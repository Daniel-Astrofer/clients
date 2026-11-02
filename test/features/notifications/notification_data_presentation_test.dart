import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/widgets/notification_sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';
import 'notification_surface_fixture.dart';
import '../../goldens/golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  testWidgets('inbox without an account closes instead of loading forever',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              sessionStorageScopeProvider.overrideWithValue(null),
            ],
            child: Navigator(
                key: key,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                        body: Text('Public sign-in fixture'))))));
    unawaited(key.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const NotificationCenterScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Entre na sua conta para consultar as notificações.'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Public sign-in fixture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final theme in AppThemeVariant.values) {
    testWidgets(
        'failed lookup retains readable complete notices and query time in $theme',
        (tester) async {
      final feed = NotificationSurfaceFeed();
      await pumpNotificationSurface(tester,
          theme: theme,
          feed: feed,
          status: SessionNotificationSyncState(
              hydrated: true,
              failed: true,
              lastSyncedAt: DateTime.utc(2020, 1, 2, 3, 4, 5)));
      expect(find.text('Atualização indisponível'), findsOneWidget);
      expect(find.textContaining('As notificações conhecidas'), findsOneWidget);
      expect(find.textContaining('Última consulta:'), findsOneWidget);
      final body = find.text(noticeWithUnknownDate.body);
      await tester.scrollUntilVisible(body, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Data não informada'), findsWidgets);
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(body);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.widget<Text>(body).maxLines, isNull);
      final title = find.text(noticeWithUnknownDate.title);
      final ink = tester.widget<Ink>(
          find.ancestor(of: title, matching: find.byType(Ink)).first);
      expect((ink.decoration as BoxDecoration).color,
          KeroseneBrandTheme.of(tester.element(title)).surface);
      final retry = find.descendant(
          of: find.byType(NotificationSyncStatus),
          matching: find.byType(TextButton));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(feed.refreshes, 2);
      expect(tester.takeException(), isNull);
    });
    testWidgets('recognized query keeps an explicit refresh action in $theme',
        (tester) async {
      final feed = NotificationSurfaceFeed(success: true);
      await pumpNotificationSurface(tester,
          theme: theme,
          feed: feed,
          status: SessionNotificationSyncState(
              hydrated: true, lastSyncedAt: DateTime.utc(2020, 1, 2, 3, 4, 5)));
      expect(find.byTooltip('Atualizar notificações'), findsOneWidget);
      await tester.tap(find.byTooltip('Atualizar notificações'));
      await tester.pump();
      expect(feed.refreshes, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
