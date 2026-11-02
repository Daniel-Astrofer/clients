import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/localization/app_timezone_scope.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_transactions.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../features/wallet/transaction_list_test.dart' as fixture;
import 'golden_harness.dart';

class _FailedSync extends TransactionHistoryLastSyncNotifier {
  @override
  DateTime? build() {
    refreshFailed = true;
    return DateTime.utc(2026, 10, 17, 12);
  }
}

void main() {
  setUpAll(initializeGoldenHarness);
  for (final variant in AppThemeVariant.values) {
    for (final surface in ['home_sliver', 'home_column', 'statement']) {
      testGoldens('history refresh failure stays visible: $surface $variant',
          (tester) async {
        final rows = [fixture.walletHistoryFixture().transactions.last];
        final isSliver = surface == 'home_sliver';
        final home = HomeTransactionsList(
            asSliver: isSliver, onCreateWallet: () {}, onDepositWallet: (_) {});
        await pumpFullScreenGolden(
          tester,
          Theme(
            data: AppTheme.themeFor(variant),
            child: MediaQuery(
              data: const MediaQueryData(
                  size: Size(390, 1000),
                  textScaler: TextScaler.linear(1.5),
                  disableAnimations: true),
              child: AppTimezoneScope(
                timeZoneId: 'UTC',
                child: ProviderScope(
                  overrides: [
                    transactionHistoryProvider
                        .overrideWith((ref) async => rows),
                    lastTransactionHistoryProvider
                        .overrideWith(LastTransactionHistoryNotifier.new),
                    filteredHomeTransactionsProvider.overrideWith((ref) =>
                        mergeTransactionHistoryProjection(
                            remote: ref
                                .watch(transactionHistoryProvider)
                                .asData
                                ?.value,
                            last: ref.watch(lastTransactionHistoryProvider))),
                    transactionHistoryLastSyncProvider
                        .overrideWith(_FailedSync.new),
                    transactionHistoryReadinessProvider.overrideWith((ref) {
                      final time =
                          ref.watch(transactionHistoryLastSyncProvider);
                      return (
                        lastSyncedAt: time,
                        failed: true,
                        primaryLoaded: true
                      );
                    }),
                  ],
                  child: surface == 'statement'
                      ? const TransactionStatementScreen()
                      : Scaffold(
                          body: isSliver
                              ? CustomScrollView(slivers: [
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 20)),
                                  SliverPadding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      sliver: home),
                                ])
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: home)),
                ),
              ),
            ),
          ),
          size: const Size(390, 1000),
        );
        expect(
            find.text('Não foi possível atualizar o histórico').hitTestable(),
            findsOneWidget);
        await screenMatchesGolden(
            tester, 'history_sync_${surface}_${variant.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
