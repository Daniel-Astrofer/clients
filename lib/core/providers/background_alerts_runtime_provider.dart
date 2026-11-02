import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/notifications/notification_service.dart';

import '../services/background_service.dart';
import 'alert_preferences_provider.dart';

enum BackgroundAlertsPhase {
  disabled,
  signedOut,
  unsupported,
  waitingForForeground,
  starting,
  running,
  permissionRequired,
  failedStart,
  failedStop,
}

/// The preference is a desired setting; this reports verified service state.
class BackgroundAlertsRuntimeState {
  const BackgroundAlertsRuntimeState(this.phase);
  final BackgroundAlertsPhase phase;
}

class BackgroundAlertsDriver {
  bool get supported => backgroundServiceSupported;
  Future<BackgroundServiceStatus> snapshot() => readBackgroundServiceStatus();
  Future<void> initialize() => initializeBackgroundService();
  Future<void> start() => startBackgroundService();
  Future<void> stop() => stopBackgroundService();
  Future<bool> permissionsEnabled() =>
      NotificationService().permissionsEnabled();
}

final backgroundAlertsDriverProvider =
    Provider((ref) => BackgroundAlertsDriver());
final backgroundAlertsRuntimeProvider = NotifierProvider<
    BackgroundAlertsRuntimeNotifier,
    BackgroundAlertsRuntimeState>(BackgroundAlertsRuntimeNotifier.new);

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.changed);
  final void Function(AppLifecycleState) changed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => changed(state);
}

class BackgroundAlertsRuntimeNotifier
    extends Notifier<BackgroundAlertsRuntimeState> {
  String? _userId;
  int _epoch = 0;
  int _preferenceRevision = 0;
  bool _foreground = false;
  bool _disposed = false;
  bool _dirty = false;
  Future<void> _tail = Future.value();
  Future<void>? _pendingSync;
  late BackgroundAlertsDriver _serviceDriver;

  (String, int)? get session => _userId == null ? null : (_userId!, _epoch);
  bool get _enabled =>
      ref.read(alertPreferencesProvider).backgroundAlertsEnabled;
  BackgroundAlertsDriver get _driver => _serviceDriver;

  @override
  BackgroundAlertsRuntimeState build() {
    _serviceDriver = ref.read(backgroundAlertsDriverProvider);
    final supported = _driver.supported;
    if (supported) {
      ref.listen(alertPreferencesProvider, (previous, next) {
        if (previous?.backgroundAlertsEnabled != next.backgroundAlertsEnabled) {
          _preferenceRevision++;
          unawaited(retry());
        }
      });
    }
    if (supported) {
      _foreground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final observer = _LifecycleObserver((lifecycle) {
        _foreground = lifecycle == AppLifecycleState.resumed;
        if (_foreground) unawaited(retry());
      });
      WidgetsBinding.instance.addObserver(observer);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
      final check = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_disposed &&
            _foreground &&
            state.phase == BackgroundAlertsPhase.running) {
          unawaited(retry());
        }
      });
      ref.onDispose(check.cancel);
    }
    ref.onDispose(() => _disposed = true);
    return BackgroundAlertsRuntimeState(supported
        ? BackgroundAlertsPhase.signedOut
        : BackgroundAlertsPhase.unsupported);
  }

  Future<void> activateFor(String userId) {
    final normalized = userId.trim();
    final next = normalized.isEmpty || normalized == '0' ? null : normalized;
    if (_userId != next) {
      _userId = next;
      _epoch++;
    }
    return retry();
  }

  Future<void> deactivate() {
    _userId = null;
    _epoch++;
    return retry();
  }

  void _publish(BackgroundAlertsPhase phase) {
    if (!_disposed) state = BackgroundAlertsRuntimeState(phase);
  }

  bool _owns((String, int)? stamp, int revision) =>
      !_disposed && session == stamp && _preferenceRevision == revision;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // The returned future reports explicit failures to the caller. Consuming
    // only the queue tail prevents one failed action from poisoning later work.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> retry() {
    if (_disposed) return Future.value();
    _dirty = true;
    final pending = _pendingSync;
    if (pending != null) return pending;
    final result = _serialize(() async {
      while (_dirty && !_disposed) {
        _dirty = false;
        await _reconcile();
      }
    });
    _pendingSync = result;
    return result.whenComplete(() {
      if (identical(_pendingSync, result)) _pendingSync = null;
      if (_dirty && !_disposed) unawaited(retry());
    });
  }

  Future<void> _reconcile() async {
    if (!_driver.supported) {
      _publish(BackgroundAlertsPhase.unsupported);
      return;
    }
    final stamp = session;
    final revision = _preferenceRevision;
    if (!_enabled || stamp == null) {
      try {
        await _driver.stop();
        await _driver.initialize(); // Applies the saved boot preference, too.
        if (_owns(stamp, revision)) {
          _publish(stamp == null
              ? BackgroundAlertsPhase.signedOut
              : BackgroundAlertsPhase.disabled);
        }
      } catch (_) {
        if (_owns(stamp, revision)) _publish(BackgroundAlertsPhase.failedStop);
      }
      return;
    }
    try {
      await _ensureRunning(stamp, revision);
    } on BackgroundServiceNeedsForeground {
      if (_owns(stamp, revision)) {
        _publish(BackgroundAlertsPhase.waitingForForeground);
      }
    } catch (_) {
      if (_owns(stamp, revision)) _publish(BackgroundAlertsPhase.failedStart);
    }
  }

  Future<bool> _ensureRunning((String, int) stamp, int revision) async {
    BackgroundServiceStatus snapshot;
    try {
      snapshot = await _driver.snapshot();
    } catch (_) {
      if (_owns(stamp, revision)) await _driver.stop();
      rethrow;
    }
    if (!_owns(stamp, revision)) return false;
    if (!snapshot.running && !_foreground) {
      _publish(BackgroundAlertsPhase.waitingForForeground);
      return false;
    }
    final permission = await _driver.permissionsEnabled();
    if (!_owns(stamp, revision)) return false;
    if (!permission) {
      await _driver.stop();
      if (_owns(stamp, revision)) {
        _publish(BackgroundAlertsPhase.permissionRequired);
      }
      return false;
    }
    if (snapshot.running && snapshot.userId == stamp.$1) {
      _publish(BackgroundAlertsPhase.running);
      return true;
    }
    if (snapshot.running) await _driver.stop();
    if (!_owns(stamp, revision)) return false;
    if (!_foreground) {
      _publish(BackgroundAlertsPhase.waitingForForeground);
      return false;
    }
    _publish(BackgroundAlertsPhase.starting);
    await _driver.initialize();
    if (!_owns(stamp, revision)) return false;
    if (!_foreground) throw const BackgroundServiceNeedsForeground();
    try {
      await _driver.start();
      final confirmed = await _driver.snapshot();
      if (!_owns(stamp, revision)) {
        await _driver.stop();
        return false;
      }
      if (!confirmed.running || confirmed.userId != stamp.$1) {
        throw StateError(
            'Background service did not confirm the current account.');
      }
      _publish(BackgroundAlertsPhase.running);
      return true;
    } catch (_) {
      await _driver.stop();
      rethrow;
    }
  }

  /// A user action: commit the desired preference, verify its effect, and
  /// restore the prior preference on failure while this same session owns it.
  Future<void> setEnabled(bool enabled,
          {required (String, int)? expectedSession}) =>
      _serialize(() async {
        if (_disposed || session != expectedSession) {
          throw StateError('Background alert account changed.');
        }
        if (enabled && (!_driver.supported || expectedSession == null)) {
          throw StateError('Background alerts are unavailable.');
        }
        final previous = _enabled;
        final preferences = ref.read(alertPreferencesProvider.notifier);
        await preferences.setBackgroundAlertsEnabled(enabled);
        final revision = _preferenceRevision;
        try {
          if (!_owns(expectedSession, revision)) {
            throw StateError('Account changed.');
          }
          if (!enabled) {
            if (_driver.supported) {
              await _driver.stop();
              await _driver.initialize();
            }
            if (!_owns(expectedSession, revision)) {
              throw StateError('Account changed.');
            }
            _publish(BackgroundAlertsPhase.disabled);
          } else if (!await _ensureRunning(expectedSession!, revision)) {
            throw StateError('Background alerts were not started.');
          }
        } catch (_) {
          if (_owns(expectedSession, revision)) {
            await preferences.setBackgroundAlertsEnabled(previous);
          }
          rethrow;
        }
      });
}
