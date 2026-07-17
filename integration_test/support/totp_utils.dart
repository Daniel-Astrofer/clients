import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Minimal TOTP (RFC 6238) generator for visual / integration E2E.
class TotpGenerator {
  /// Generates a 6-digit TOTP code for a given Base32 secret.
  static String generate(String secret, {int? timeMs}) {
    final key = _base32Decode(secret);
    var counter = (timeMs ?? DateTime.now().millisecondsSinceEpoch) ~/ 30000;

    final msg = Uint8List(8);
    for (var i = 7; i >= 0; i--) {
      msg[i] = counter & 0xff;
      counter >>= 8;
    }

    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(msg).bytes;

    final offset = hash[hash.length - 1] & 0xf;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  static Uint8List _base32Decode(String base32) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean = base32.toUpperCase().replaceAll('=', '');
    final bits = clean.split('').map((c) => alphabet.indexOf(c)).toList();

    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (final val in bits) {
      if (val == -1) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }
    return Uint8List.fromList(bytes);
  }
}
