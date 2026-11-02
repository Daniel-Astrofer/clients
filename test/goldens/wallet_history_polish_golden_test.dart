import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/movement/presentation/activity/wallet_transaction_list.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import '../features/wallet/transaction_list_test.dart' as fixture;
import 'golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  for (final variant in AppThemeVariant.values) {
    testGoldens(
        'actual account history keeps expansion in both themes: $variant',
        (tester) async {
      final account = BitcoinAccount.fromJson({
        'id': 'wallet-history',
        'type': 'INTERNAL_CARD',
        'custody': 'INTERNAL',
        'status': 'ACTIVE',
        'label': 'Conta de uso diário',
      });
      final tx = Transaction.fromJson({
        ...fixture.walletHistoryFixture().transactions.last.toJson(),
        'walletId': account.id,
      });
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(variant),
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 740),
                      textScaler: TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: Scaffold(
                      body: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: FocusedAccountHistory(
                              account: account,
                              transactionsAsync: AsyncData([tx]),
                              requestsAsync: const AsyncData([])))))),
          size: const Size(320, 740));
      expect(find.byType(StatementTransactionCard), findsOneWidget);
      await screenMatchesGolden(tester, 'account_history_${variant.name}');
      await tester.tap(find
          .descendant(
              of: find.byType(StatementTransactionCard),
              matching: find.byType(InkWell))
          .first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<StatementTransactionCard>(
                  find.byType(StatementTransactionCard))
              .expanded,
          isTrue);
      await screenMatchesGolden(
          tester, 'account_history_expanded_${variant.name}');
      expect(tester.takeException(), isNull);
    });

    testGoldens('wallet history keeps the brand and complete values: $variant',
        (tester) async {
      await fixture.pumpWalletList(tester, fixture.walletHistoryFixture(),
          variant: variant, size: const Size(390, 844));
      await screenMatchesGolden(tester, 'wallet_history_${variant.name}');
      await fixture.pumpWalletList(
          tester,
          TransactionList(
              transactions: [fixture.walletHistoryFixture().transactions.last]),
          variant: variant,
          scale: 1.8);
      await screenMatchesGolden(
          tester, 'wallet_history_large_text_${variant.name}');
      expect(tester.takeException(), isNull);
    });
  }
}
