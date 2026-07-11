import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

import 'qr_payment_parser.dart';

/// Encodes and decodes payment requests stored in NDEF tags.
class NfcPaymentRequestCodec {
  const NfcPaymentRequestCodec._();

  static NdefMessage encodeUri(String value) {
    final normalized = _requirePaymentPayload(value);
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList(utf8.encode('U')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([0x00, ...utf8.encode(normalized)]),
        ),
      ],
    );
  }

  static String? decodeMessage(NdefMessage? message) {
    if (message == null) return null;
    for (final record in message.records) {
      final decoded = decodeRecord(record);
      if (decoded != null) return decoded;
    }
    return null;
  }

  static String? decodeRecord(NdefRecord record) {
    if (record.payload.isEmpty) return null;

    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        _decodeBytes(record.type) == 'U') {
      final prefixIndex = record.payload.first;
      final prefix =
          prefixIndex < _uriPrefixes.length ? _uriPrefixes[prefixIndex] : '';
      return _normalizePaymentPayload(
        '$prefix${_decodeBytes(record.payload.sublist(1))}',
      );
    }

    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        _decodeBytes(record.type) == 'T') {
      final languageLength = record.payload.first & 0x3f;
      final textOffset = 1 + languageLength;
      if (textOffset <= record.payload.length) {
        return _normalizePaymentPayload(
          _decodeBytes(record.payload.sublist(textOffset)),
        );
      }
    }

    return _normalizePaymentPayload(_decodeBytes(record.payload)) ??
        (record.payload.length > 1
            ? _normalizePaymentPayload(
                _decodeBytes(record.payload.sublist(1)),
              )
            : null);
  }

  static bool isPaymentPayload(String value) {
    return _normalizePaymentPayload(value) != null;
  }

  static String _requirePaymentPayload(String value) {
    final normalized = _normalizePaymentPayload(value);
    if (normalized == null) {
      throw const FormatException('Invalid NFC payment request payload.');
    }
    return normalized;
  }

  static String? _normalizePaymentPayload(String value) {
    final normalized = value.trim().replaceFirst('\u0000', '');
    if (normalized.isEmpty) return null;
    return QrPaymentParser.decode(normalized) != null ? normalized : null;
  }

  static String _decodeBytes(List<int> value) {
    return utf8.decode(value, allowMalformed: true);
  }

  static const List<String> _uriPrefixes = [
    '',
    'http://www.',
    'https://www.',
    'http://',
    'https://',
    'tel:',
    'mailto:',
    'ftp://anonymous:anonymous@',
    'ftp://ftp.',
    'ftps://',
    'sftp://',
    'smb://',
    'nfs://',
    'ftp://',
    'dav://',
    'news:',
    'telnet://',
    'imap:',
    'rtsp://',
    'urn:',
    'pop:',
    'sip:',
    'sips:',
    'tftp:',
    'btspp://',
    'btl2cap://',
    'btgoep://',
    'tcpobex://',
    'irdaobex://',
    'file://',
    'urn:epc:id:',
    'urn:epc:tag:',
    'urn:epc:pat:',
    'urn:epc:raw:',
    'urn:epc:',
    'urn:nfc:',
  ];
}
