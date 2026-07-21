import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/locale_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/data/entities/statement_report.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/statement_report_calculator.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// Legacy test helper — redirects to [TransactionLedgerAdapter] (id-keyed).
List<Transaction> mergeInsightTransactions({
  required List<Transaction> remote,
  required List<Transaction> local,
}) {
  return TransactionLedgerAdapter.mergeTransactionLists(
    localRows: local,
    remoteRows: remote,
  );
}

/// Full insight report for the selected period.
///
/// Uses **only** [transactionHistoryProvider] so insights and the extrato list
/// always share the same ids / confs / payment-link dedupe.
final statementInsightsReportProvider =
    FutureProvider.family<StatementReport, StatementReportPeriod>(
        (ref, period) async {
  final locale = ref.watch(localeProvider).locale;
  // Same projection as home/statement — no second merge.
  final transactions = await ref.watch(transactionHistoryProvider.future);

  final accounts = ref.watch(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];

  final walletState = ref.watch(walletProvider);
  final wallets = walletState is WalletLoaded
      ? walletState.wallets
      : const <Wallet>[];

  final languageTag = locale.toLanguageTag();
  final emptyWalletName = switch (locale.languageCode) {
    'en' => 'No wallets',
    'es' => 'Sin carteras',
    _ => 'Sem carteiras',
  };

  return StatementReportCalculator.calculate(
    transactions: transactions,
    accounts: accounts,
    wallets: wallets,
    period: period,
    locale: languageTag,
    emptyWalletName: emptyWalletName,
  );
});
