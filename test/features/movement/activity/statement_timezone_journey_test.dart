import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/localization/app_timezone_scope.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../../../goldens/golden_harness.dart';

Transaction timezoneJourneyFixture(String id, DateTime at) => Transaction(
    id: id,
    fromAddress: 'public-sender',
    toAddress: 'public-recipient',
    amountSatoshis: 123456789,
    feeSatoshis: 0,
    status: TransactionStatus.confirmed,
    type: TransactionType.receive,
    confirmations: 6,
    timestamp: at);

void main() {
  setUpAll(initializeGoldenHarness);
  testWidgets('statement group and detail use the same selected date',
      (tester) async {
    final transactions = [
      timezoneJourneyFixture('first-january', DateTime.utc(2020, 1, 1, 8)),
      timezoneJourneyFixture('last-december', DateTime.utc(2020, 1, 1, 1)),
      timezoneJourneyFixture('another-december', DateTime.utc(2020, 1, 1, 0)),
    ];
    final zone = ValueNotifier('America/New_York');
    addTearDown(zone.dispose);
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              transactionHistoryProvider
                  .overrideWith((ref) async => transactions),
            ],
            child: ValueListenableBuilder<String>(
              valueListenable: zone,
              builder: (_, id, child) =>
                  AppTimezoneScope(timeZoneId: id, child: child!),
              child: const TransactionStatementScreen(),
            )),
        size: const Size(390, 2200));
    final context = tester.element(find.byType(TransactionStatementScreen));
    final january = AppDateTime.formatDate(context, transactions[0].timestamp);
    final december = AppDateTime.formatDate(context, transactions[1].timestamp);
    expect(january, isNot(december));
    expect(find.text(january), findsOneWidget);
    expect(find.text(december), findsOneWidget);
    // Both December operations share one heading, despite UTC being January.
    zone.value = 'UTC';
    await tester.pump();
    expect(find.text(december), findsNothing);
    expect(
        find.text(AppDateTime.formatDate(context, transactions[1].timestamp)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              moneyFormatConfigProvider.overrideWithValue(
                  const MoneyFormatConfig(
                      currency: Currency.btc,
                      locale: Locale('pt'),
                      btcDecimalPlaces: 2)),
            ],
            child: AppTimezoneScope(
              timeZoneId: 'America/New_York',
              child: TransactionDetailScreen(transaction: transactions[1]),
            )),
        size: const Size(390, 1700));
    final detailContext = tester.element(find.byType(TransactionDetailScreen));
    expect(
        find.text(
            AppDateTime.formatFull(detailContext, transactions[1].timestamp)),
        findsOneWidget);
    expect(find.textContaining('1,23456789'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('details action remains legible in a light statement row',
      (tester) async {
    final tx =
        timezoneJourneyFixture('light-fixture', DateTime.utc(2020, 1, 1, 1));
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              transactionHistoryProvider.overrideWith((ref) async => [tx]),
            ],
            child: Theme(
              data: AppTheme.themeFor(AppThemeVariant.light),
              child: const TransactionStatementScreen(),
            )),
        size: const Size(390, 1700));
    expect(find.text('Confirmada'), findsOneWidget);
    final paragraph =
        tester.renderObject<RenderParagraph>(find.text('Ver detalhes'));
    final text = paragraph.text as TextSpan;
    final foreground = text.style!.color!;
    final background =
        AppTheme.themeFor(AppThemeVariant.light).colorScheme.surface;
    final high = background.computeLuminance();
    final low = foreground.computeLuminance();
    expect((high + 0.05) / (low + 0.05), greaterThan(4.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
      'UTC statement keeps consecutive dates independent of device calendar',
      (tester) async {
    final transactions = [
      timezoneJourneyFixture('day-after', DateTime.utc(2011, 12, 31, 12)),
      timezoneJourneyFixture('day-before', DateTime.utc(2011, 12, 30, 12)),
    ];
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              transactionHistoryProvider
                  .overrideWith((ref) async => transactions),
            ],
            child: const AppTimezoneScope(
                timeZoneId: 'UTC', child: TransactionStatementScreen())),
        size: const Size(390, 2200));
    final context = tester.element(find.byType(TransactionStatementScreen));
    for (final tx in transactions) {
      expect(find.text(AppDateTime.formatDate(context, tx.timestamp)),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
