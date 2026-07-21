import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/price_provider.dart';
import '../../../auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/get_wallets_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/send_bitcoin_usecase.dart';
import '../../domain/usecases/get_deposit_address_usecase.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show transactionHistoryProvider;

import 'package:kerosene/features/financial_accounts/application/providers/wallet_data_providers.dart';

export 'package:kerosene/features/financial_accounts/application/providers/wallet_data_providers.dart';

// ==================== UseCase Providers ====================

final getWalletsUseCaseProvider = Provider<GetWalletsUseCase>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return GetWalletsUseCase(repository);
});

final getTransactionsUseCaseProvider = Provider<GetTransactionsUseCase>((ref) {
  final repository = ref.watch(ledgerRepositoryProvider);
  return GetTransactionsUseCase(repository);
});

final sendBitcoinUseCaseProvider = Provider<SendBitcoinUseCase>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return SendBitcoinUseCase(repository);
});

final getDepositAddressUseCaseProvider = Provider<GetDepositAddressUseCase>((
  ref,
) {
  final repository = ref.watch(transactionRepositoryProvider);
  return GetDepositAddressUseCase(repository);
});

// ==================== State Notifiers ====================

/// StateNotifier para gerenciar estado de carteiras
class WalletNotifier extends Notifier<WalletState> {
  late GetWalletsUseCase getWalletsUseCase;
  late WalletRepository walletRepository;

  @override
  WalletState build() {
    ref.watch(sessionStorageScopeProvider);
    getWalletsUseCase = ref.watch(getWalletsUseCaseProvider);
    walletRepository = ref.watch(walletRepositoryProvider);
    return const WalletInitial();
  }
  // Não chamamos _loadWallets() aqui para evitar duplicação:
  // o HomeScreen.initState chama refresh() via addPostFrameCallback.

  /// Carrega carteiras e taxa de câmbio
  Future<void> _loadWallets({bool isRefresh = false}) async {
    if (!isRefresh || state is! WalletLoaded) {
      state = const WalletLoading();
    }

    final walletsResult = await getWalletsUseCase();

    const btcToUsdRate = 0.0;

    walletsResult.fold(
      (failure) {
        // If we fail to fetch wallets (e.g. 403, 401, timeout), we should emit an Error state, NOT an empty loaded state!
        state = WalletError(
          failure.message,
          statusCode: failure.statusCode,
          errorCode: failure.errorCode,
        );
      },
      (wallets) {
        state = WalletLoaded(
          wallets: wallets,
          selectedWallet: wallets.isNotEmpty ? wallets.first : null,
          btcToUsdRate: btcToUsdRate,
        );
      },
    );
  }

  /// Recarrega carteiras
  Future<void> refresh() async {
    await _loadWallets(isRefresh: true);
  }

  /// Seleciona uma carteira
  void selectWallet(Wallet wallet) {
    if (state is WalletLoaded) {
      final currentState = state as WalletLoaded;
      state = currentState.copyWith(selectedWallet: wallet);
    }
  }

  /// Atualiza saldo de uma carteira específica
  /// IMPORTANTE: walletId deve ser o NOME da wallet, não o ID numérico!
  Future<void> updateWalletBalance(String walletId) async {
    if (state is! WalletLoaded) return;

    final result = await walletRepository.updateWalletBalance(walletId);

    result.fold(
      (failure) {
        // Log error mas não muda estado para não interromper UX
        debugPrint('Wallet balance refresh failed.');
      },
      (updatedWallet) {
        final currentState = state as WalletLoaded;
        final updatedWallets = currentState.wallets.map((wallet) {
          // Comparar por NAME, não por ID!
          return wallet.name == walletId ? updatedWallet : wallet;
        }).toList();

        state = currentState.copyWith(wallets: updatedWallets);
      },
    );
  }

  /// Atualiza saldo de uma wallet via WebSocket (tempo real).
  /// Prefer [updateBalanceFromWebSocketUpdate] when bucket snapshot is present.
  void updateBalanceFromWebSocket(String walletKey, double newBalance) {
    updateBalanceFromWebSocketUpdate(
      walletKey: walletKey,
      newBalance: newBalance,
    );
  }

  /// Dual-ledger-aware realtime update.
  ///
  /// - Cold / observed-only: only [observedSats] drives primary balance.
  /// - Custodial/internal: [availableSats] is spendable; observed events must
  ///   not overwrite hero balance (dual-ledger).
  void updateBalanceFromWebSocketUpdate({
    required String walletKey,
    required double newBalance,
    String? kind,
    int? availableSats,
    int? observedSats,
    int? primarySats,
    String? bucket,
    String context = '',
  }) {
    if (state is! WalletLoaded) return;

    final key = walletKey.trim();
    if (key.isEmpty) return;

    final currentState = state as WalletLoaded;
    var matched = false;
    final ctx = context.toLowerCase();
    final bucketUpper = (bucket ?? '').toUpperCase();
    final isObservedEvent = bucketUpper == 'OBSERVED' || ctx.contains('observ');

    final updatedWallets = currentState.wallets.map((wallet) {
      // Prefer stable KFE wallet UUID only — never match by name/label (collision risk).
      final hit = wallet.id == key;
      if (!hit) return wallet;
      matched = true;

      final cold = wallet.isColdWallet || wallet.isObservedOnlyBalance;
      final nextObserved = observedSats ??
          (isObservedEvent || cold
              ? (primarySats ?? (newBalance * 100000000).round())
              : null);
      final nextAvailable = availableSats ??
          (!cold && !isObservedEvent
              ? (primarySats ?? (newBalance * 100000000).round())
              : null);

      if (cold) {
        final obs = nextObserved ?? wallet.observedSats;
        return wallet.copyWith(
          observedSats: obs,
          balance: obs / 100000000.0,
        );
      }

      // Custodial/internal: never let an observed-only event clobber available.
      if (isObservedEvent && availableSats == null) {
        final obs = nextObserved ?? wallet.observedSats;
        return wallet.copyWith(
          observedSats: obs,
          // keep available + balance (spendable) unchanged
        );
      }

      final avail = nextAvailable ?? wallet.availableSats;
      final obs = nextObserved ?? wallet.observedSats;
      return wallet.copyWith(
        availableSats: avail,
        observedSats: obs,
        balance: avail / 100000000.0,
      );
    }).toList();

    if (!matched) {
      debugPrint(
        'Wallet realtime update ignored — no wallet matched key=$key',
      );
      return;
    }

    state = currentState.copyWith(wallets: updatedWallets);

    // As soon as the websocket pushes a balance update, invalidate the transaction
    // history so it automatically fetches the new rows that generated this balance.
    ref.invalidate(transactionHistoryProvider);

    debugPrint(
      'Wallet balance refreshed from realtime feed (bucket=$bucket context=$context).',
    );
  }
}

final walletProvider =
    NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);

// ==================== Transaction Notifier ====================

class TransactionNotifier extends Notifier<TransactionState> {
  late GetTransactionsUseCase getTransactionsUseCase;

  @override
  TransactionState build() {
    ref.watch(sessionStorageScopeProvider);
    getTransactionsUseCase = ref.watch(getTransactionsUseCaseProvider);
    return const TransactionInitial();
  }

  Future<void> loadTransactions(String walletId, {int limit = 50}) async {
    state = const TransactionLoading();

    final result = await getTransactionsUseCase(
      walletId: walletId,
      limit: limit,
    );

    result.fold(
      (failure) => state = TransactionError(failure.message),
      (transactions) => state = TransactionLoaded(
        transactions: transactions,
        hasMore: transactions.length >= limit,
      ),
    );
  }

  // Falta implementar loadMore e refresh se necessário, mas para esse contexto
  // de correção de compilação, o básico basta. Vou manter simples.
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, TransactionState>(
        TransactionNotifier.new);

// ==================== Total Balance Providers ====================

/// Provider for total BTC balance across all wallets
final totalBalanceBtcProvider = Provider<double>((ref) {
  final walletState = ref.watch(walletProvider);

  if (walletState is! WalletLoaded) return 0.0;

  return walletState.wallets.fold(0.0, (sum, wallet) {
    if (!wallet.hasKeroseneSpendableBalance) {
      return sum;
    }
    return sum + wallet.balance;
  });
});

/// Provider for total balance in USD using real-time price
final totalBalanceUsdProvider = Provider.autoDispose<double?>((ref) {
  final balanceBtc = ref.watch(totalBalanceBtcProvider);
  final priceAsync = ref.watch(backendBtcRatesProvider);

  return priceAsync.when(
    data: (rates) {
      final price = rates?.btcUsd;
      if (price == null || price <= 0) {
        return null;
      }
      return balanceBtc * price;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ==================== UI State Providers ====================

class BalanceVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final balanceVisibilityProvider =
    NotifierProvider<BalanceVisibilityNotifier, bool>(
        BalanceVisibilityNotifier.new);

class DecimalPrecisionNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final decimalPrecisionProvider =
    NotifierProvider<DecimalPrecisionNotifier, bool>(
        DecimalPrecisionNotifier.new);
