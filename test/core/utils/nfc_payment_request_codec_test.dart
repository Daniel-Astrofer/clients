import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/nfc_payment_request_codec.dart';
import 'package:nfc_manager/ndef_record.dart';

void main() {
  group('NfcPaymentRequestCodec', () {
    test('round trips a public Kerosene payment request URI', () {
      const uri = 'kerosene://payment/pay/public-request-id';

      final message = NfcPaymentRequestCodec.encodeUri(uri);

      expect(NfcPaymentRequestCodec.decodeMessage(message), uri);
    });

    test('round trips a live-style publicId payment URI', () {
      const uri = 'kerosene://payment/pay/euk1dbtccw7fo31lpzciveyf';
      final message = NfcPaymentRequestCodec.encodeUri(uri);
      expect(NfcPaymentRequestCodec.decodeMessage(message), uri);
      expect(NfcPaymentRequestCodec.isPaymentPayload(uri), isTrue);
    });

    test('accepts bitcoin BIP-21 URI for NFC tags', () {
      const uri =
          'bitcoin:tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x?amount=0.00025';
      final message = NfcPaymentRequestCodec.encodeUri(uri);
      expect(NfcPaymentRequestCodec.decodeMessage(message), uri);
    });

    test('decodes a prefixed NDEF URI record', () {
      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList('U'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList([
          0x04,
          ...'wallet.example/pay/public-request-id'.codeUnits,
        ]),
      );

      expect(
        NfcPaymentRequestCodec.decodeRecord(record),
        'https://wallet.example/pay/public-request-id',
      );
    });

    test('rejects unrelated tag content', () {
      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.media,
        type: Uint8List.fromList('text/plain'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList('not a payment'.codeUnits),
      );

      expect(NfcPaymentRequestCodec.decodeRecord(record), isNull);
      expect(
        () => NfcPaymentRequestCodec.encodeUri('not a payment'),
        throwsFormatException,
      );
    });
  });
}
