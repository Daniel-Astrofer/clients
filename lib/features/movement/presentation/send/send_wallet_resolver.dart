import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';

/// Resolves the send source wallet only after an explicit in-flow pick.
/// Never falls back to the home/global [WalletLoaded.selectedWallet].
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
