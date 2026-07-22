import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// How much of the financial projection to reload.
enum FinancialRefreshScope {
  /// Wallets + transaction history only (periodic poll / WS balance tick).
  light,

  /// Full invalidate of deposits, payment links, external transfers, etc.
  full,
}

/// Single entrypoint: balance + extrato refresh together (reactive parity).
///
/// Returns `true` only when **both** wallet and history pulls succeed. Under Tor
/// latency (and assuming kfe→server fan-out is similarly slow), callers must
/// keep [financialDirtyProvider] set until this returns true.
///
/// [forceFullHistory] resets the `?since=` cursor **and** arms a one-shot full
/// page-0 pull (use on manual pull-to-refresh / reconnect catch-up).
Future<bool> refreshFinancialProjection(
  Ref ref, {
  bool forceFullHistory = false,
  FinancialRefreshScope scope = FinancialRefreshScope.full,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return false;
  }
  if (forceFullHistory) {
    ref.read(transactionHistoryCursorProvider.notifier).reset();
    ref.read(transactionHistoryForceFullProvider.notifier).arm();
  }
  return _kickRefresh(ref, scope: scope);
}

/// WidgetRef entrypoint — same contract as [refreshFinancialProjection].
Future<bool> refreshFinancialProjectionUi(
  WidgetRef ref, {
  bool forceFullHistory = false,
  FinancialRefreshScope scope = FinancialRefreshScope.full,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return false;
  }
  if (forceFullHistory) {
    ref.read(transactionHistoryCursorProvider.notifier).reset();
    ref.read(transactionHistoryForceFullProvider.notifier).arm();
  }
  return _kickRefreshUi(ref, scope: scope);
}

Future<bool> _kickRefresh(
  Ref ref, {
  required FinancialRefreshScope scope,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) return false;

  final walletNotifier = ref.read(walletProvider.notifier);

  ref.invalidate(ledgerRepositoryProvider);
  ref.invalidate(transactionHistoryProvider);
  ref.invalidate(pagedTransactionHistoryProvider);
  ref.invalidate(localTransactionHistoryProvider);

  if (scope == FinancialRefreshScope.full) {
    ref.invalidate(depositsProvider);
    ref.invalidate(depositBalanceProvider);
    ref.invalidate(depositDetailProvider);
    ref.invalidate(externalTransfersProvider);
    ref.invalidate(externalTransferDetailProvider);
    ref.invalidate(paymentLinksProvider);
    ref.invalidate(txStatusProvider);
    ref.invalidate(bitcoinAccountsProvider);
  }

  var walletsOk = false;
  var historyOk = false;

  try {
    await walletNotifier.refresh();
    walletsOk = true;
  } catch (_) {}

  try {
    await ref.read(transactionHistoryProvider.future);
    historyOk = true;
  } catch (_) {}

  return walletsOk && historyOk;
}

Future<bool> _kickRefreshUi(
  WidgetRef ref, {
  required FinancialRefreshScope scope,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) return false;

  final walletNotifier = ref.read(walletProvider.notifier);

  ref.invalidate(ledgerRepositoryProvider);
  ref.invalidate(transactionHistoryProvider);
  ref.invalidate(pagedTransactionHistoryProvider);
  ref.invalidate(localTransactionHistoryProvider);

  if (scope == FinancialRefreshScope.full) {
    ref.invalidate(depositsProvider);
    ref.invalidate(depositBalanceProvider);
    ref.invalidate(depositDetailProvider);
    ref.invalidate(externalTransfersProvider);
    ref.invalidate(externalTransferDetailProvider);
    ref.invalidate(paymentLinksProvider);
    ref.invalidate(txStatusProvider);
    ref.invalidate(bitcoinAccountsProvider);
  }

  var walletsOk = false;
  var historyOk = false;

  try {
    await walletNotifier.refresh();
    walletsOk = true;
  } catch (_) {}

  try {
    await ref.read(transactionHistoryProvider.future);
    historyOk = true;
  } catch (_) {}

  return walletsOk && historyOk;
}
