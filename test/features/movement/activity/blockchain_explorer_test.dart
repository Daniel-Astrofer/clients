import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/activity/blockchain_explorer.dart';

void main() {
  final hash = List.filled(4, 'abcdef0123456789').join();
  const main = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
  final testAddress = 'tb1q${List.filled(32, 'q').join()}';
  final local = 'bcrt1q${List.filled(32, 'q').join()}';
  for (final entry in {
    'mainnet': '',
    'bitcoin': '',
    'testnet3': '/testnet',
    'testnet': '/testnet',
    'testnet4': '/testnet4',
    'signet': '/signet',
  }.entries) {
    test('tx links use the explicit ${entry.key} network', () {
      expect(
          BlockchainExplorer.txUri(' ${hash.toUpperCase()} ',
                  networkHint: entry.key)
              ?.toString(),
          'https://mempool.space${entry.value}/tx/$hash');
    });
  }
  test('missing, local and malformed network hints never choose testnet', () {
    for (final hint in [null, '', 'regtest', 'unknown', 'notmainnet']) {
      expect(BlockchainExplorer.txUri(hash, networkHint: hint), isNull);
    }
  });
  test('tx identifiers reject path injection and non-hex or wrong length', () {
    for (final invalid in [
      '',
      'a' * 63,
      'a' * 65,
      'z' * 64,
      '$hash/../other'
    ]) {
      expect(BlockchainExplorer.txUri(invalid, networkHint: 'mainnet'), isNull);
    }
  });
  test('only unambiguous address evidence resolves a network', () {
    expect(
        BlockchainExplorer.networkFromAddresses([main, 'Kerosene']), 'mainnet');
    expect(BlockchainExplorer.networkFromAddresses([local]), 'regtest');
    expect(BlockchainExplorer.networkFromAddresses([testAddress]), isNull);
    expect(
        BlockchainExplorer.networkFromAddresses([main, testAddress]), isNull);
    expect(BlockchainExplorer.networkFromAddresses(['not-an-address']), isNull);
  });
  test('address links reject ambiguous and contradictory networks', () {
    expect(BlockchainExplorer.addressUri(main)?.path, '/address/$main');
    expect(BlockchainExplorer.addressUri(testAddress), isNull);
    expect(BlockchainExplorer.addressUri(local, networkHint: 'signet'), isNull);
    expect(BlockchainExplorer.addressUri(main, networkHint: 'testnet'), isNull);
    expect(BlockchainExplorer.addressUri(testAddress, networkHint: 'mainnet'),
        isNull);
    expect(
        BlockchainExplorer.addressUri(testAddress, networkHint: 'signet')?.path,
        '/signet/address/$testAddress');
  });
  test('launcher false and asynchronous errors return failure', () async {
    expect(
        await BlockchainExplorer.openTx(hash,
            networkHint: 'mainnet', launcher: (_) async => false),
        isFalse);
    expect(
        await BlockchainExplorer.openTx(hash,
            networkHint: 'mainnet',
            launcher: (_) async => throw StateError('private')),
        isFalse);
    var calls = 0;
    expect(
        await BlockchainExplorer.openTx(hash, launcher: (_) async {
          calls++;
          return true;
        }),
        isFalse);
    expect(calls, 0);
  });
}
