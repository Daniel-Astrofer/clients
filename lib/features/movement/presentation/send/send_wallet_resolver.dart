import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';

/// Resolves the send source wallet only after the user picks one in-flow.
/// Never falls back to home/active wallet — source list comes after destination.
Wallet? resolveSendWallet({
  required WalletState walletState,
  required Wallet? selectedWallet,
}) {
  if (walletState is! WalletLoaded || selectedWallet == null) {
    return null;
  }

  for (final wallet in walletState.wallets) {
    if (wallet.id == selectedWallet.id || wallet.name == selectedWallet.name) {
      return wallet;
    }
  }
  return null;
}
