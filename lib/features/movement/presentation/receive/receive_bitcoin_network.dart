import 'package:kerosene/core/utils/bitcoin_network.dart';

enum ReceiveBitcoinNetwork {
  mainnet,
  testnet,
  testnet3,
  testnet4,
  signet,
  regtest,
  testFamily,
  unknown,
}

/// An allocation's explicit network takes priority. Shared test-address
/// prefixes alone cannot identify which test chain issued an address.
ReceiveBitcoinNetwork resolveReceiveBitcoinNetwork(
    {String? network, required String address}) {
  final hint = (network ?? '').trim().toLowerCase();
  final inferred = looksLikeBitcoinAddress(address)
      ? inferBitcoinNetworkFromAddress(address)
      : BitcoinNetworkKind.unknown;
  if (hint.isEmpty) {
    return switch (inferred) {
      BitcoinNetworkKind.mainnet => ReceiveBitcoinNetwork.mainnet,
      BitcoinNetworkKind.regtest => ReceiveBitcoinNetwork.regtest,
      BitcoinNetworkKind.testnet => ReceiveBitcoinNetwork.testFamily,
      BitcoinNetworkKind.unknown => ReceiveBitcoinNetwork.unknown,
    };
  }
  final explicit = switch (hint) {
    'mainnet' || 'bitcoin' => ReceiveBitcoinNetwork.mainnet,
    'testnet' => ReceiveBitcoinNetwork.testnet,
    'testnet3' => ReceiveBitcoinNetwork.testnet3,
    'testnet4' => ReceiveBitcoinNetwork.testnet4,
    'signet' => ReceiveBitcoinNetwork.signet,
    'regtest' => ReceiveBitcoinNetwork.regtest,
    _ => ReceiveBitcoinNetwork.unknown,
  };
  if ((inferred == BitcoinNetworkKind.mainnet &&
          explicit != ReceiveBitcoinNetwork.mainnet) ||
      (inferred != BitcoinNetworkKind.mainnet &&
          inferred != BitcoinNetworkKind.unknown &&
          explicit == ReceiveBitcoinNetwork.mainnet) ||
      (inferred == BitcoinNetworkKind.regtest &&
          explicit != ReceiveBitcoinNetwork.regtest)) {
    return ReceiveBitcoinNetwork.unknown;
  }
  return explicit;
}
