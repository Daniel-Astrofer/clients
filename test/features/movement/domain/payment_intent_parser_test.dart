import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_parser.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_analyzer.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

void main() {
  const parser = PaymentIntentParser();

  group('PaymentIntentParser', () {
    test('empty input', () {
      final intent = parser.parse('   ');
      expect(intent.kind, PaymentDestinationKind.empty);
      expect(intent.isEmpty, isTrue);
    });

    test('username and @username are internal', () {
      for (final raw in ['nycollas', '@nycollas', '  @Alice_01  ']) {
        final intent = parser.parse(raw);
        expect(intent.kind, PaymentDestinationKind.internal, reason: raw);
        expect(intent.normalizedValue, isNot(contains('@')));
      }
    });

    test('wallet UUID is internal', () {
      const id = '61a8bb23-e18e-4f32-8414-9844e7300c14';
      final intent = parser.parse(id);
      expect(intent.kind, PaymentDestinationKind.internal);
      expect(intent.normalizedValue, id);
    });

    test('wallet hash is invalid not internal', () {
      const destination = 'abcdef1234567890abcdef1234567890';
      final intent = parser.parse(destination);
      expect(intent.kind, PaymentDestinationKind.invalid);
    });

    test('bare garbage is invalid never payment link', () {
      final intent = parser.parse('not-a-real-destination!!!');
      expect(intent.kind, PaymentDestinationKind.invalid);
      expect(intent.paymentLinkId, isNull);
    });

    test('whitespace payload is invalid', () {
      final intent = parser.parse('hello world');
      expect(intent.kind, PaymentDestinationKind.invalid);
      expect(intent.invalidReason, 'whitespace');
    });

    test('kerosene payment link shapes', () {
      const id = 'pub-link-abc123';
      final cases = [
        'kerosene:link:$id',
        'kerosene://pay/$id',
        'kerosene://payment/pay/$id',
        'https://app.kerosene.example/pay/$id',
        'http://examplehiddenservice.onion/pay/$id',
        'https://host/api/public/kfe/payment-requests/$id',
      ];
      for (final raw in cases) {
        final intent = parser.parse(raw);
        expect(intent.kind, PaymentDestinationKind.paymentLink, reason: raw);
        expect(intent.paymentLinkId, id, reason: raw);
      }
    });

    test('encodePaymentLink round-trips', () {
      const id = 'round-trip-id-001';
      final encoded = QrPaymentParser.encodePaymentLink(id);
      final intent = parser.parse(encoded);
      expect(intent.kind, PaymentDestinationKind.paymentLink);
      expect(intent.paymentLinkId, id);
    });

    test('testnet bech32 is onchain', () {
      const addr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
      final intent = parser.parse(addr);
      expect(intent.kind, PaymentDestinationKind.onchain);
      expect(intent.normalizedValue, addr);
      expect(intent.detectedOnchainNetwork, BitcoinNetworkKind.testnet);
    });

    test('mainnet bech32 is onchain', () {
      const addr = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
      final intent = parser.parse(addr);
      expect(intent.kind, PaymentDestinationKind.onchain);
      expect(intent.detectedOnchainNetwork, BitcoinNetworkKind.mainnet);
    });

    test('BIP-21 with amount', () {
      const addr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
      final uri = 'bitcoin:$addr?amount=0.00010000&label=Coffee';
      final intent = parser.parse(uri);
      expect(intent.kind, PaymentDestinationKind.onchain);
      expect(intent.normalizedValue, addr);
      expect(intent.amountBtc, closeTo(0.0001, 1e-12));
      expect(intent.label, 'Coffee');
    });

    test('lightning invoice prefix', () {
      // Minimal shape that matches looksLikeLightningRequest (not a valid bolt11).
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse(invoice);
      expect(intent.kind, PaymentDestinationKind.lightning);
    });

    test('lightning: prefix stripped', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse('lightning:$invoice');
      expect(intent.kind, PaymentDestinationKind.lightning);
      expect(intent.normalizedValue, invoice);
    });

    test('lightning address email form', () {
      final intent = parser.parse('user@example.com');
      expect(intent.kind, PaymentDestinationKind.lightning);
    });

    test('analyzeSendDestination mirrors parser kind', () {
      const fixtures = <String, SendDestinationType>{
        '': SendDestinationType.empty,
        'nycollas': SendDestinationType.internal,
        '@bob_01': SendDestinationType.internal,
        'kerosene:link:xyz': SendDestinationType.paymentLink,
        'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx':
            SendDestinationType.onChain,
        'not valid!!': SendDestinationType.invalid,
        'two words': SendDestinationType.invalid,
      };
      for (final entry in fixtures.entries) {
        final intent = parser.parse(entry.key);
        final analysis = analyzeSendDestination(entry.key);
        expect(
          analysis.type,
          entry.value,
          reason: 'raw=${entry.key} intent=${intent.kind}',
        );
      }
    });

    test('fuzz random strings never throw', () {
      final rng = Random(42);
      for (var i = 0; i < 100; i++) {
        final length = rng.nextInt(80);
        final buffer = StringBuffer();
        for (var j = 0; j < length; j++) {
          buffer.writeCharCode(32 + rng.nextInt(95));
        }
        final raw = buffer.toString();
        expect(() => parser.parse(raw), returnsNormally, reason: raw);
        final intent = parser.parse(raw);
        expect(PaymentDestinationKind.values, contains(intent.kind));
      }
    });
  });
}
