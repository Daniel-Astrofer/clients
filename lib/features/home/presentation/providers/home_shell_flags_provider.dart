import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// Structural flags for the home shell — **not** the full data payloads.
///
/// [HomeScreen] must not watch wallet lists / full history / prices.
/// Only these coarse flags may affect shell structure (loading vs feed).
class HomeShellFlags {
  final bool showLoading;
  final bool hasWallet;
  final bool hasBalance;
  final bool hasTransactions;
  final bool hasLoadedHistory;
  final String? authenticatedUserId;
  final String userNameRaw;
  final bool authIsLoading;
  final double sectionGapAfterHeader;
  final double sectionGapBeforeFeed;

  const HomeShellFlags({
    required this.showLoading,
    required this.hasWallet,
    required this.hasBalance,
    required this.hasTransactions,
    required this.hasLoadedHistory,
    required this.authenticatedUserId,
    required this.userNameRaw,
    required this.authIsLoading,
    required this.sectionGapAfterHeader,
    required this.sectionGapBeforeFeed,
  });

  bool get isReadyActionsVariant => hasWallet && hasBalance;

  @override
  bool operator ==(Object other) {
    return other is HomeShellFlags &&
        other.showLoading == showLoading &&
        other.hasWallet == hasWallet &&
        other.hasBalance == hasBalance &&
        other.hasTransactions == hasTransactions &&
        other.hasLoadedHistory == hasLoadedHistory &&
        other.authenticatedUserId == authenticatedUserId &&
        other.userNameRaw == userNameRaw &&
        other.authIsLoading == authIsLoading &&
        other.sectionGapAfterHeader == sectionGapAfterHeader &&
        other.sectionGapBeforeFeed == sectionGapBeforeFeed;
  }

  @override
  int get hashCode => Object.hash(
        showLoading,
        hasWallet,
        hasBalance,
        hasTransactions,
        hasLoadedHistory,
        authenticatedUserId,
        userNameRaw,
        authIsLoading,
        sectionGapAfterHeader,
        sectionGapBeforeFeed,
      );
}

final homeShellFlagsProvider = Provider<HomeShellFlags>((ref) {
  final authId = ref.watch(
    authControllerProvider.select(
      (s) => s is AuthAuthenticated ? s.user.id : null,
    ),
  );
  final authName = ref.watch(
    authControllerProvider.select(
      (s) => s is AuthAuthenticated ? s.user.name.trim() : '',
    ),
  );
  final authLoading = ref.watch(
    authControllerProvider.select((s) => s is AuthLoading),
  );

  final showLoading = ref.watch(
    walletProvider.select((w) => w is WalletInitial || w is WalletLoading),
  );
  final hasWallet = ref.watch(
    walletProvider.select((w) {
      if (w is! WalletLoaded) return false;
      return w.wallets.isNotEmpty || w.selectedWallet != null;
    }),
  );
  final hasBalance = ref.watch(
    walletProvider.select((w) {
      if (w is! WalletLoaded) return false;
      final active =
          w.selectedWallet ?? (w.wallets.isNotEmpty ? w.wallets.first : null);
      return (active?.balance ?? 0) > 0;
    }),
  );

  final hasLoadedHistory = ref.watch(
    transactionHistoryProvider.select((a) => a.hasValue),
  );
  final hasTransactions = ref.watch(
    transactionHistoryProvider.select(
      (a) => (a.asData?.value.isNotEmpty ?? false),
    ),
  );

  final layout = ref.watch(homeSurfaceProvider.select((s) => s.layout));

  return HomeShellFlags(
    showLoading: showLoading,
    hasWallet: hasWallet,
    hasBalance: hasBalance,
    hasTransactions: hasTransactions,
    hasLoadedHistory: hasLoadedHistory,
    authenticatedUserId: authId,
    userNameRaw: authName,
    authIsLoading: authLoading,
    sectionGapAfterHeader: layout.sectionGapAfterHeader,
    sectionGapBeforeFeed: layout.sectionGapBeforeFeed,
  );
});
