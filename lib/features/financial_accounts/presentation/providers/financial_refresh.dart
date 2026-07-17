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
/// Call after send/pay/withdraw, WS notifications, pull-to-refresh, and the
/// periodic financial loop. History is never wiped here — only re-pulled and
/// merged into the durable local projection.
///
/// [forceFullHistory] resets the `?since=` cursor so the next pull is a full
/// page 0 (use on manual pull-to-refresh).
///
/// [scope] defaults to [FinancialRefreshScope.full] for money-move / manual
/// paths; the background poll uses [FinancialRefreshScope.light].
Future<void> refreshFinancialProjection(
  Ref ref, {
  bool forceFullHistory = false,
  FinancialRefreshScope scope = FinancialRefreshScope.full,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return;
  }
  if (forceFullHistory) {
    ref.read(transactionHistoryCursorProvider.notifier).reset();
  }
  await _kickRefresh(ref, scope: scope);
}

/// WidgetRef entrypoint — same contract as [refreshFinancialProjection].
Future<void> refreshFinancialProjectionUi(
  WidgetRef ref, {
  bool forceFullHistory = false,
  FinancialRefreshScope scope = FinancialRefreshScope.full,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return;
  }
  if (forceFullHistory) {
    ref.read(transactionHistoryCursorProvider.notifier).reset();
  }
  await _kickRefreshUi(ref, scope: scope);
}

Future<void> _kickRefresh(
  Ref ref, {
  required FinancialRefreshScope scope,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) return;

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

  final historyFuture = ref.read(transactionHistoryProvider.future);
  await Future.wait<void>([
    walletNotifier.refresh(),
    historyFuture.then((_) {}, onError: (_) {}),
  ]);
}

Future<void> _kickRefreshUi(
  WidgetRef ref, {
  required FinancialRefreshScope scope,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) return;

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

  final historyFuture = ref.read(transactionHistoryProvider.future);
  await Future.wait<void>([
    walletNotifier.refresh(),
    historyFuture.then((_) {}, onError: (_) {}),
  ]);
}
