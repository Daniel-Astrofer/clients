import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/services/bitcoin_market_chart_service.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/home/presentation/providers/home_bitcoin_market_chart_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_bitcoin_market_chart_card.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/widgets/global_notification_host.dart';
import 'golden_harness.dart';

final _sample = SessionNotificationItem(
    id: 'public-fixture-event',
    title: 'Revise a atividade da conta',
    body:
        'Dados fictícios para revisão visual. Consulte o estado da operação antes de tentar novamente. Referência pública: public-operation-1234567890-abcdef.',
    timestamp: DateTime.utc(2020),
    kind: SessionNotificationItem.kindSystemInfo,
    severity: SessionNotificationItem.severityWarning);

class _Feed extends SessionNotificationFeedNotifier {
  @override
  List<SessionNotificationItem> build() => [_sample];
}

class _KnownSync extends SessionNotificationSyncNotifier {
  @override
  SessionNotificationSyncState build() => SessionNotificationSyncState(
      hydrated: true, lastSyncedAt: DateTime.utc(2020, 1, 2, 3, 4, 5));
}

void main() {
  setUpAll(initializeGoldenHarness);
  tearDown(AppScreenFeedbackBus.clear);
  for (final theme in AppThemeVariant.values) {
    for (final surface in ['banner', 'sidebar', 'feedback']) {
      testGoldens('notification surface $surface $theme', (tester) async {
        await pumpFullScreenGolden(
            tester,
            ProviderScope(
                overrides: [
                  sessionNotificationFeedProvider.overrideWith(_Feed.new),
                  sessionNotificationSyncProvider.overrideWith(_KnownSync.new),
                  sessionNotificationUnreadCountProvider.overrideWith((ref) =>
                      ref
                          .watch(sessionNotificationFeedProvider)
                          .where((item) => !item.read)
                          .length),
                ],
                child: Theme(
                    data: AppTheme.themeFor(theme),
                    child: MediaQuery(
                      data: const MediaQueryData(
                          size: Size(320, 740),
                          textScaler: TextScaler.linear(1.4),
                          disableAnimations: true),
                      child: const GlobalNotificationHost(
                          child: Scaffold(
                              body: Center(
                                  child: Text(
                                      'Dados fictícios • revisão de interface')))),
                    ))),
            size: const Size(320, 740));
        final container = ProviderScope.containerOf(
            tester.element(find.byType(GlobalNotificationHost)));
        if (surface == 'banner') {
          container.read(notificationBannerProvider.notifier).show(_sample);
        }
        if (surface == 'sidebar') {
          container.read(notificationSidebarProvider.notifier).open();
        }
        if (surface == 'feedback') {
          AppScreenFeedbackBus.show(
              type: AppNoticeType.success,
              title: 'Configuração salva',
              message:
                  'Mensagem fictícia para conferir contraste e leitura com texto ampliado.',
              duration: Duration.zero);
        }
        await tester.pumpAndSettle();
        await screenMatchesGolden(
            tester, 'notification_surface_${surface}_${theme.name}');
        expect(tester.takeException(), isNull);
        AppScreenFeedbackBus.clear();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
    testGoldens('market notice review remains readable: $theme',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await pumpFullScreenGolden(
          tester,
          MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: key,
              theme: AppTheme.themeFor(theme),
              locale: const Locale('pt'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: child!),
              home: const Scaffold(
                  body: Center(child: Text('Dados fictícios • revisão')))),
          size: const Size(320, 740));
      final item = SessionNotificationItem(
          id: 'fixture-market',
          title: 'Cotação registrada',
          body: 'Dados fictícios para revisão de interface.',
          timestamp: DateTime.utc(2020),
          kind: SessionNotificationItem.kindMarketAlert,
          deeplink: '/market',
          metadata: const {
            'priceUsd': '123456.789123',
            'dailyChangePercent': '-2.123456',
            'thresholdPercent': '0.013579',
            'source': 'Dados fictícios para revisão'
          });
      final opening =
          NotificationNavigation.openWithNavigator(item, key.currentState!);
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'notification_review_market_${theme.name}');
      expect(tester.takeException(), isNull);
      key.currentState!.pop(false);
      await tester.pumpAndSettle();
      await opening;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    for (final expanded in [false, true]) {
      for (final rising in [true, false]) {
        if (expanded && !rising) continue;
        testGoldens(
            'monochrome market direction $rising $theme expanded=$expanded',
            (tester) async {
          const request = BitcoinMarketChartRequest(
              symbol: 'BTCBRL',
              quoteCurrency: Currency.brl,
              range: BitcoinMarketChartRange.oneDay);
          final snapshot = BitcoinMarketChartSnapshot(
              request: request,
              points: [
                BitcoinMarketChartPoint(
                    time: DateTime.utc(2020, 1, 1, 10), price: 350000),
                BitcoinMarketChartPoint(
                    time: DateTime.utc(2020, 1, 1, 11),
                    price: rising ? 357000 : 343000),
              ],
              lastUpdatedAt: DateTime.utc(2020, 1, 1, 11),
              isLive: false);
          await pumpFullScreenGolden(
              tester,
              ProviderScope(
                  overrides: [
                    homeBitcoinMarketChartProvider
                        .overrideWith((ref) => Stream.value(snapshot)),
                    homeBitcoinMarketChartRequestProvider
                        .overrideWithValue(request),
                    moneyFormatConfigProvider.overrideWithValue(
                        const MoneyFormatConfig(
                            currency: Currency.brl, locale: Locale('pt'))),
                  ],
                  child: Theme(
                      data: AppTheme.themeFor(theme),
                      child: MediaQuery(
                        data: MediaQueryData(
                            size: Size(expanded ? 320 : 390, 740),
                            textScaler: TextScaler.linear(expanded ? 2.0 : 1.2),
                            disableAnimations: true),
                        child: const Scaffold(
                            body: Padding(
                                padding: EdgeInsets.all(20),
                                child: HomeBitcoinMarketChartCard())),
                      ))),
              size: Size(expanded ? 320 : 390, 740));
          if (expanded) {
            final plot = find.byWidgetPredicate((widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() ==
                    '_BitcoinMarketChartPainter');
            await tester.tapAt(tester.getTopRight(plot) + const Offset(-9, 60));
            await tester.pumpAndSettle();
          }
          await screenMatchesGolden(tester,
              'market_direction_${rising ? 'up' : 'down'}_${theme.name}${expanded ? '_expanded' : ''}');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
