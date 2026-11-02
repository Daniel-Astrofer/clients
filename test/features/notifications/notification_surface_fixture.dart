import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/localization/app_timezone_scope.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:kerosene/features/notifications/presentation/widgets/session_notification_sidebar.dart';
import '../../goldens/golden_harness.dart';

final noticeWithUnknownDate = SessionNotificationItem(
    id: 'public-undated-notice',
    title: 'Operação em verificação',
    body:
        'Dados fictícios para revisão. Referência completa: public-operation-1234567890-abcdefghijklmnopqrstuvwxyz-1234567890-abcdefghijklmnopqrstuvwxyz. Consulte o registro para acompanhar o estado.',
    timestamp: null,
    kind: SessionNotificationItem.kindPaymentReconciliationRequired);

class NotificationSurfaceFeed extends SessionNotificationFeedNotifier {
  int refreshes = 0;
  final bool success;
  NotificationSurfaceFeed({this.success = false});
  @override
  List<SessionNotificationItem> build() => [
        SessionNotificationItem(
            id: 'public-dated-notice',
            title: 'Dados da conta',
            body: 'Registro fictício para conferir leitura e contraste.',
            timestamp: DateTime.utc(2020, 1, 2, 3, 4, 5)),
        noticeWithUnknownDate,
      ];
  @override
  Future<bool> reloadFromServer() async {
    refreshes++;
    return success;
  }
}

class NotificationSurfaceSync extends SessionNotificationSyncNotifier {
  final SessionNotificationSyncState initial;
  NotificationSurfaceSync(this.initial);
  @override
  SessionNotificationSyncState build() => initial;
}

Future<void> pumpNotificationSurface(
  WidgetTester tester, {
  required AppThemeVariant theme,
  required SessionNotificationSyncState status,
  bool sidebar = false,
  NotificationSurfaceFeed? feed,
  Size size = const Size(320, 740),
}) async {
  await pumpFullScreenGolden(
      tester,
      ProviderScope(
          overrides: [
            sessionNotificationFeedProvider
                .overrideWith(() => feed ?? NotificationSurfaceFeed()),
            sessionNotificationSyncProvider
                .overrideWith(() => NotificationSurfaceSync(status)),
            sessionNotificationUnreadCountProvider.overrideWith((ref) => ref
                .watch(sessionNotificationFeedProvider)
                .where((item) => !item.read)
                .length),
          ],
          child: Theme(
              data: AppTheme.themeFor(theme),
              child: AppTimezoneScope(
                timeZoneId: 'UTC',
                child: MediaQuery(
                  data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: sidebar
                      ? const Scaffold(body: SessionNotificationSidebar())
                      : const NotificationCenterScreen(),
                ),
              ))),
      size: size);
}
