import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'balance_websocket_service.dart';
import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'notification_service.dart';

bool _usesOnionBackend() {
  final host = Uri.tryParse(AppConfig.onionBaseUrl)?.host.toLowerCase();
  return host?.endsWith('.onion') ?? false;
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Persistent channel for the foreground service (required while app is closed).
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'kerosene_foreground',
    'Kerosene em segundo plano',
    description: 'Monitora saldo e notificações com o app fechado.',
    importance: Importance.low,
  );

  // High-importance channel for transaction alerts from background isolate.
  const AndroidNotificationChannel txChannel = AndroidNotificationChannel(
    'kerosene_transactions',
    'Kerosene transactions',
    description: 'Alertas de envios e recebimentos.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.createNotificationChannel(txChannel);

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
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  }
}

Future<void> stopBackgroundService() async {
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

  bool _isFinancialKind(String kind) {
    final k = kind.toLowerCase();
    return k.contains('deposit') ||
        k.contains('transfer') ||
        k.contains('payment') ||
        k.contains('outbound') ||
        k.contains('cold') ||
        k == 'payment_sent' ||
        k == 'transfer_sent' ||
        k == 'transfer_received';
  }

  bool _isIncomingKind(String kind) {
    final k = kind.toLowerCase();
    return k.contains('deposit') ||
        k.contains('received') ||
        k.contains('inbound');
  }

  void _rememberId(String id) {
    if (id.isEmpty || seenNotificationIds.contains(id)) return;
    seenNotificationIds.add(id);
    if (seenNotificationIds.length > 300) {
      seenNotificationIds.remove(seenNotificationIds.first);
    }
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
        _rememberId(id);

        // Seed history silently on first successful list fetch.
        if (isSeedPass) continue;

        final kind = map['kind']?.toString() ?? '';
        final title = map['title']?.toString() ?? 'Kerosene';
        final body = map['body']?.toString() ?? '';
        if (!_isFinancialKind(kind) || body.isEmpty) continue;

        await NotificationService().showTransactionNotification(
          id: id.hashCode & 0x7fffffff,
          title: title,
          body: body,
          summary: 'Kerosene',
          incoming: _isIncomingKind(kind),
          dedupeKey: 'bg|$id',
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
        _rememberId(id);
        final kind = event.kind;
        if (!_isFinancialKind(kind)) return;
        await NotificationService().showTransactionNotification(
          id: id.hashCode & 0x7fffffff,
          title: event.title,
          body: event.body,
          summary: 'Kerosene',
          incoming: _isIncomingKind(kind),
          dedupeKey: 'bg-ws|$id',
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
