import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/locale_provider.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/entities/statement_report.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/services/statement_report_calculator.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// Merges remote statement history with durable on-device ledger.
List<Transaction> mergeInsightTransactions({
  required List<Transaction> remote,
  required List<Transaction> local,
}) {
  final byKey = <String, Transaction>{};

  String keyOf(Transaction tx) {
    final chain = tx.blockchainTxid?.trim() ?? '';
    if (chain.isNotEmpty) return 'chain:$chain';
    final hash = tx.paymentHash?.trim() ?? '';
    if (hash.isNotEmpty) return 'ph:$hash';
    return 'id:${tx.id.trim()}';
  }

  int score(Transaction tx) {
    var s = 0;
    if ((tx.blockchainTxid ?? '').isNotEmpty) s += 4;
    if (tx.feeSatoshis > 0) s += 1;
    if (tx.serviceFeeSatoshis > 0) s += 1;
    if ((tx.walletId ?? '').isNotEmpty) s += 1;
    if ((tx.sourceWalletId ?? '').isNotEmpty) s += 1;
    if ((tx.destinationWalletId ?? '').isNotEmpty) s += 1;
    return s;
  }

  void upsert(Transaction tx) {
    final key = keyOf(tx);
    final existing = byKey[key];
    if (existing == null || score(tx) >= score(existing)) {
      byKey[key] = tx;
    }
  }

  for (final tx in local) {
    upsert(tx);
  }
  for (final tx in remote) {
    upsert(tx);
  }

  final list = byKey.values.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return list;
}

/// Full insight report for the selected period (real accounts + merged history).
final statementInsightsReportProvider =
    FutureProvider.family<StatementReport, StatementReportPeriod>(
        (ref, period) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  final locale = ref.watch(localeProvider).locale;
  final remote = await ref.watch(transactionHistoryProvider.future);

  List<Transaction> local = const [];
  if (sessionScope != null && sessionScope.trim().isNotEmpty) {
    final store = ref.watch(localTransactionHistoryStoreProvider);
    local = await store.load(sessionScope);
  }

  final transactions = mergeInsightTransactions(remote: remote, local: local);

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
