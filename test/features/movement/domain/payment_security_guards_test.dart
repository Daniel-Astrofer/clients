import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';

void main() {
  group('payment_security_guards', () {
    test('networkMismatchMessage blocks mainnet address on testnet app', () {
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
      final msg = networkMismatchMessage(
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
      );
      expect(msg, isNotNull);
      expect(msg, contains('Rede'));
    });

    test('networkMismatchMessage allows testnet address on testnet app', () {
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
      final msg = networkMismatchMessage(
        'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      expect(msg, isNull);
    });

    test('networkMismatchMessage ignores non-address strings', () {
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
      expect(networkMismatchMessage('@alice'), isNull);
      expect(networkMismatchMessage(''), isNull);
    });
  });
}
