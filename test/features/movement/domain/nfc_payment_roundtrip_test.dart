import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/kernel/intent/nfc_payment_request_codec.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_parser.dart';

void main() {
  const parser = PaymentIntentParser();

  group('NFC encode → decode → PaymentIntentParser round-trip', () {
    test('payment link URI', () {
      const id = 'nfc-link-roundtrip-42';
      final encoded = QrPaymentParser.encodePaymentLink(id);
      expect(NfcPaymentRequestCodec.isPaymentPayload(encoded), isTrue);

      final message = NfcPaymentRequestCodec.encodeUri(encoded);
      final decoded = NfcPaymentRequestCodec.decodeMessage(message);
      expect(decoded, isNotNull);

      final intent = parser.parse(decoded!);
      expect(intent.kind, PaymentDestinationKind.paymentLink);
      expect(intent.paymentLinkId, id);
    });

    test('BIP-21 on-chain with amount', () {
      const addr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
      final uri = QrPaymentParser.encode(address: addr, amountBtc: 0.00012);
      expect(NfcPaymentRequestCodec.isPaymentPayload(uri), isTrue);

      final message = NfcPaymentRequestCodec.encodeUri(uri);
      final decoded = NfcPaymentRequestCodec.decodeMessage(message);
      expect(decoded, isNotNull);

      final intent = parser.parse(decoded!);
      expect(intent.kind, PaymentDestinationKind.onchain);
      expect(intent.normalizedValue, addr);
      expect(intent.amountBtc, closeTo(0.00012, 1e-12));
    });

    test('raw bech32 address is valid NFC payload via parser', () {
      const addr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
      expect(NfcPaymentRequestCodec.isPaymentPayload(addr), isTrue);
      final message = NfcPaymentRequestCodec.encodeUri(addr);
      final decoded = NfcPaymentRequestCodec.decodeMessage(message);
      final intent = parser.parse(decoded!);
      expect(intent.kind, PaymentDestinationKind.onchain);
    });

    test('username is valid NFC payload via parser', () {
      expect(NfcPaymentRequestCodec.isPaymentPayload('alice_01'), isTrue);
      final message = NfcPaymentRequestCodec.encodeUri('@alice_01');
      final decoded = NfcPaymentRequestCodec.decodeMessage(message);
      final intent = parser.parse(decoded!);
      expect(intent.kind, PaymentDestinationKind.internal);
      expect(intent.normalizedValue, 'alice_01');
    });

    test('garbage is rejected for NFC encode', () {
      expect(
          NfcPaymentRequestCodec.isPaymentPayload('!!!not-valid!!!'), isFalse);
      expect(
        () => NfcPaymentRequestCodec.encodeUri('!!!not-valid!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('QR encodePaymentLink and NFC share same parser id', () {
      const id = 'shared-channel-id';
      final qr = QrPaymentParser.encodePaymentLink(id);
      final nfcMessage = NfcPaymentRequestCodec.encodeUri(qr);
      final fromNfc = NfcPaymentRequestCodec.decodeMessage(nfcMessage)!;
      final fromQr = qr;

      expect(parser.parse(fromNfc).paymentLinkId, id);
      expect(parser.parse(fromQr).paymentLinkId, id);
      expect(parser.parse(fromNfc).kind, parser.parse(fromQr).kind);
    });
  });
}
