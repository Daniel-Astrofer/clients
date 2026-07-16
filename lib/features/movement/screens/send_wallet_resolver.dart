import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';

Wallet? resolveSendWallet({
  required WalletState walletState,
  required Wallet? selectedWallet,
  required String? requestedWalletId,
}) {
  if (walletState is! WalletLoaded) {
    return null;
  }

  final selected = selectedWallet;
  if (selected != null) {
    for (final wallet in walletState.wallets) {
      if (wallet.id == selected.id || wallet.name == selected.name) {
        return wallet;
      }
    }
  }

  if (requestedWalletId != null) {
    for (final wallet in walletState.wallets) {
      if (wallet.id == requestedWalletId || wallet.name == requestedWalletId) {
        return wallet;
      }
    }
  }

  if (walletState.wallets.length == 3) {
    final insured = walletState.wallets.firstWhere(
      (w) => w.isInternalCustody,
      orElse: () => walletState.wallets[0],
    );
    return insured;
  }

  return walletState.selectedWallet ??
      (walletState.wallets.isNotEmpty ? walletState.wallets.first : null);
}
