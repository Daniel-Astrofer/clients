import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:crypto/crypto.dart';

import 'package:kerosene/features/financial_accounts/domain/services/bip39_mnemonic_utils.dart';

/// Electrum native seed (not BIP39).
///
/// Electrum uses the same English wordlist as BIP39 but a different checksum
/// (HMAC-SHA512 "Seed version") and PBKDF2 salt (`electrum` + passphrase).
/// Default software wallets created in Electrum are almost never BIP39.
///
/// Version prefixes (hex of HMAC):
/// - `01`  standard (legacy P2PKH)
/// - `100` segwit (native P2WPKH) — common on testnet
/// - `101` 2FA
/// - `102` 2FA+segwit
enum ElectrumSeedType {
  standard,
  segwit,
  twoFactor,
  twoFactorSegwit,
}

class ElectrumSeedInfo {
  final ElectrumSeedType type;
  final String phrase;
  final String versionPrefix;

  const ElectrumSeedInfo({
    required this.type,
    required this.phrase,
    required this.versionPrefix,
  });

  /// Account-level path whose `/0/*` and `/1/*` children are receive/change.
  String get accountDerivationPath => switch (type) {
        ElectrumSeedType.segwit || ElectrumSeedType.twoFactorSegwit => "m/0'",
        // Standard Electrum: children hang off the master (`m`).
        ElectrumSeedType.standard || ElectrumSeedType.twoFactor => 'm',
      };

  bool get isSegwit =>
      type == ElectrumSeedType.segwit ||
      type == ElectrumSeedType.twoFactorSegwit;
}

class ElectrumSeedUtils {
  ElectrumSeedUtils._();

  static const int pbkdf2Rounds = 2048;
  static const int seedLength = 64;

  /// Normalize like Electrum (`normalize_text`): collapse whitespace.
  static String normalize(String raw) =>
      Bip39MnemonicUtils.normalizePhrase(raw);

  /// HMAC-SHA512 hex of `Seed version` || phrase (Electrum seed version system).
  static String versionHmacHex(String phrase) {
    final normalized = normalize(phrase);
    final digest = Hmac(sha512, utf8.encode('Seed version'))
        .convert(utf8.encode(normalized));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Detect Electrum seed type, or null if not an Electrum seed.
  static ElectrumSeedInfo? detect(String raw) {
    final words = Bip39MnemonicUtils.tokenize(raw);
    if (words.isEmpty) return null;
    // Electrum seeds are typically 12 words (sometimes 24 in older formats).
    if (words.length != 12 && words.length != 24) return null;
    // All words must be BIP39-english (Electrum uses that list).
    if (words.any((w) => !Bip39MnemonicUtils.isEnglishWord(w))) return null;

    final phrase = words.join(' ');
    final hmacHex = versionHmacHex(phrase);

    ElectrumSeedType? type;
    String? prefix;
    if (hmacHex.startsWith('100')) {
      type = ElectrumSeedType.segwit;
      prefix = '100';
    } else if (hmacHex.startsWith('102')) {
      type = ElectrumSeedType.twoFactorSegwit;
      prefix = '102';
    } else if (hmacHex.startsWith('101')) {
      type = ElectrumSeedType.twoFactor;
      prefix = '101';
    } else if (hmacHex.startsWith('01')) {
      type = ElectrumSeedType.standard;
      prefix = '01';
    }
    if (type == null || prefix == null) return null;

    return ElectrumSeedInfo(
      type: type,
      phrase: phrase,
      versionPrefix: prefix,
    );
  }

  static bool isElectrumSeed(String raw) => detect(raw) != null;

  /// Electrum `mnemonic_to_seed`: PBKDF2-HMAC-SHA512(mnemonic, "electrum"+pass).
  static Uint8List mnemonicToSeed(
    String mnemonic, {
    String passphrase = '',
  }) {
    final m = normalize(mnemonic);
    final p = normalize(passphrase);
    final password = utf8.encode(m);
    final salt = utf8.encode('electrum$p');
    final derived = QuickCrypto.pbkdf2DeriveKey(
      password: password,
      salt: salt,
      iterations: pbkdf2Rounds,
      dklen: seedLength,
    );
    return Uint8List.fromList(derived);
  }
}

/// How a cold-wallet mnemonic must be interpreted for derive/sign.
enum ColdWalletSeedKind {
  /// Standard BIP39 + BIP84 path.
  bip39,

  /// Electrum native seed (segwit or standard).
  electrum,
}

extension ColdWalletSeedKindWire on ColdWalletSeedKind {
  String get wireName => switch (this) {
        ColdWalletSeedKind.bip39 => 'bip39',
        ColdWalletSeedKind.electrum => 'electrum',
      };

  static ColdWalletSeedKind parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'electrum':
        return ColdWalletSeedKind.electrum;
      case 'bip39':
      default:
        return ColdWalletSeedKind.bip39;
    }
  }
}
