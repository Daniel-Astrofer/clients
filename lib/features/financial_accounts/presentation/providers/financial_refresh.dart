import 'dart:async';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/movement/providers/payment_submission_recovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
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
  if (!ref.mounted) return false;
  final account = ref.read(sessionStorageScopeProvider);
  if (account == null) return false;
  return ref
      .read(_financialProjectionRefreshProvider)
      .request(account, scope, forceFullHistory);
}

/// WidgetRef entrypoint — same contract as [refreshFinancialProjection].
Future<bool> refreshFinancialProjectionUi(
  WidgetRef ref, {
  bool forceFullHistory = false,
  FinancialRefreshScope scope = FinancialRefreshScope.full,
}) async {
  if (!ref.context.mounted) return false;
  final account = ref.read(sessionStorageScopeProvider);
  if (account == null) return false;
  return ref
      .read(_financialProjectionRefreshProvider)
      .request(account, scope, forceFullHistory);
}

final _financialProjectionRefreshProvider =
    Provider<_FinancialProjectionRefresh>((ref) {
  final refresh = _FinancialProjectionRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

class _RefreshBatch {
  final completion = Completer<bool>();
  bool pending = false;
  bool full = false;
  bool forceFullHistory = false;
  void merge(FinancialRefreshScope scope, bool force) {
    pending = true;
    full |= scope == FinancialRefreshScope.full;
    forceFullHistory |= force;
  }
}

/// Shared by widgets, reconnects and incoming events. A burst is one refresh;
/// events arriving during I/O request one follow-up before callers see success.
class _FinancialProjectionRefresh {
  _FinancialProjectionRefresh(this.ref);
  final Ref ref;
  final _batches = <String, _RefreshBatch>{};
  DateTime? _lastDrainFinished;

  bool _owns(String account) =>
      ref.mounted && ref.read(sessionStorageScopeProvider) == account;

  Future<bool> request(
      String account, FinancialRefreshScope scope, bool force) {
    final existing = _batches[account];
    if (existing != null) {
      existing.merge(scope, force);
      return existing.completion.future;
    }
    final batch = _RefreshBatch()..merge(scope, force);
    _batches[account] = batch;
    unawaited(_drain(account, batch));
    return batch.completion.future;
  }

  Future<void> _drain(String account, _RefreshBatch batch) async {
    var ok = false;
    try {
      while (batch.pending) {
        // Leave Riverpod's rebuild pass before invalidating projections or
        // publishing wallet state. A microtask is not a rendering boundary.
        await Future<void>.delayed(Duration.zero);
        if (!_owns(account)) {
          ok = false;
          break;
        }
        final scope = batch.full
            ? FinancialRefreshScope.full
            : FinancialRefreshScope.light;
        final force = batch.forceFullHistory;
        batch.pending = batch.full = batch.forceFullHistory = false;

        final now = DateTime.now();
        if (_lastDrainFinished != null &&
            now.difference(_lastDrainFinished!) < const Duration(seconds: 3) &&
            !force &&
            ok) {
          break;
        }

        if (force) {
          ref.read(transactionHistoryCursorProvider.notifier).reset();
          ref.read(transactionHistoryForceFullProvider.notifier).arm();
        }
        ok = await _kickRefresh(ref, scope: scope);
        if (ok) {
          _lastDrainFinished = DateTime.now();
        }
      }
      if (!batch.completion.isCompleted) {
        batch.completion.complete(ok && _owns(account));
      }
    } catch (error, stack) {
      if (!batch.completion.isCompleted) {
        batch.completion.completeError(error, stack);
      }
    } finally {
      if (identical(_batches[account], batch)) _batches.remove(account);
    }
  }

  void dispose() {
    for (final batch in _batches.values) {
      if (!batch.completion.isCompleted) batch.completion.complete(false);
    }
    _batches.clear();
  }
}

Future<bool> _kickRefresh(
  Ref ref, {
  required FinancialRefreshScope scope,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) return false;
  final account = ref.read(sessionStorageScopeProvider);

  final walletNotifier = ref.read(walletProvider.notifier);

  // The repository has no cached projection. Rebuilding it during a refresh
  // recursively invalidates consumers that are already rebuilding this frame.
  invalidateTransactionHistoryProjection(ref);
  ref.invalidate(localTransactionHistoryProvider);

  if (scope == FinancialRefreshScope.full) {
    ref.invalidate(depositsProvider);
    ref.invalidate(depositBalanceProvider);
    ref.invalidate(depositDetailProvider);
    ref.invalidate(externalTransfersProvider);
    ref.invalidate(externalTransferDetailProvider);
    ref.invalidate(paymentLinksProvider);
    ref.invalidate(txStatusProvider);
    unawaited(ref.read(bitcoinAccountsControllerProvider).refresh());
  }

  if (scope == FinancialRefreshScope.full) {
    ref.invalidate(pendingPaymentSubmissionsProvider);
    ref.invalidate(paymentSubmissionLookupProvider);
    unawaited(
        ref.read(sessionNotificationFeedProvider.notifier).reloadFromServer());
  } else {
    final account = ref.read(sessionStorageScopeProvider);
    if (account != null &&
        ref.exists(pendingPaymentSubmissionsProvider(account))) {
      final pending =
          ref.read(pendingPaymentSubmissionsProvider(account)).asData?.value ??
              [];
      for (final record
          in pending.where((record) => record.transactionId == null)) {
        final lookup =
            paymentSubmissionLookupProvider((account, record.key, null));
        if (ref.exists(lookup) && !ref.read(lookup).isLoading) {
          ref.invalidate(lookup);
        }
      }
    }
  }
  final previousSync = ref.read(transactionHistoryLastSyncProvider);
  var walletsOk = false;
  var historyOk = false;

  try {
    await walletNotifier.refresh();
    if (!ref.mounted || ref.read(sessionStorageScopeProvider) != account) {
      return false;
    }
    walletsOk = ref.read(walletProvider) is WalletLoaded;
  } catch (_) {}

  if (!ref.mounted || ref.read(sessionStorageScopeProvider) != account) {
    return false;
  }

  try {
    await ref.read(transactionHistoryProvider.future);
    if (!ref.mounted || ref.read(sessionStorageScopeProvider) != account) {
      return false;
    }
    historyOk = ref.read(transactionHistoryLastSyncProvider) != previousSync;
  } catch (_) {}

  return walletsOk && historyOk;
}
