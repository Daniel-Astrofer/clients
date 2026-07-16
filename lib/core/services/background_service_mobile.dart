import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'balance_websocket_service.dart';
import 'native_notification_presenter.dart';
import 'notification_service.dart';

/// flutter_background_service only supports Android / iOS.
bool get _supportsBackgroundService {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

bool _usesOnionBackend() {
  final host = Uri.tryParse(AppConfig.onionBaseUrl)?.host.toLowerCase();
  return host?.endsWith('.onion') ?? false;
}

Future<void> initializeBackgroundService() async {
  if (!_supportsBackgroundService) {
    debugPrint(
      'BackgroundService: skipped (supported on Android/iOS only; '
      'desktop uses foreground Tor + REST).',
    );
    return;
  }

  final service = FlutterBackgroundService();

  // Channels are owned by NotificationService (pt-BR names + importance).
  await NotificationService().init();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      // User can enable from settings; auth_controller starts when preferred.
      autoStart: false,
      // Restart after device reboot if the service was enabled.
      autoStartOnBoot: true,
      // Foreground service keeps the process alive after swipe-away (Android).
      isForegroundMode: true,
      notificationChannelId: 'kerosene_foreground',
      initialNotificationTitle: 'Kerosene',
      initialNotificationContent: 'Monitorando carteiras e notificações…',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> startBackgroundService() async {
  if (!_supportsBackgroundService) return;
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  }
}

Future<void> stopBackgroundService() async {
  if (!_supportsBackgroundService) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await NotificationService().init();

  final secureStorage = SecureStorageService();
  String? token = await secureStorage.read(key: AppConfig.authTokenKey);
  final userDataJson = await secureStorage.read(key: AppConfig.userDataKey);

  String? userId;
  if (userDataJson != null) {
    try {
      final userData = jsonDecode(userDataJson);
      userId = userData['id']?.toString();
    } catch (e) {
      debugPrint('BackgroundService: Error parsing user data: $e');
    }
  }

  if (token == null || userId == null) {
    debugPrint('BackgroundService: No token/userId found. Stopping.');
    service.stopSelf();
    return;
  }

  // Promote to foreground notification so Android keeps the process.
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Kerosene',
      content: 'Monitorando carteiras e notificações…',
    );
  }

  final seenNotificationIds = <String>{};
  final lastBalances = <String, double>{};
  Timer? pollTimer;
  BalanceWebSocketService? wsService;
  // First successful poll only seeds IDs so we don't re-alert historical items.
  var seededNotificationHistory = false;

  void rememberId(String id) {
    if (id.isEmpty || seenNotificationIds.contains(id)) return;
    seenNotificationIds.add(id);
    if (seenNotificationIds.length > 300) {
      seenNotificationIds.remove(seenNotificationIds.first);
    }
  }

  Map<String, String> metadataFrom(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final k = key?.toString();
      final v = value?.toString();
      if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
        out[k] = v;
      }
    });
    return out;
  }

  Future<void> pollNotifications() async {
    try {
      final freshToken = await secureStorage.read(key: AppConfig.authTokenKey);
      if (freshToken == null || freshToken.isEmpty) {
        return;
      }
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Authorization': freshToken.startsWith('Bearer ')
                ? freshToken
                : 'Bearer $freshToken',
            'Accept': 'application/json',
          },
        ),
      );
      // Best-effort: if onion URL, Dio will fail without Tor in this isolate.
      final response = await dio.get(AppConfig.notificationsList);
      final data = response.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else {
        list = const [];
      }

      final isSeedPass = !seededNotificationHistory;
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty || seenNotificationIds.contains(id)) continue;
        rememberId(id);

        // Seed history silently on first successful list fetch.
        if (isSeedPass) continue;

        final kind = map['kind']?.toString() ?? '';
        final title = map['title']?.toString() ?? 'Kerosene';
        final body = map['body']?.toString() ?? '';
        if (!NativeNotificationPresenter.isNativeAlertKind(kind)) continue;
        if (title.isEmpty && body.isEmpty) continue;

        await NotificationService().showFromBackendEvent(
          id: id,
          kind: kind,
          title: title,
          body: body,
          metadata: metadataFrom(map['metadata']),
          deeplink: map['deeplink']?.toString(),
          entityType: map['entityType']?.toString(),
          entityId: map['entityId']?.toString(),
          severity: map['severity']?.toString(),
        );
      }
      seededNotificationHistory = true;
    } catch (e) {
      debugPrint('BackgroundService: pollNotifications failed: $e');
    }
  }

  // Always poll notifications (works when REST is reachable without Tor).
  pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
    unawaited(pollNotifications());
  });
  unawaited(pollNotifications());

  // Clearnet: also keep balance websocket for near-real-time.
  if (!_usesOnionBackend()) {
    wsService = BalanceWebSocketService(
      baseUrl: AppConfig.apiUrl,
      userId: userId,
      authToken: token,
      onBalanceUpdate: (update) async {
        lastBalances[update.walletName] = update.newBalance;
      },
      onNotification: (event) async {
        final id = event.id;
        if (id.isEmpty || seenNotificationIds.contains(id)) return;
        rememberId(id);
        final kind = event.kind;
        if (!NativeNotificationPresenter.isNativeAlertKind(kind)) return;
        await NotificationService().showFromBackendEvent(
          id: id,
          kind: kind,
          title: event.title,
          body: event.body,
          metadata: event.metadata,
          deeplink: event.deeplink,
          entityType: event.entityType,
          entityId: event.entityId,
          severity: event.severity,
        );
      },
    );
    unawaited(wsService.connect());
  } else {
    debugPrint(
      'BackgroundService: onion mode — polling REST notifications only '
      '(Tor SOCKS stays on main isolate).',
    );
  }

  service.on('stopService').listen((event) {
    pollTimer?.cancel();
    wsService?.disconnect();
    service.stopSelf();
  });
}
