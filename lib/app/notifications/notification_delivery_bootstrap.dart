import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/services/background_network_bridge.dart';
import 'package:kerosene/core/services/background_service.dart';
import 'package:kerosene/app/notifications/notification_service.dart';
import 'package:kerosene/core/services/push_token_source.dart';
import 'package:kerosene/core/utils/device_helper.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';

/// Ensures OS notifications can actually fire after login:
/// permissions, channels, background monitor, and device-token registry.
///
/// Remote FCM is not required: Kerosene delivers via STOMP (foreground) +
/// background REST poll (when the user enables background alerts).
class NotificationDeliveryBootstrap {
  NotificationDeliveryBootstrap(this._ref);

  final Ref _ref;
  bool _inFlight = false;
  String? _lastUserId;

  Future<void> ensureReady() async {
    final auth = _ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      _lastUserId = null;
      return;
    }
    if (_inFlight) return;
    if (_lastUserId == auth.user.id) {
      // Already bootstrapped this session user.
      return;
    }
    _inFlight = true;
    try {
      await NotificationService().init();
      final granted = await NotificationService().requestPermissions();
      if (kDebugMode) {
        debugPrint(
          'NotificationDelivery: permissions granted=$granted user=${auth.user.id}',
        );
      }

      // Ensure background isolate has a reachable API base (local Tor relay or clearnet).
      await BackgroundNetworkBridge.publishMainIsolateRouting(
        apiBaseUrl: AppConfig.apiUrl,
        torEnabled: AppConfig.isTorEnabled,
      );

      final prefs = _ref.read(alertPreferencesProvider);
      if (prefs.backgroundAlertsEnabled) {
        await startBackgroundService();
      } else {
        await stopBackgroundService();
      }

      await _registerDeviceTokens();
      // Hydrate in-app notification center from REST (includes metadata).
      unawaited(
        _ref.read(sessionNotificationFeedProvider.notifier).reloadFromServer(),
      );
      _lastUserId = auth.user.id;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('NotificationDelivery: bootstrap failed: $e\n$st');
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _registerDeviceTokens() async {
    try {
      final meta = await DeviceHelper.getDeviceMetadata();
      final installId = meta.deviceInstallId.isNotEmpty
          ? meta.deviceInstallId
          : meta.deviceId;
      if (installId.isEmpty) return;

      final platform = _platformLabel();
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final primary = PushTokenSource.primaryToken(installId: installId);
      final secondary =
          PushTokenSource.secondaryLocalAlertToken(installId: installId);

      await _registerOne(
        platform: platform,
        token: primary,
        deviceId: installId,
        appVersion: appVersion,
      );
      if (secondary != null && secondary != primary) {
        await _registerOne(
          platform: platform,
          token: secondary,
          deviceId: installId,
          appVersion: appVersion,
        );
      }
      _ref.invalidate(activeDeviceTokensProvider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationDelivery: register skipped: $e');
      }
    }
  }

  Future<void> _registerOne({
    required String platform,
    required String token,
    required String deviceId,
    String? appVersion,
  }) async {
    final result =
        await _ref.read(notificationRepositoryProvider).registerDeviceToken(
              platform: platform,
              token: token,
              deviceId: deviceId,
              appVersion: appVersion,
            );
    result.fold(
      (failure) {
        if (kDebugMode) {
          debugPrint(
            'NotificationDelivery: token register failed: ${failure.message}',
          );
        }
      },
      (_) {
        if (kDebugMode) {
          final kind =
              token.startsWith('local-alert:') ? 'local-alert' : 'remote';
          debugPrint('NotificationDelivery: device token registered ($kind)');
        }
      },
    );
  }

  /// Backend accepts only ANDROID | IOS | WEB.
  String _platformLabel() {
    if (kIsWeb) return 'WEB';
    try {
      if (Platform.isAndroid) return 'ANDROID';
      if (Platform.isIOS) return 'IOS';
    } catch (_) {}
    // Desktop / other → registry as WEB (local-alert still works for ops list).
    return 'WEB';
  }
}

/// Watches auth + pin unlock and bootstraps native notification delivery.
final notificationDeliveryBootstrapProvider =
    Provider<NotificationDeliveryBootstrap>((ref) {
  return NotificationDeliveryBootstrap(ref);
});
