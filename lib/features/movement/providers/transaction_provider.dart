import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/security/device_credential_capabilities.dart';
import 'package:kerosene/core/security/device_credential_enroll_policy.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/core/services/sovereign_auth_service.dart';
import 'package:kerosene/core/telemetry/device_credential_telemetry.dart';
import 'package:kerosene/core/telemetry/ledger_telemetry.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show authControllerProvider, sessionStorageScopeProvider;
import 'package:kerosene/features/auth/controller/auth_providers.dart'
    show authRepositoryProvider;
import 'package:kerosene/features/auth/presentation/state/auth_state.dart';
import 'package:kerosene/features/ledger/domain/local_ledger_sync.dart';
import 'package:kerosene/features/ledger/domain/transaction_ledger_adapter.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/domain/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/domain/entities/deposit.dart';
import 'package:kerosene/features/movement/domain/entities/external_transfer.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/wallet_network_address.dart';
import 'package:kerosene/features/security/domain/entities/passkey_action_required.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show ledgerRepositoryProvider, walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/providers/transaction_data_providers.dart';
export 'package:kerosene/features/movement/providers/transaction_data_providers.dart';

const _paymentLinkSelfPayException = ValidationException(
  message: 'You cannot pay a link created by yourself.',
  errorCode: 'LEDGER_009',
);

/// Post money-move refresh without importing financial_refresh (cycle-safe).
Future<void> _refreshAfterMoneyMoved(Ref ref) async {
  ref.read(transactionHistoryCursorProvider.notifier).reset();
  ref.invalidate(transactionHistoryProvider);
  ref.invalidate(pagedTransactionHistoryProvider);
  ref.invalidate(depositsProvider);
  ref.invalidate(depositBalanceProvider);
  ref.invalidate(paymentLinksProvider);
  ref.invalidate(externalTransfersProvider);
  await Future.wait<void>([
    ref.read(walletProvider.notifier).refresh(),
    ref.read(transactionHistoryProvider.future).then((_) {}, onError: (_) {}),
  ]);
}

// ==================== Filter Logic ====================

enum TransactionFilter {
  all('Tudo'),
  send('Enviadas'),
  receive('Recebidas');

  final String label;
  const TransactionFilter(this.label);
}

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.all;

  void updateFilter(TransactionFilter filter) => state = filter;
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
        TransactionFilterNotifier.new);

final walletNetworkProfileProvider =
    FutureProvider.family<WalletNetworkAddress, String>(
        (ref, walletName) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getWalletNetworkProfile(walletName: walletName);
});

List<Transaction> _mergeExternalHistory({
  required List<Transaction> kfeTransactions,
  required List<ExternalTransfer> externalTransfers,
  required List<PaymentLink> paymentLinks,
}) {
  // Only links with movement (paid / detecting / completed). Pure open quotes
  // stay in the payment-link product UI, not the operational extrato.
  final linkRows = paymentLinks
      .where(
        (l) =>
            l.isPaid ||
            l.isCompleted ||
            l.hasObservedOnchainPayment ||
            l.isValidatingSettlement,
      )
      .map((l) => l.toTransaction())
      .toList(growable: false);
  final extras = <Transaction>[
    ...externalTransfers.map((t) => t.toTransaction()),
    ...linkRows,
  ];
  // Field-level merge (LOCAL_LEDGER_SYNC): remote KFE first, then extras as remote batch.
  final withKfe = TransactionLedgerAdapter.mergeTransactionLists(
    localRows: const [],
    remoteRows: kfeTransactions,
  );
  final merged = TransactionLedgerAdapter.mergeTransactionLists(
    localRows: withKfe,
    remoteRows: extras,
  );
  // Drop pl_* when KFE already has the settlement for the same chain ref.
  return TransactionLedgerAdapter.dedupePaymentLinkOverlays(merged);
}

/// Last successfully merged history (survives FutureProvider reloads).
final lastTransactionHistoryProvider =
    NotifierProvider<LastTransactionHistoryNotifier, List<Transaction>>(
  LastTransactionHistoryNotifier.new,
);

class LastTransactionHistoryNotifier extends Notifier<List<Transaction>> {
  @override
  List<Transaction> build() => const [];

  void set(List<Transaction> value) => state = List.unmodifiable(value);
}

/// Wall-clock of the last successful history merge (local or remote).
final transactionHistoryLastSyncProvider =
    NotifierProvider<TransactionHistoryLastSyncNotifier, DateTime?>(
  TransactionHistoryLastSyncNotifier.new,
);

class TransactionHistoryLastSyncNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void touch() => state = DateTime.now();
}

/// Max server `updatedAt` seen in the last successful remote batch (for `?since=`).
final transactionHistoryCursorProvider =
    NotifierProvider<TransactionHistoryCursorNotifier, DateTime?>(
  TransactionHistoryCursorNotifier.new,
);

class TransactionHistoryCursorNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void advance(Iterable<Transaction> rows) {
    DateTime? maxAt = state;
    for (final tx in rows) {
      final at = tx.effectiveUpdatedAt.toUtc();
      if (maxAt == null || at.isAfter(maxAt)) {
        maxAt = at;
      }
    }
    if (maxAt != null) {
      state = maxAt;
    }
  }

  void reset() => state = null;
}

/// Kept for tests / call-sites that still score address completeness.
int transactionAddressCompletenessBonus(Transaction transaction) {
  var score = 0;

  if (transaction.fromAddress.trim().isNotEmpty) {
    score += 2;
  }
  if (transaction.toAddress.trim().isNotEmpty) {
    score += 2;
  }
  if ((transaction.lightningInvoice ?? '').trim().isNotEmpty) {
    score += 2;
  }
  if ((transaction.externalTransferId ?? '').trim().isNotEmpty) {
    score += 2;
  }

  return score;
}

Future<List<ExternalTransfer>> _loadExternalTransfersSafely(Ref ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    return const <ExternalTransfer>[];
  }

  try {
    return await ref
        .watch(transactionRepositoryProvider)
        .getExternalTransfers();
  } catch (_) {
    return const <ExternalTransfer>[];
  }
}

Future<List<PaymentLink>> _loadPaymentLinksSafely(Ref ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    return const <PaymentLink>[];
  }

  try {
    return await ref.watch(transactionRepositoryProvider).getPaymentLinks();
  } catch (_) {
    return const <PaymentLink>[];
  }
}

// ==================== Transaction History (API) ====================

/// Busca o histórico de transações a partir do dashboard KFE.
///
/// O cache fica indexado pelo escopo da sessão para impedir que histórico de uma
/// conta seja reutilizado por outra após troca de usuário no mesmo app.
final transactionHistoryProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <Transaction>[];
  }
  return ref.watch(_scopedTransactionHistoryProvider(sessionScope).future);
});

final _scopedTransactionHistoryProvider =
    FutureProvider.family<List<Transaction>, String>((ref, sessionScope) async {
  final ledgerRepo = ref.watch(ledgerRepositoryProvider);
  final localStore = ref.watch(localTransactionHistoryStoreProvider);
  final ledgerSync = LocalLedgerSync(localStore);
  final localCached = await localStore.load(sessionScope);

  // Incremental: only rows updated after last cursor when we already have local.
  final cursor = ref.read(transactionHistoryCursorProvider);
  DateTime? since;
  if (localCached.isNotEmpty && cursor != null) {
    // 90s skew buffer so clock/partition edges do not skip confs.
    since = cursor.toUtc().subtract(const Duration(seconds: 90));
  } else if (localCached.isNotEmpty) {
    DateTime? maxLocal;
    for (final tx in localCached) {
      final at = tx.effectiveUpdatedAt.toUtc();
      if (maxLocal == null || at.isAfter(maxLocal)) maxLocal = at;
    }
    if (maxLocal != null) {
      since = maxLocal.subtract(const Duration(seconds: 90));
    }
  }

  // Wider first page so open confs / recent activity stay in the live window.
  if (since != null) {
    // fire-and-forget counter
    // ignore: unawaited_futures
    LedgerTelemetry.recordIncrementalPull();
  } else {
    // ignore: unawaited_futures
    LedgerTelemetry.recordFullPull();
  }
  final result = await ledgerRepo.getHistory(page: 0, size: 100, since: since);
  final externalTransfers = await _loadExternalTransfersSafely(ref);
  final paymentLinks = await _loadPaymentLinksSafely(ref);

  return result.fold(
    (failure) async {
      // Offline / unreachable — serve secure local projection.
      if (localCached.isNotEmpty) {
        // ignore: unawaited_futures
        LedgerTelemetry.recordOfflineServed();
        ref.read(lastTransactionHistoryProvider.notifier).set(localCached);
        ref.read(transactionHistoryLastSyncProvider.notifier).touch();
        return localCached;
      }
      throw Exception(failure.message);
    },
    (transactions) async {
      final online = _mergeExternalHistory(
        kfeTransactions: transactions,
        externalTransfers: externalTransfers,
        paymentLinks: paymentLinks,
      );
      // Detect conf upgrades for telemetry (local 0 → remote N).
      if (localCached.isNotEmpty && online.isNotEmpty) {
        final localById = {
          for (final t in localCached) t.id: t.confirmations,
        };
        for (final t in online) {
          final prev = localById[t.id];
          if (prev != null && t.confirmations > prev) {
            // ignore: unawaited_futures
            LedgerTelemetry.recordMergeUpgraded();
            break;
          }
        }
      }
      // LocalLedgerSync: field-level merge + durable projection.
      final merged = await ledgerSync.hydrateAndMerge(
        sessionScope: sessionScope,
        remote: online,
      );
      ref.read(lastTransactionHistoryProvider.notifier).set(merged);
      ref.read(transactionHistoryLastSyncProvider.notifier).touch();
      ref.read(transactionHistoryCursorProvider.notifier).advance(transactions);
      return merged;
    },
  );
});

final pagedTransactionHistoryProvider =
    FutureProvider.family<List<Transaction>, ({int page, int size})>((
  ref,
  request,
) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <Transaction>[];
  }
  return ref.watch(_scopedPagedTransactionHistoryProvider((
    sessionScope: sessionScope,
    page: request.page,
    size: request.size,
  )).future);
});

final _scopedPagedTransactionHistoryProvider = FutureProvider.family<
    List<Transaction>,
    ({String sessionScope, int page, int size})>((ref, request) async {
  // Page 0 shares the same LocalLedgerSync projection as the main feed.
  if (request.page == 0) {
    final full = await ref.watch(transactionHistoryProvider.future);
    return full.take(request.size).toList(growable: false);
  }

  // Deeper pages are remote-only (not persisted); UI rarely paginates past 0.
  final ledgerRepo = ref.watch(ledgerRepositoryProvider);
  final result = await ledgerRepo.getHistory(
    page: request.page,
    size: request.size,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transactions) => transactions,
  );
});

/// Histórico filtrado por tipo
final filteredTransactionsProvider = Provider<AsyncValue<List<Transaction>>>((
  ref,
) {
  final historyAsync = ref.watch(transactionHistoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  return historyAsync.whenData((txs) {
    switch (filter) {
      case TransactionFilter.all:
        return txs;
      case TransactionFilter.send:
        return txs
            .where(
              (tx) =>
                  tx.type == TransactionType.send ||
                  tx.type == TransactionType.withdrawal,
            )
            .toList();
      case TransactionFilter.receive:
        return txs
            .where(
              (tx) =>
                  tx.type == TransactionType.receive ||
                  tx.type == TransactionType.deposit,
            )
            .toList();
    }
  });
});

final transactionsByWalletProvider =
    FutureProvider.family<List<Transaction>, String>((ref, address) async {
  final historyAsync = await ref.watch(transactionHistoryProvider.future);
  return historyAsync
      .where((tx) => tx.fromAddress == address || tx.toAddress == address)
      .toList();
});

// ==================== Fee Estimation ====================

final feeEstimateProvider = FutureProvider.family<FeeEstimate, double>((
  ref,
  amount,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.estimateFee(amount);
});

// ==================== Transaction Status ====================

final txStatusProvider = FutureProvider.family<TxStatus, String>((
  ref,
  txid,
) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    throw Exception('Nao autenticado');
  }

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTransactionStatus(txid);
});

// ==================== Deposit Address ====================

final depositAddressProvider = FutureProvider<String>((ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    throw Exception('Nao autenticado');
  }

  final repo = ref.watch(transactionRepositoryProvider);
  final walletState = ref.watch(walletProvider);

  if (walletState is WalletLoaded && walletState.wallets.isNotEmpty) {
    final walletName = walletState.wallets.first.name.trim();
    if (walletName.isNotEmpty) {
      try {
        final profile =
            await repo.getWalletNetworkProfile(walletName: walletName);
        final onchainAddress = profile.onchainAddress.trim();
        if (onchainAddress.isNotEmpty) {
          return onchainAddress;
        }
      } catch (error) {
        throw Exception(
            'Nao foi possivel carregar o endereco on-chain real: $error');
      }
    }
  }

  throw Exception(
      'Nenhuma carteira com perfil de rede disponivel para deposito.');
});

// ==================== Deposits ====================

final depositsProvider = FutureProvider<List<Deposit>>((ref) async {
  final historyAsync = await ref.watch(transactionHistoryProvider.future);
  return historyAsync
      .where((t) =>
          t.type == TransactionType.receive ||
          t.type == TransactionType.deposit)
      .map((t) => Deposit(
            id: t.id.hashCode,
            userId: 0,
            txid: t.id,
            fromAddress: t.fromAddress,
            toAddress: t.toAddress,
            amountBtc: t.amountSatoshis / 100000000,
            confirmations: t.confirmations,
            status: t.status == TransactionStatus.confirmed
                ? 'credited'
                : 'pending',
            createdAt: t.timestamp,
          ))
      .toList();
});

final depositBalanceProvider = FutureProvider<double>((ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    return 0.0;
  }

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getDepositBalance();
});

final depositDetailProvider = FutureProvider.family<Deposit, String>((
  ref,
  txid,
) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    throw Exception('Nao autenticado');
  }

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getDeposit(txid);
});

// ==================== Payment Links ====================

final paymentLinksProvider = FutureProvider<List<PaymentLink>>((ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    return const <PaymentLink>[];
  }

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getPaymentLinks();
});

final externalTransfersProvider = FutureProvider<List<ExternalTransfer>>((
  ref,
) async {
  if (ref.watch(sessionStorageScopeProvider) == null) {
    return const <ExternalTransfer>[];
  }

  final repo = ref.watch(transactionRepositoryProvider);
  final transfers = await repo.getExternalTransfers();
  final sorted = List<ExternalTransfer>.from(transfers)
    ..sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  return sorted;
});

final externalTransferDetailProvider =
    FutureProvider.family<ExternalTransfer, String>((ref, transferId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getExternalTransfer(transferId);
});

// ==================== Action Notifiers ====================

/// State for async operations
class AsyncActionState {
  final bool isLoading;
  final String? error;
  final dynamic result;

  const AsyncActionState({this.isLoading = false, this.error, this.result});

  AsyncActionState copyWith({bool? isLoading, String? error, dynamic result}) {
    return AsyncActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

/// Notifier para envio de transações Bitcoin
class SendTransactionNotifier extends Notifier<AsyncActionState> {
  late TransactionRepository _repository;

  @override
  AsyncActionState build() {
    _repository = ref.watch(transactionRepositoryProvider);
    return const AsyncActionState();
  }

  Future<TxStatus?> send({
    required String toAddress,
    required double amount,
    required int feeSatoshis,
    String? fromWalletId,
    String? fromAddress,
    String? context,
    String? passkeyAssertionJson,
    String? confirmationPassphrase,
    String? totpCode,
    String? idempotencyKey,
    int? requestTimestamp,
    String? appPin,
  }) async {
    state = const AsyncActionState(isLoading: true);
    try {
      final result = await _repository.sendTransaction(
        toAddress: toAddress,
        amount: amount,
        feeSatoshis: feeSatoshis,
        fromWalletId: fromWalletId,
        fromAddress: fromAddress,
        context: context,
        passkeyAssertionJson: passkeyAssertionJson,
        confirmationPassphrase: confirmationPassphrase,
        totpCode: totpCode,
        idempotencyKey: idempotencyKey,
        requestTimestamp: requestTimestamp,
        appPin: appPin,
      );

      // Refresh history from API after successful transaction
      await _refreshAfterMoneyMoved(ref);

      state = AsyncActionState(result: result);
      return result;
    } catch (e) {
      final stepUp = _extractStepUpChallenge(e);
      if (stepUp != null) {
        return _retrySendWithPasskeyChallenge(
          initialChallenge: stepUp.legacyChallenge,
          actionRequired: stepUp.actionRequired,
          toAddress: toAddress,
          amount: amount,
          feeSatoshis: feeSatoshis,
          fromWalletId: fromWalletId,
          fromAddress: fromAddress,
          context: context,
          confirmationPassphrase: confirmationPassphrase,
          totpCode: totpCode,
          idempotencyKey: idempotencyKey,
          requestTimestamp: requestTimestamp,
          appPin: appPin,
        );
      }

      state = AsyncActionState(error: e.toString());
      return null;
    }
  }

  Future<TxStatus?> _retrySendWithPasskeyChallenge({
    required String initialChallenge,
    PasskeyActionRequired? actionRequired,
    required String toAddress,
    required double amount,
    required int feeSatoshis,
    String? fromWalletId,
    String? fromAddress,
    String? context,
    String? confirmationPassphrase,
    String? totpCode,
    String? idempotencyKey,
    int? requestTimestamp,
    String? appPin,
  }) async {
    var challenge = initialChallenge;
    var stepUpAction = actionRequired;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final assertion = await buildTransactionalPasskeyAssertion(
          ref: ref,
          challenge: challenge,
          actionRequired: stepUpAction,
        );
        final result = await _repository.sendTransaction(
          toAddress: toAddress,
          amount: amount,
          feeSatoshis: feeSatoshis,
          fromWalletId: fromWalletId,
          fromAddress: fromAddress,
          context: context,
          passkeyAssertionJson: assertion.json,
          confirmationPassphrase: confirmationPassphrase,
          totpCode: totpCode,
          idempotencyKey: idempotencyKey,
          requestTimestamp: requestTimestamp,
          appPin: appPin,
        );
        await assertion.commitIfNeeded();

        await _refreshAfterMoneyMoved(ref);
        state = AsyncActionState(result: result);
        return result;
      } catch (signErr) {
        if (isAuthUserCancellation(signErr)) {
          state = const AsyncActionState();
          return null;
        }
        final renewed = _extractStepUpChallenge(signErr);
        if (renewed == null ||
            renewed.legacyChallenge == challenge ||
            attempt == 1) {
          state = AsyncActionState(error: signErr.toString());
          return null;
        }
        challenge = renewed.legacyChallenge;
        stepUpAction = renewed.actionRequired;
      }
    }
    return null;
  }

  void reset() => state = const AsyncActionState();
}

final sendTransactionProvider =
    NotifierProvider<SendTransactionNotifier, AsyncActionState>(
        SendTransactionNotifier.new);

/// Notifier para Payment Links
class PaymentLinkNotifier extends Notifier<AsyncActionState> {
  final Future<String> Function(String)? _passkeyAssertionBuilder;
  late TransactionRepository _repository;

  PaymentLinkNotifier({
    Future<String> Function(String)? passkeyAssertionBuilder,
  }) : _passkeyAssertionBuilder = passkeyAssertionBuilder;

  @override
  AsyncActionState build() {
    _repository = ref.watch(transactionRepositoryProvider);
    return const AsyncActionState();
  }

  Future<PaymentLink?> create({
    required double amount,
    required String receiverWalletName,
    int? expiresIn,
  }) async {
    state = const AsyncActionState(isLoading: true);
    try {
      final result = await _repository.createPaymentLink(
        amount: amount,
        description: 'Recebimento $receiverWalletName',
        expiresInMinutes: 60,
        visibility: 'PRIVATE',
        confirmationMode: 'USER_ACTION_REQUIRED',
        amountLocked: true,
        referenceLabel: receiverWalletName,
        metadata: {
          'walletName': receiverWalletName,
          'rail': 'ONCHAIN',
          'source': 'receive_flow',
        },
      );
      await _refreshAfterMoneyMoved(ref);
      state = AsyncActionState(result: result);
      return result;
    } catch (e) {
      state = AsyncActionState(error: e.toString());
      return null;
    }
  }

  Future<TxStatus?> pay({
    required String linkId,
    required String payerWalletId,
    String? totpCode,
    String? confirmationPassphrase,
    String? passkeyAssertionJson,
    String? idempotencyKey,
    String? appPin,
  }) async {
    state = const AsyncActionState(isLoading: true);
    final operationIdempotencyKey = idempotencyKey?.trim().isNotEmpty == true
        ? idempotencyKey!.trim()
        : const Uuid().v4();
    try {
      final link = await _repository.getPaymentLink(linkId);
      _ensurePaymentLinkPayable(link);
      final result = await _repository.withdraw(
        fromWalletName: payerWalletId,
        toAddress: _withdrawalDestination(link),
        paymentRequest: _paymentRequestPublicId(link),
        amount: link.amountBtc,
        description: link.description.isNotEmpty
            ? link.description
            : 'Pagamento de link',
        confirmationPassphrase: confirmationPassphrase,
        passkeyAssertionJson: passkeyAssertionJson,
        totpCode: totpCode,
        idempotencyKey: operationIdempotencyKey,
        appPin: appPin,
      );
      await _refreshAfterMoneyMoved(ref);
      state = AsyncActionState(result: result);
      return result;
    } catch (e) {
      final stepUp = _extractStepUpChallenge(e);
      if (stepUp != null) {
        return _retryPaymentLinkWithPasskeyChallenge(
          initialChallenge: stepUp.legacyChallenge,
          actionRequired: stepUp.actionRequired,
          linkId: linkId,
          payerWalletId: payerWalletId,
          confirmationPassphrase: confirmationPassphrase,
          totpCode: totpCode,
          idempotencyKey: operationIdempotencyKey,
          appPin: appPin,
        );
      }

      state = AsyncActionState(error: e.toString());
      return null;
    }
  }

  void _ensurePaymentLinkIsNotSelfPay(PaymentLink link) {
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      return;
    }
    final currentUserId = int.tryParse(authState.user.id.trim());
    if (currentUserId != null && currentUserId == link.userId) {
      throw _paymentLinkSelfPayException;
    }
  }

  void _ensurePaymentLinkPayable(PaymentLink link) {
    _ensurePaymentLinkIsNotSelfPay(link);
    final status = link.status.trim().toUpperCase();
    if (const {'PAID', 'COMPLETED', 'SETTLED'}.contains(status)) {
      throw const ValidationException(
        message: 'Payment link has already been paid.',
        statusCode: 409,
        errorCode: 'ERR_KFE_PAYMENT_LINK_ALREADY_PAID',
      );
    }
    if (link.terminal ||
        link.isExpired ||
        const {'CANCELLED', 'CANCELED', 'HIDDEN', 'EXPIRED'}.contains(status)) {
      throw const ValidationException(
        message: 'Payment link is no longer open.',
        statusCode: 409,
        errorCode: 'ERR_KFE_PAYMENT_LINK_NOT_OPEN',
      );
    }
  }

  String _withdrawalDestination(PaymentLink link) {
    if (link.paymentRail.trim().toUpperCase() != 'INTERNAL') {
      return link.depositAddress;
    }

    final destinationHash = link.destinationHash?.trim();
    if (destinationHash == null || destinationHash.isEmpty) {
      throw const ValidationException(
        message: 'Internal payment link destination is missing.',
        statusCode: 422,
        errorCode: 'ERR_KFE_PAYMENT_LINK_DESTINATION_MISSING',
      );
    }
    return destinationHash;
  }

  String? _paymentRequestPublicId(PaymentLink link) {
    if (link.paymentRail.trim().toUpperCase() != 'INTERNAL') {
      return null;
    }

    final publicId = link.id.trim();
    if (publicId.isEmpty) {
      throw const ValidationException(
        message: 'Internal payment link reference is missing.',
        statusCode: 422,
        errorCode: 'ERR_KFE_PAYMENT_LINK_REFERENCE_MISSING',
      );
    }
    return publicId;
  }

  Future<TxStatus?> _retryPaymentLinkWithPasskeyChallenge({
    required String initialChallenge,
    PasskeyActionRequired? actionRequired,
    required String linkId,
    required String payerWalletId,
    String? confirmationPassphrase,
    String? totpCode,
    required String idempotencyKey,
    String? appPin,
  }) async {
    var challenge = initialChallenge;
    var stepUpAction = actionRequired;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final link = await _repository.getPaymentLink(linkId);
        _ensurePaymentLinkPayable(link);
        final TransactionalPasskeyAssertion assertion;
        if (_passkeyAssertionBuilder != null) {
          assertion = TransactionalPasskeyAssertion(
            json: await _passkeyAssertionBuilder!(challenge),
          );
        } else {
          assertion = await buildTransactionalPasskeyAssertion(
            ref: ref,
            challenge: challenge,
            actionRequired: stepUpAction,
          );
        }
        final result = await _repository.withdraw(
          fromWalletName: payerWalletId,
          toAddress: _withdrawalDestination(link),
          paymentRequest: _paymentRequestPublicId(link),
          amount: link.amountBtc,
          description: link.description.isNotEmpty
              ? link.description
              : 'Pagamento de link',
          confirmationPassphrase: confirmationPassphrase,
          passkeyAssertionJson: assertion.json,
          totpCode: totpCode,
          idempotencyKey: idempotencyKey,
          appPin: appPin,
        );
        await assertion.commitIfNeeded();

        await _refreshAfterMoneyMoved(ref);
        state = AsyncActionState(result: result);
        return result;
      } catch (signErr) {
        if (isAuthUserCancellation(signErr)) {
          state = const AsyncActionState();
          return null;
        }
        final renewed = _extractStepUpChallenge(signErr);
        if (renewed == null ||
            renewed.legacyChallenge == challenge ||
            attempt == 1) {
          state = AsyncActionState(error: signErr.toString());
          return null;
        }
        challenge = renewed.legacyChallenge;
        stepUpAction = renewed.actionRequired;
      }
    }
    return null;
  }

  void reset() => state = const AsyncActionState();
}

final paymentLinkNotifierProvider =
    NotifierProvider<PaymentLinkNotifier, AsyncActionState>(
        () => PaymentLinkNotifier());

/// Notifier para Saques Externos
class WithdrawNotifier extends Notifier<AsyncActionState> {
  late TransactionRepository _repository;

  @override
  AsyncActionState build() {
    _repository = ref.watch(transactionRepositoryProvider);
    return const AsyncActionState();
  }

  Future<TxStatus?> withdraw({
    required String fromWalletName,
    String? toAddress,
    String? paymentRequest,
    required double amount,
    String? totpCode,
    bool isLightning = false,
    double networkFeeBtc = 0,
    double maxRoutingFeeBtc = 0.000001,
    String? description,
    String? confirmationPassphrase,
    String? passkeyAssertionJson,
    String? idempotencyKey,
    String? appPin,
  }) async {
    state = const AsyncActionState(isLoading: true);
    final operationIdempotencyKey = idempotencyKey?.trim().isNotEmpty == true
        ? idempotencyKey!.trim()
        : const Uuid().v4();
    try {
      final result = await _repository.withdraw(
        fromWalletName: fromWalletName,
        toAddress: toAddress,
        paymentRequest: paymentRequest,
        amount: amount,
        totpCode: totpCode,
        isLightning: isLightning,
        networkFeeBtc: networkFeeBtc,
        maxRoutingFeeBtc: maxRoutingFeeBtc,
        description: description,
        confirmationPassphrase: confirmationPassphrase,
        passkeyAssertionJson: passkeyAssertionJson,
        idempotencyKey: operationIdempotencyKey,
        appPin: appPin,
      );

      await _refreshAfterMoneyMoved(ref);

      state = AsyncActionState(result: result);
      return result;
    } catch (e) {
      final stepUp = _extractStepUpChallenge(e);
      if (stepUp != null) {
        return _retryWithdrawWithPasskeyChallenge(
          initialChallenge: stepUp.legacyChallenge,
          actionRequired: stepUp.actionRequired,
          fromWalletName: fromWalletName,
          toAddress: toAddress,
          paymentRequest: paymentRequest,
          amount: amount,
          totpCode: totpCode,
          isLightning: isLightning,
          networkFeeBtc: networkFeeBtc,
          maxRoutingFeeBtc: maxRoutingFeeBtc,
          description: description,
          confirmationPassphrase: confirmationPassphrase,
          idempotencyKey: operationIdempotencyKey,
          appPin: appPin,
        );
      }

      state = AsyncActionState(error: e.toString());
      return null;
    }
  }

  Future<TxStatus?> _retryWithdrawWithPasskeyChallenge({
    required String initialChallenge,
    PasskeyActionRequired? actionRequired,
    required String fromWalletName,
    String? toAddress,
    String? paymentRequest,
    required double amount,
    String? totpCode,
    bool isLightning = false,
    double networkFeeBtc = 0,
    double maxRoutingFeeBtc = 0.000001,
    String? description,
    String? confirmationPassphrase,
    required String idempotencyKey,
    String? appPin,
  }) async {
    var challenge = initialChallenge;
    var stepUpAction = actionRequired;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final assertion = await buildTransactionalPasskeyAssertion(
          ref: ref,
          challenge: challenge,
          actionRequired: stepUpAction,
        );
        final result = await _repository.withdraw(
          fromWalletName: fromWalletName,
          toAddress: toAddress,
          paymentRequest: paymentRequest,
          amount: amount,
          totpCode: totpCode,
          isLightning: isLightning,
          networkFeeBtc: networkFeeBtc,
          maxRoutingFeeBtc: maxRoutingFeeBtc,
          description: description,
          confirmationPassphrase: confirmationPassphrase,
          passkeyAssertionJson: assertion.json,
          idempotencyKey: idempotencyKey,
          appPin: appPin,
        );
        await assertion.commitIfNeeded();

        await _refreshAfterMoneyMoved(ref);
        state = AsyncActionState(result: result);
        return result;
      } catch (signErr) {
        if (isAuthUserCancellation(signErr)) {
          state = const AsyncActionState();
          return null;
        }
        final renewed = _extractStepUpChallenge(signErr);
        if (renewed == null ||
            renewed.legacyChallenge == challenge ||
            attempt == 1) {
          state = AsyncActionState(error: signErr.toString());
          return null;
        }
        challenge = renewed.legacyChallenge;
        stepUpAction = renewed.actionRequired;
      }
    }
    return null;
  }

  void reset() => state = const AsyncActionState();
}

final withdrawProvider =
    NotifierProvider<WithdrawNotifier, AsyncActionState>(WithdrawNotifier.new);

/// True when the user dismissed device-key / passkey / vault biometrics mid-flow.
///
/// Prefer known error codes; string matching is a narrow fallback only.
bool isAuthUserCancellation(Object error) {
  if (error is DeviceKeyException) {
    return error.code == 'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED';
  }
  if (error is SovereignAuthException) {
    return error.code == SovereignAuthErrorCodes.authCancelled ||
        error.code == 'ERR_AUTH_PASSKEY_AUTH_CANCELLED';
  }

  final raw = error.toString();
  const cancelCodes = <String>[
    'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED',
    'ERR_AUTH_PASSKEY_AUTH_CANCELLED',
    'ERR_COLD_VAULT_AUTH_CANCELLED',
  ];
  for (final code in cancelCodes) {
    if (raw.contains(code)) return true;
  }

  // Narrow OS / plugin messages — avoid matching "cannot cancel subscription".
  final lower = raw.toLowerCase();
  if (lower.contains('usercanceled') ||
      lower.contains('user_canceled') ||
      lower.contains('user cancelled') ||
      lower.contains('user canceled')) {
    return true;
  }
  return false;
}

class _StepUpChallenge {
  final String legacyChallenge;
  final PasskeyActionRequired? actionRequired;

  const _StepUpChallenge({
    required this.legacyChallenge,
    this.actionRequired,
  });
}

/// Extracts typed 428 payload when present, plus a legacy challenge string for
/// older backends / test doubles that only embed PASSKEY_CHALLENGE_REQUIRED.
_StepUpChallenge? _extractStepUpChallenge(Object error) {
  PasskeyActionRequired? action;
  if (error is AppException) {
    action = PasskeyActionRequired.fromErrorPayload(error.data);
  } else if (error is Failure) {
    action = PasskeyActionRequired.fromErrorPayload(error.data);
  }

  final legacyFromTyped = action?.legacyOrPasskeyChallenge;
  if (legacyFromTyped != null && legacyFromTyped.isNotEmpty) {
    return _StepUpChallenge(
      legacyChallenge: legacyFromTyped,
      actionRequired: action,
    );
  }

  final legacy = _extractPasskeyChallenge(error);
  if (legacy == null) {
    // Typed DEVICE_KEY-only 428 without PASSKEY hex: still usable.
    final deviceOnly = action?.challengeFor('DEVICE_KEY');
    if (deviceOnly != null && deviceOnly.isComplete) {
      return _StepUpChallenge(
        legacyChallenge: deviceOnly.challenge,
        actionRequired: action,
      );
    }
    return null;
  }
  return _StepUpChallenge(
    legacyChallenge: legacy,
    actionRequired: action,
  );
}

String? _extractPasskeyChallenge(Object error) {
  const marker = 'PASSKEY_CHALLENGE_REQUIRED:';
  final rawError = error.toString().trim();
  final candidates = <String>[rawError];

  if (error is AppException) {
    candidates.insert(0, error.message);
    _appendPasskeyChallengeCandidates(candidates, error.data);
  } else if (error is Failure) {
    candidates.insert(0, error.message);
    _appendPasskeyChallengeCandidates(candidates, error.data);
  }

  try {
    final decoded = jsonDecode(rawError);
    if (decoded is Map) {
      _appendPasskeyChallengeCandidates(candidates, decoded);
    }
  } catch (_) {}

  final hexPattern = RegExp(
    '${RegExp.escape(marker)}([0-9a-fA-F]+)',
  );

  for (final candidate in candidates) {
    final trimmedCandidate = candidate.trim();
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmedCandidate)) {
      return trimmedCandidate;
    }

    final hexMatch = hexPattern.firstMatch(candidate);
    if (hexMatch != null) {
      return hexMatch.group(1);
    }

    final markerIndex = candidate.indexOf(marker);
    if (markerIndex < 0) {
      continue;
    }

    var challenge = candidate.substring(markerIndex + marker.length).trim();
    challenge = challenge.replaceFirst(RegExp(r"""^['"]+"""), '');
    challenge = challenge.replaceFirst(RegExp(r"""['",}\]\s]+$"""), '');

    if (challenge.isNotEmpty) {
      return challenge;
    }
  }

  return null;
}

void _appendPasskeyChallengeCandidates(List<String> candidates, Object? value) {
  if (value == null) {
    return;
  }

  if (value is Map) {
    for (final key in const [
      'challenge',
      'message',
      'error',
      'guidance',
      'errorCode',
      'code',
    ]) {
      final candidate = value[key]?.toString().trim();
      if (candidate != null && candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }
    // ApiResponse envelope often nests PasskeyActionRequiredDTO under data.
    _appendPasskeyChallengeCandidates(candidates, value['data']);
    return;
  }

  if (value is Iterable) {
    for (final item in value) {
      _appendPasskeyChallengeCandidates(candidates, item);
    }
    return;
  }

  final candidate = value.toString().trim();
  if (candidate.isNotEmpty) {
    candidates.add(candidate);
  }
}

/// Result of a local transactional signature.
///
/// [commitIfNeeded] must run only after the server accepts the assertion so the
/// local WebAuthn-style counter stays aligned with `passkey_credentials`.
class TransactionalPasskeyAssertion {
  final String json;
  final Future<void> Function()? commitOnSuccess;

  const TransactionalPasskeyAssertion({
    required this.json,
    this.commitOnSuccess,
  });

  Future<void> commitIfNeeded() async {
    final commit = commitOnSuccess;
    if (commit != null) {
      await commit();
    }
  }
}

/// Signs a KFE transactional challenge with the **authenticated** user's keys.
///
/// Historical bugs fixed here:
/// 1. Used username `'transaction'` so local material was never found.
/// 2. Device-key path reused the **passkey** challenge hex as `challengeId`
///    instead of fetching `/auth/device-key/challenge` (Redis `device_key_challenge`).
/// 3. Sovereign passkey counter was never committed after a successful tx, so the
///    next attempt replayed the same counter and the server answered AUTH_016 /
///    "passkey not linked" guidance.
///
/// Prefers device-key when enrolled.
///
/// Release N+2 (mobile tier A): no WebAuthn-shaped step-up fallback — user must
/// reconfigure Device Key if only a legacy sovereign key exists.
///
/// When [actionRequired] carries typed `challenges.DEVICE_KEY`, the FE signs
/// without an extra GET to `/auth/device-key/challenge` (release N 428).
Future<TransactionalPasskeyAssertion> buildTransactionalPasskeyAssertion({
  required Ref ref,
  required String challenge,
  PasskeyActionRequired? actionRequired,
}) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    throw const ServerException(
      message: 'Sessão inválida para assinar a transação.',
      errorCode: 'ERR_AUTH_SESSION_REQUIRED',
    );
  }

  final username = authState.user.username.trim();
  if (username.isEmpty) {
    throw const ServerException(
      message: 'Usuário inválido para assinar a transação.',
      errorCode: 'ERR_AUTH_USERNAME_REQUIRED',
    );
  }

  final deviceKey = DeviceKeyService.instance;
  // Linux/desktop: auto-enroll Device Key on first custodial step-up when allowed
  // (local_auth is missing; app entry PIN already gated the session).
  if (!await deviceKey.hasRegisteredDeviceKey(username)) {
    await _tryAutoEnrollDeviceKey(ref: ref, username: username);
  }
  if (await deviceKey.hasRegisteredDeviceKey(username)) {
    final typed = actionRequired?.challengeFor('DEVICE_KEY');
    final DeviceKeyChallenge deviceChallenge;
    if (typed != null && typed.isComplete) {
      deviceChallenge = DeviceKeyChallenge(
        challengeId: typed.challengeId!,
        challenge: typed.challenge,
        expiresInSeconds: typed.expiresInSeconds ?? 90,
        onionServiceId: typed.onionServiceId ?? '',
        algorithm: typed.algorithm ?? 'Ed25519',
        canonicalization: typed.canonicalization ?? 'KEROSENE_JSON_V1',
      );
    } else {
      // Compat: older 428 bodies only had PASSKEY hex.
      deviceChallenge =
          await _fetchDeviceKeyAuthChallenge(ref: ref, username: username);
    }
    final assertion = await deviceKey.authenticate(
      challenge: deviceChallenge,
      username: username,
    );
    return TransactionalPasskeyAssertion(
      json: jsonEncode({
        'type': 'DEVICE_KEY',
        ...assertion,
      }),
      commitOnSuccess: () => DeviceCredentialTelemetry.recordStepUp(
        kind: 'DEVICE_KEY',
        success: true,
      ),
    );
  }

  // N+2: dual path removed on first-class platforms — no shaped fallback.
  if (await DeviceCredentialEnrollPolicy.requireDeviceKeyForStepUp()) {
    await DeviceCredentialTelemetry.recordStepUp(
      kind: 'WEBAUTHN_SHAPED',
      success: false,
    );
    throw const ServerException(
      message: DeviceCredentialEnrollPolicy.reconfigureRequiredMessage,
      errorCode: DeviceCredentialEnrollPolicy.reconfigureRequiredCode,
    );
  }

  final passkeyChallenge =
      actionRequired?.legacyOrPasskeyChallenge ?? challenge;
  final credential = await PasskeyService.instance.authenticate(
    challengeHex: passkeyChallenge,
    username: username,
  );
  return TransactionalPasskeyAssertion(
    json: jsonEncode(PasskeyService.toWirePayload(credential)),
    commitOnSuccess: () async {
      await PasskeyService.instance.commitAuthenticationCounter(credential);
      await DeviceCredentialTelemetry.recordStepUp(
        kind: 'WEBAUTHN_SHAPED',
        success: true,
      );
    },
  );
}

/// Best-effort Device Key enroll so Linux can complete KFE step-up without
/// local_auth. Failures are swallowed; caller falls through to other paths.
Future<void> _tryAutoEnrollDeviceKey({
  required Ref ref,
  required String username,
}) async {
  try {
    final caps =
        await DeviceCredentialCapabilitiesResolver.instance.resolve();
    if (!caps.canEnrollDeviceCredential) {
      return;
    }
    final start = await ref.read(authRepositoryProvider).deviceKeyRegisterStart();
    final challengeJson = start.fold((_) => null, (v) => v);
    if (challengeJson == null) return;

    final challenge = DeviceKeyChallenge.fromJson(challengeJson);
    final credential = await DeviceKeyService.instance.register(
      challenge: challenge,
      username: username,
      sessionId: '',
    );
    final finish =
        await ref.read(authRepositoryProvider).deviceKeyRegisterFinish(credential);
    finish.fold((_) {}, (_) {
      // Bound locally for subsequent signs.
    });
  } catch (error) {
    debugPrint('DeviceKey auto-enroll skipped: $error');
  }
}

Future<DeviceKeyChallenge> _fetchDeviceKeyAuthChallenge({
  required Ref ref,
  required String username,
}) async {
  try {
    final response = await ref.read(apiClientProvider).get(
          AppConfig.authDeviceKeyChallenge,
          queryParameters: {'username': username},
        );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final challenge = DeviceKeyChallenge.fromJson(data);
      if (challenge.challengeId.isEmpty || challenge.challenge.isEmpty) {
        throw const ServerException(
          message: 'Challenge da device key incompleto.',
          errorCode: 'ERR_AUTH_DEVICE_KEY_INVALID_CHALLENGE',
        );
      }
      return challenge;
    }
    if (data is Map) {
      final challenge = DeviceKeyChallenge.fromJson(
        Map<String, dynamic>.from(data),
      );
      if (challenge.challengeId.isEmpty || challenge.challenge.isEmpty) {
        throw const ServerException(
          message: 'Challenge da device key incompleto.',
          errorCode: 'ERR_AUTH_DEVICE_KEY_INVALID_CHALLENGE',
        );
      }
      return challenge;
    }
    throw const ServerException(
      message: 'Não foi possível obter o challenge da device key.',
      errorCode: 'ERR_AUTH_DEVICE_KEY_INVALID_CHALLENGE',
    );
  } on AppException {
    rethrow;
  } catch (error) {
    throw ServerException(
      message:
          'Não foi possível obter o challenge da device key para assinar a transação.',
      errorCode: 'ERR_AUTH_DEVICE_KEY_CHALLENGE_FETCH',
      data: {'cause': error.toString()},
    );
  }
}
