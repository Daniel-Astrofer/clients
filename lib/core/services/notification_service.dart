import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kerosene/core/services/native_notification_presenter.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/core/logging/app_log.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const Duration _nativeDedupeWindow = Duration(seconds: 45);
  final Map<String, DateTime> _lastNativeNotificationShownAt =
      <String, DateTime>{};

  final NativeNotificationPresenter _presenter =
      const NativeNotificationPresenter();

  bool _initialized = false;

  /// Optional deeplink handler when user taps a system notification.
  void Function(String payload)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Desktop platforms require explicit settings or initialize() throws.
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Kerosene',
      appUserModelId: 'Kerosene.App.Desktop',
      // Stable GUID for toast activation callbacks (do not rotate).
      guid: 'a3f1c8e2-7b54-4d91-9e6c-2f8d0b4a5c17',
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload?.trim();
        if (payload == null || payload.isEmpty) return;
        if (kDebugMode) {
          debugPrint('NotificationService: tap payload=$payload');
        }
        onNotificationTap?.call(payload);
      },
    );

    // Cold start from notification tap.
    try {
      final launch = await flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload?.trim();
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        // Defer until UI tree mounts.
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          onNotificationTap?.call(payload);
        });
      }
    } catch (_) {}

    await _ensureAndroidChannels();
    await requestPermissions();
    _initialized = true;
  }

  Future<void> _ensureAndroidChannels() async {
    final android =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NativeNotificationChannels.transactions,
        NativeNotificationChannels.transactionsName,
        description: NativeNotificationChannels.transactionsDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NativeNotificationChannels.security,
        NativeNotificationChannels.securityName,
        description: NativeNotificationChannels.securityDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NativeNotificationChannels.system,
        NativeNotificationChannels.systemName,
        description: NativeNotificationChannels.systemDesc,
        importance: Importance.defaultImportance,
        playSound: true,
        showBadge: true,
      ),
    );
    // Foreground service sticky channel (low importance, no sound).
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NativeNotificationChannels.foreground,
        NativeNotificationChannels.foregroundName,
        description: NativeNotificationChannels.foregroundDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final androidGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final iosGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final macosGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return androidGranted ?? iosGranted ?? macosGranted ?? true;
  }

  /// Preferred entry: full structured presentation from backend fields.
  Future<void> showPresented(
      NativeNotificationPresentation presentation) async {
    if (!_initialized) {
      await init();
    }
    if (_shouldSuppressNativeNotification(presentation.dedupeKey)) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: suppressed dedupe=${presentation.dedupeKey}',
        );
      }
      return;
    }

    final color = presentation.accentColor;
    final androidColor = AndroidNotificationDetails(
      presentation.channelId,
      _channelName(presentation.channelId),
      channelDescription: _channelDescription(presentation.channelId),
      importance: presentation.highPriority
          ? Importance.max
          : Importance.defaultImportance,
      priority:
          presentation.highPriority ? Priority.high : Priority.defaultPriority,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      color: color,
      colorized: false,
      visibility: NotificationVisibility.public,
      category: presentation.family == NativeNotificationFamily.security
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.status,
      ticker: presentation.title,
      subText: presentation.summary,
      styleInformation: BigTextStyleInformation(
        presentation.body,
        contentTitle: presentation.title,
        summaryText: presentation.summary,
        htmlFormatBigText: false,
        htmlFormatContentTitle: false,
        htmlFormatSummaryText: false,
      ),
      playSound: true,
      enableVibration: true,
      // Group financial alerts under one app section when possible.
      groupKey:
          presentation.channelId == NativeNotificationChannels.transactions
              ? 'kerosene_tx_group'
              : null,
      autoCancel: true,
      onlyAlertOnce: false,
    );

    const darwinNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final id = _stableId(presentation.dedupeKey);
    appLog(
        'NotificationService: attempting to show id=$id channel=${presentation.channelId}');

    try {
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: presentation.title,
        body: presentation.body,
        notificationDetails: NotificationDetails(
          android: androidColor,
          iOS: darwinNotificationDetails,
          macOS: darwinNotificationDetails,
          linux: LinuxNotificationDetails(
            // Linux notification icons need raster; OS tray cannot load Lottie.
            icon: AssetsLinuxIcon('assets/logo/kerosene-logo-white.png'),
          ),
        ),
        payload: presentation.payload,
      );
      appLog(
          'NotificationService: successfully shown id=$id title="${presentation.title}"');
    } catch (e, stack) {
      appLog('NotificationService: FAILED to show notification. Error: $e');
      appLog(stack.toString());
    }
  }

  /// Builds presentation from raw fields and shows it.
  Future<void> showFromBackendEvent({
    required String id,
    required String kind,
    required String title,
    required String body,
    Map<String, String> metadata = const {},
    String? deeplink,
    String? entityType,
    String? entityId,
    String? severity,
  }) {
    final presentation = _presenter.present(
      id: id,
      kind: kind,
      title: title,
      body: body,
      metadata: metadata,
      deeplink: deeplink,
      entityType: entityType,
      entityId: entityId,
      severity: severity,
    );
    return showPresented(presentation);
  }

  Future<void> showSessionNotification(SessionNotificationItem item) {
    return showPresented(_presenter.presentSession(item));
  }

  /// Legacy API — prefer [showFromBackendEvent] / [showSessionNotification].
  Future<void> showTransactionNotification({
    required int id,
    required String title,
    required String body,
    String? summary,
    String? payload,
    bool incoming = true,
    String? dedupeKey,
  }) {
    final presentation = NativeNotificationPresentation(
      title: title,
      body: body,
      summary: summary ?? (incoming ? 'Recebimento' : 'Envio'),
      channelId: NativeNotificationChannels.transactions,
      family: incoming
          ? NativeNotificationFamily.transactionIncoming
          : NativeNotificationFamily.transactionOutgoing,
      highPriority: true,
      accentColor:
          incoming ? KeroseneBrandTokens.success : KeroseneBrandTokens.warning,
      payload: payload,
      dedupeKey: dedupeKey ?? _nativeDedupeKey(title: title, body: body),
    );
    return showPresented(presentation);
  }

  Future<void> showSubtleNotification({
    required int id,
    required String title,
    required String body,
  }) {
    return showFromBackendEvent(
      id: 'subtle-$id',
      kind: SessionNotificationItem.kindSystemInfo,
      title: title,
      body: body,
    );
  }

  String _channelName(String id) {
    return switch (id) {
      NativeNotificationChannels.security =>
        NativeNotificationChannels.securityName,
      NativeNotificationChannels.system =>
        NativeNotificationChannels.systemName,
      NativeNotificationChannels.foreground =>
        NativeNotificationChannels.foregroundName,
      _ => NativeNotificationChannels.transactionsName,
    };
  }

  String _channelDescription(String id) {
    return switch (id) {
      NativeNotificationChannels.security =>
        NativeNotificationChannels.securityDesc,
      NativeNotificationChannels.system =>
        NativeNotificationChannels.systemDesc,
      NativeNotificationChannels.foreground =>
        NativeNotificationChannels.foregroundDesc,
      _ => NativeNotificationChannels.transactionsDesc,
    };
  }

  int _stableId(String key) {
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    final id = hash & 0x7fffffff;
    return id == 0 ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : id;
  }

  String _nativeDedupeKey({required String title, required String body}) {
    final normalizedBody = _normalizeNotificationText(body);
    if (normalizedBody.isNotEmpty) {
      return normalizedBody;
    }
    return _normalizeNotificationText(title);
  }

  String _normalizeNotificationText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _shouldSuppressNativeNotification(String key) {
    if (key.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    _lastNativeNotificationShownAt.removeWhere(
      (_, shownAt) => now.difference(shownAt) > _nativeDedupeWindow,
    );

    final lastShownAt = _lastNativeNotificationShownAt[key];
    if (lastShownAt != null &&
        now.difference(lastShownAt) <= _nativeDedupeWindow) {
      return true;
    }

    _lastNativeNotificationShownAt[key] = now;
    return false;
  }
}
