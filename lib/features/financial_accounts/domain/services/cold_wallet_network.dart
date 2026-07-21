import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';

/// BIP84 account path for software cold wallets (native segwit).
///
/// Coin type follows BIP44: 0 = mainnet, 1 = testnet/regtest.
String coldWalletDerivationPathFor(BitcoinNetworkKind network) {
  return switch (network) {
    BitcoinNetworkKind.mainnet => "m/84'/0'/0'",
    BitcoinNetworkKind.testnet || BitcoinNetworkKind.regtest => "m/84'/1'/0'",
    BitcoinNetworkKind.unknown => coldWalletDerivationPathFor(
        expectedBitcoinNetwork,
      ),
  };
}

/// Path used by the running app flavor (testnet by default in local builds).
String get appColdWalletDerivationPath =>
    coldWalletDerivationPathFor(expectedBitcoinNetwork);

String coldWalletNetworkLabel(BitcoinNetworkKind network) {
  return bitcoinNetworkDisplayName(network);
}
