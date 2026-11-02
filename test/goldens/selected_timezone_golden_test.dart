import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/localization/app_timezone_scope.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../features/movement/activity/statement_timezone_journey_test.dart'
    as fixture;
import 'golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final detail in [false, true]) {
      testGoldens('selected timezone and full amounts: $theme detail=$detail',
          (tester) async {
        final tx = fixture.timezoneJourneyFixture(
            'public-registration-operation-1234567890',
            DateTime.utc(2020, 1, 1, 1));
        await pumpFullScreenGolden(
            tester,
            ProviderScope(
                overrides: [
                  transactionHistoryProvider.overrideWith((ref) async => [tx]),
                  moneyFormatConfigProvider.overrideWithValue(
                      const MoneyFormatConfig(
                          currency: Currency.btc,
                          locale: Locale('pt'),
                          btcDecimalPlaces: 2)),
                ],
                child: Theme(
                  data: AppTheme.themeFor(theme),
                  child: AppTimezoneScope(
                      timeZoneId: 'America/New_York',
                      child: MediaQuery(
                        data: const MediaQueryData(
                            size: Size(320, 1550),
                            textScaler: TextScaler.linear(1.4),
                            disableAnimations: true),
                        child: detail
                            ? TransactionDetailScreen(transaction: tx)
                            : const TransactionStatementScreen(),
                      )),
                )),
            size: const Size(320, 1550));
        await screenMatchesGolden(tester,
            'selected_timezone_${detail ? 'detail' : 'statement'}_${theme.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
