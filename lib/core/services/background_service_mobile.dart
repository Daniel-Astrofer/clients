import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, InternetAddress, Platform;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../security/secure_storage_service.dart';
import 'background_network_bridge.dart';
import 'native_notification_presenter.dart';
import 'background_service_status.dart';
import '../providers/alert_preferences_provider.dart';
import 'package:kerosene/app/notifications/notification_service.dart';
export 'background_service_status.dart';

bool get backgroundServiceSupported => _supportsBackgroundService;
Future<void>? _configurationFuture;
bool? _configuredEnabled;

/// flutter_background_service only supports Android / iOS.
bool get _supportsBackgroundService {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

Future<void> initializeBackgroundService() async {
  if (!_supportsBackgroundService) {
    debugPrint(
      'BackgroundService: skipped (supported on Android/iOS only; '
      'desktop uses foreground Tor + REST).',
    );
    return;
  }

  final enabled = await loadBackgroundAlertsEnabled();
  final pending = _configurationFuture;
  if (pending != null) await pending;
  if (_configuredEnabled == enabled) return;
  final future = _configureBackgroundService(enabled);
  _configurationFuture = future;
  try {
    await future;
    _configuredEnabled = enabled;
  } finally {
    if (identical(_configurationFuture, future)) _configurationFuture = null;
  }
}

Future<void> _configureBackgroundService(bool enabled) async {
  final service = FlutterBackgroundService();

  // Channels are owned by NotificationService (pt-BR names + importance).
  await NotificationService().init(requestPermission: false);
  // Android 15+ disallows boot-triggered dataSync foreground services.
  final bootAllowed = !Platform.isAndroid ||
      (await DeviceInfoPlugin().androidInfo).version.sdkInt < 35;

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      // User can enable from settings; auth_controller starts when preferred.
      autoStart: false,
      // Restart after device reboot if the service was enabled.
      autoStartOnBoot: enabled && bootAllowed,
      // Foreground service keeps the process alive after swipe-away (Android).
      isForegroundMode: true,
      notificationChannelId: 'kerosene_foreground',
      initialNotificationTitle: 'Kerosene',
      initialNotificationContent: 'Inicializando alertas…',
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
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      throw const BackgroundServiceNeedsForeground();
    }
    try {
      if (!await service.startService()) {
        throw StateError('Background notification service did not start.');
      }
    } on PlatformException catch (error) {
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('startforegroundservice') &&
          (message.contains('not allowed') ||
              message.contains('mallowstartforeground false'))) {
        throw const BackgroundServiceNeedsForeground();
      }
      rethrow;
    }
  }
}

Future<void> stopBackgroundService() async {
  if (!_supportsBackgroundService) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('stopService');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (await service.isRunning()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Background service did not confirm stopping.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}

Future<BackgroundServiceStatus> readBackgroundServiceStatus() async {
  if (!_supportsBackgroundService) {
    return const BackgroundServiceStatus(running: false);
  }
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    return const BackgroundServiceStatus(running: false);
  }
  final nonce = const Uuid().v4();
  final reply = Completer<BackgroundServiceStatus>();
  final subscription = service.on('runtimeStatus').listen((event) {
    if (event == null || event['nonce'] != nonce || reply.isCompleted) return;
    if (event['failed'] == true) {
      reply.completeError(StateError('Background initialization failed.'));
    } else if (event['userId'] is String) {
      reply.complete(BackgroundServiceStatus(
          running: true, userId: event['userId'] as String));
    }
  });
  try {
    service.invoke('runtimeStatusRequest', {'nonce': nonce});
    return await reply.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    if (!await service.isRunning()) {
      return const BackgroundServiceStatus(running: false);
    }
    rethrow;
  } finally {
    await subscription.cancel();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

Dio _buildBackgroundDio({
  required String baseUrl,
  required String authToken,
  required BackgroundRoutingSnapshot routing,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Authorization':
            authToken.startsWith('Bearer ') ? authToken : 'Bearer $authToken',
        'Accept': 'application/json',
      },
    ),
  );

  if (routing.shouldUseSocks) {
    final port = routing.socksPort!;
    final host = routing.socksHost;
    final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
    adapter.createHttpClient = () {
      final client = HttpClient();
      final settings = [
        ProxySettings(
          host == '127.0.0.1' || host == 'localhost'
              ? InternetAddress.loopbackIPv4
              : InternetAddress(host),
          port,
        ),
      ];
      SocksTCPClient.assignToHttpClient(client, settings);
      return client;
    };
    debugPrint(
      'BackgroundService: SOCKS5 via $host:$port for $baseUrl',
    );
  } else if (routing.isOnionApi) {
    debugPrint(
      'BackgroundService: onion API without SOCKS snapshot — poll may fail '
      'until main isolate publishes Tor port.',
    );
  }

  return dio;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  String? readyUserId;
  var stopping = false;
  var failed = false;
  Timer? pollTimer;
  final pendingStatusRequests = <String>{};
  void reportStatus(String nonce) => service.invoke('runtimeStatus', {
        'nonce': nonce,
        'userId': readyUserId,
        'failed': failed,
      });
  service.on('runtimeStatusRequest').listen((event) {
    final nonce = event?['nonce'];
    if (nonce is! String || nonce.isEmpty) return;
    if (readyUserId != null || failed) {
      reportStatus(nonce);
    } else {
      pendingStatusRequests.add(nonce);
    }
  });
  service.on('stopService').listen((event) async {
    stopping = true;
    pollTimer?.cancel();
    try {
      await service.stopSelf();
    } catch (error) {
      failed = true;
      readyUserId = null;
      debugPrint('BackgroundService: stopping failed (${error.runtimeType}).');
    }
  });
  try {
    // Android runtime notification permission must be requested from the main
    // isolate. The background isolate only initializes channels/plugin state.
    await NotificationService().init(requestPermission: false);

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

    if (stopping ||
        token == null ||
        userId == null ||
        userId.isEmpty ||
        userId == '0' ||
        !backgroundTokenMatchesUser(token, userId) ||
        await BackgroundNetworkBridge.isCredentialRejected(token) ||
        !await loadBackgroundAlertsEnabled()) {
      debugPrint('BackgroundService: No token/userId found. Stopping.');
      await service.stopSelf();
      return;
    }

    // Promote to foreground notification so Android keeps the process.
    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
      await service.setForegroundNotificationInfo(
        title: 'Kerosene',
        content: 'Monitorando carteiras e notificações…',
      );
    }

    if (stopping) {
      await service.stopSelf();
      return;
    }
    readyUserId = userId;
    for (final nonce in pendingStatusRequests) {
      reportStatus(nonce);
    }
    pendingStatusRequests.clear();
    final seenNotificationIds = await BackgroundNetworkBridge.loadSeenIds();
    var polling = false;
    Future<bool> stillOwned() async {
      if (stopping) return false;
      final currentToken =
          await secureStorage.read(key: AppConfig.authTokenKey);
      final rawUser = await secureStorage.read(key: AppConfig.userDataKey);
      final currentUser = rawUser == null ? null : jsonDecode(rawUser);
      final sameUser =
          currentUser is Map && currentUser['id']?.toString() == userId;
      if (currentToken == null ||
          !sameUser ||
          !backgroundTokenMatchesUser(currentToken, userId!) ||
          !await loadBackgroundAlertsEnabled()) {
        stopping = true;
        pollTimer?.cancel();
        await service.stopSelf();
        return false;
      }
      return true; // Same-owner JWT renewal must not discard an inbox result.
    }

    // First successful poll only seeds IDs so we don't re-alert historical items.
    var seededNotificationHistory = seenNotificationIds.isNotEmpty;

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
      if (polling || stopping) return;
      polling = true;
      String? attemptedToken;
      try {
        final freshToken =
            await secureStorage.read(key: AppConfig.authTokenKey);
        if (freshToken == null || freshToken.isEmpty) {
          stopping = true;
          pollTimer?.cancel();
          await service.stopSelf();
          return;
        }
        if (!await stillOwned()) return;
        final routing = await BackgroundNetworkBridge.readRouting();
        final alertPrefs = await BackgroundNetworkBridge.readAlertPrefs();
        attemptedToken = freshToken;
        final dio = _buildBackgroundDio(
          baseUrl: routing.apiBaseUrl,
          authToken: freshToken,
          routing: routing,
        );

        final response = await dio.get(AppConfig.notificationsList);
        if (!await stillOwned()) return;
        final data = response.data;
        List list;
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else {
          throw const FormatException('Notification inbox response is invalid.');
        }

        final isSeedPass = !seededNotificationHistory;
        final newlySeen = <String>{};
        for (final raw in list) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final id = map['id']?.toString() ?? '';
          if (id.isEmpty || seenNotificationIds.contains(id)) continue;
          rememberId(id);
          newlySeen.add(id);

          // Seed history silently on first successful list fetch.
          if (isSeedPass) continue;

          final kind = map['kind']?.toString() ?? '';
          final title = map['title']?.toString() ?? 'Kerosene';
          final body = map['body']?.toString() ?? '';
          if (!NativeNotificationPresenter.isNativeAlertKind(kind)) continue;
          if (!alertPrefs.allowsKind(kind)) continue;
          if (title.isEmpty && body.isEmpty) continue;

          if (!await stillOwned()) return;
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
        if (newlySeen.isNotEmpty) {
          await BackgroundNetworkBridge.rememberSeenIds(seenNotificationIds);
        }
      } catch (e) {
        final failedToken = attemptedToken;
        if (e is DioException &&
            failedToken != null &&
            backgroundCredentialRejectionApplies(e.response?.statusCode,
                failedToken, await secureStorage.read(key: AppConfig.authTokenKey))) {
          try {
            if (await stillOwned()) {
              await BackgroundNetworkBridge.rejectCredential(failedToken);
              debugPrint('BackgroundService: credential rejected; waiting for a new session.');
            }
          } catch (error) {
            debugPrint('BackgroundService: rejection persistence failed (${error.runtimeType}).');
          } finally {
            stopping = true;
            readyUserId = null;
            pollTimer?.cancel();
            await service.stopSelf();
          }
        } else {
          debugPrint(
              'BackgroundService: pollNotifications failed (${e.runtimeType}).');
        }
      } finally {
        polling = false;
      }
    }

    // Always poll notifications (works when REST is reachable without Tor).
    pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(pollNotifications());
    });
    unawaited(pollNotifications());

    // Main isolate owns the live STOMP socket. A second clearnet BalanceWebSocket
    // here duplicated sessions and raced reconnect/auth. Background relies on
    // REST poll above (same path onion already used).
    final routing = await BackgroundNetworkBridge.readRouting();
    if (routing.isOnionApi && !routing.shouldUseSocks) {
      debugPrint(
        'BackgroundService: waiting for main isolate to publish Tor SOCKS for onion API.',
      );
    } else {
      debugPrint(
        'BackgroundService: notification poll only (no isolate STOMP).',
      );
    }

    // Main isolate can wake an immediate poll after a live WS notification.
    service.on('pollNow').listen((event) {
      unawaited(pollNotifications());
    });

    // Mark ids already shown in the main isolate so the next poll does not re-alert.
    service.on('markSeen').listen((event) {
      if (event is! Map) return;
      final map = Map<Object?, Object?>.from(event as Map);
      final raw = map['ids'];
      if (raw is! List) return;
      for (final id in raw) {
        rememberId(id.toString());
      }
      seededNotificationHistory = true;
      unawaited(BackgroundNetworkBridge.rememberSeenIds(seenNotificationIds));
    });
  } catch (error) {
    failed = true;
    readyUserId = null;
    pollTimer?.cancel();
    for (final nonce in pendingStatusRequests) {
      reportStatus(nonce);
    }
    debugPrint(
        'BackgroundService: initialization failed (${error.runtimeType}).');
    await service.stopSelf();
  }
}

/// Ask the background isolate to poll the notification inbox immediately.
Future<void> requestBackgroundNotificationPoll() async {
  if (!_supportsBackgroundService) return;
  try {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) return;
    service.invoke('pollNow');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('BackgroundService: pollNow invoke failed: $e');
    }
  }
}

/// Tell the background isolate that these notification ids were already shown
/// (e.g. via foreground STOMP) so a subsequent poll will not re-fire them.
Future<void> markBackgroundNotificationsSeen(Iterable<String> ids) async {
  if (!_supportsBackgroundService) return;
  final list = ids.where((e) => e.trim().isNotEmpty).toList(growable: false);
  if (list.isEmpty) return;
  try {
    // Persist on main isolate prefs first (BG may not be running yet).
    await BackgroundNetworkBridge.rememberSeenIds(list.toSet());
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) return;
    service.invoke('markSeen', {'ids': list});
  } catch (e) {
    if (kDebugMode) {
      debugPrint('BackgroundService: markSeen invoke failed: $e');
    }
  }
}
