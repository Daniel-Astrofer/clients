import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/services/tor_network_bootstrap.dart';
import 'package:kerosene/core/services/tor_service.dart';
import 'package:kerosene/core/providers/tor_providers.dart';

/// Cold-start readiness for Tor.
///
/// - [torSettled]: local Tor relay is bound (API can go out).
///
/// Authenticated entry PIN is shown only after Tor is settled (see
/// mobile_bootstrap) so the pad is never shown twice (pre-Tor + post-Tor).
class AppColdStartState {
  final bool torSettled;

  const AppColdStartState({
    required this.torSettled,
  });

  /// Full network path ready (relay bound; circuit may still warm in background).
  bool get isTorReady => torSettled;

  /// Back-compat alias for the Tor gate.
  bool get isReady => torSettled;

  AppColdStartState copyWith({
    bool? torSettled,
  }) {
    return AppColdStartState(
      torSettled: torSettled ?? this.torSettled,
    );
  }
}

class AppColdStartNotifier extends Notifier<AppColdStartState> {
  bool _torKickoffStarted = false;
  Completer<void>? _torReadyCompleter;

  // Instance fields survive keepAlive rebuilds without reading [state] in build().
  bool _torSettled = false;

  @override
  AppColdStartState build() {
    ref.keepAlive();
    if (!_torKickoffStarted) {
      _torKickoffStarted = true;
      unawaited(_runTorBootstrap());
    }

    return AppColdStartState(
      torSettled: _torSettled,
    );
  }

  /// Await until Tor bootstrap finished (success **or** soft-fail).
  /// Prefer [waitUntilTorReadyForApi] when you must send a network request.
  Future<void> waitUntilTorSettled() async {
    if (state.torSettled || _torSettled) return;
    final existing = _torReadyCompleter;
    if (existing != null) {
      await existing.future;
      return;
    }
    final completer = Completer<void>();
    _torReadyCompleter = completer;
    if (state.torSettled || _torSettled) {
      if (!completer.isCompleted) completer.complete();
      return;
    }
    await completer.future;
  }

  /// Wait until the embedded Tor relay is actually usable for API calls.
  ///
  /// Used by the PIN gate: keep the entered PIN, show Tor dots, then verify.
  /// Returns `true` when [TorService.isRunning]; `false` after timeout.
  Future<bool> waitUntilTorReadyForApi({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final tor = TorService.instance;
    if (AppConfig.isTorEnabled && tor.isRunning) {
      return true;
    }

    // Join the cold-start bootstrap if it is still running.
    if (!_torSettled) {
      await waitUntilTorSettled().timeout(
        timeout,
        onTimeout: () {},
      );
      if (AppConfig.isTorEnabled && tor.isRunning) {
        return true;
      }
    }

    final deadline = DateTime.now().add(timeout);
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      if (AppConfig.isTorEnabled && tor.isRunning) {
        return true;
      }
      final ok = await bootstrapTorNetwork(
        torService: tor,
        updateApiUrl: (url) {
          ref.read(torApiUrlProvider.notifier).updateUrl(url);
        },
        ignoreFailureCooldown: attempt > 0,
      );
      if (ok && tor.isRunning) {
        _torSettled = true;
        if (ref.mounted) {
          state = state.copyWith(torSettled: true);
        }
        return true;
      }
      attempt += 1;
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 4 ? 400 : 800),
      );
    }
    return AppConfig.isTorEnabled && tor.isRunning;
  }

  Future<void> _runTorBootstrap() async {
    _torReadyCompleter ??= Completer<void>();
    try {
      await bootstrapTorNetwork(
        torService: TorService.instance,
        updateApiUrl: (url) {
          ref.read(torApiUrlProvider.notifier).updateUrl(url);
        },
      );
    } catch (_) {
      // Still release the shell — unavailable UX is handled elsewhere.
    }
    if (!ref.mounted) {
      _torSettled = true;
      _completeTorWait();
      return;
    }
    _torSettled = true;
    state = state.copyWith(torSettled: true);
    _completeTorWait();
  }

  void _completeTorWait() {
    final c = _torReadyCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }
}

final appColdStartProvider =
    NotifierProvider<AppColdStartNotifier, AppColdStartState>(
  AppColdStartNotifier.new,
);

/// Convenience: true when Tor bootstrap finished (success or soft-fail).
final torSettledProvider = Provider<bool>((ref) {
  return ref.watch(appColdStartProvider).torSettled;
});
