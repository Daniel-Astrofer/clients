import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_bitcoin_network.dart';

void main() {
  const main = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
  final sharedTest = 'tb1q${List.filled(32, 'q').join()}';
  final local = 'bcrt1q${List.filled(32, 'q').join()}';
  for (final entry in {
    'mainnet': ReceiveBitcoinNetwork.mainnet,
    'testnet': ReceiveBitcoinNetwork.testnet,
    'testnet3': ReceiveBitcoinNetwork.testnet3,
    'testnet4': ReceiveBitcoinNetwork.testnet4,
    'signet': ReceiveBitcoinNetwork.signet,
    'regtest': ReceiveBitcoinNetwork.regtest,
  }.entries) {
    test('explicit ${entry.key} remains distinct', () {
      expect(resolveReceiveBitcoinNetwork(network: entry.key, address: ''),
          entry.value);
    });
  }
  test('unknown data never defaults to mainnet', () {
    expect(resolveReceiveBitcoinNetwork(address: ''),
        ReceiveBitcoinNetwork.unknown);
    expect(resolveReceiveBitcoinNetwork(address: 'bc1invalid'),
        ReceiveBitcoinNetwork.unknown);
    expect(resolveReceiveBitcoinNetwork(network: 'custom-chain', address: main),
        ReceiveBitcoinNetwork.unknown);
  });
  test('address evidence distinguishes only unambiguous networks', () {
    expect(resolveReceiveBitcoinNetwork(address: main),
        ReceiveBitcoinNetwork.mainnet);
    expect(resolveReceiveBitcoinNetwork(address: local),
        ReceiveBitcoinNetwork.regtest);
    expect(resolveReceiveBitcoinNetwork(address: sharedTest),
        ReceiveBitcoinNetwork.testFamily);
  });
  test('explicit network and address conflicts are not presented as certain',
      () {
    expect(
        resolveReceiveBitcoinNetwork(network: 'mainnet', address: sharedTest),
        ReceiveBitcoinNetwork.unknown);
    expect(resolveReceiveBitcoinNetwork(network: 'signet', address: local),
        ReceiveBitcoinNetwork.unknown);
    expect(resolveReceiveBitcoinNetwork(network: 'testnet4', address: main),
        ReceiveBitcoinNetwork.unknown);
    expect(resolveReceiveBitcoinNetwork(network: 'signet', address: sharedTest),
        ReceiveBitcoinNetwork.signet);
    expect(
        resolveReceiveBitcoinNetwork(network: 'testnet4', address: sharedTest),
        ReceiveBitcoinNetwork.testnet4);
  });
}
