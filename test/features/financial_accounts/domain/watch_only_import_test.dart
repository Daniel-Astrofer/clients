import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/watch_only_import.dart';

const _xpub =
    'xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V';
const _zpub =
    'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs';

void main() {
  for (final key in [_xpub, _zpub]) {
    test(
        'normalizes BIP84 vector while preserving account and origin: ${key.substring(0, 4)}',
        () {
      final material = parseWatchOnlyImport(
          extendedPublicKey: ' $key ',
          fingerprint: '73C5DA0A',
          derivationPath: 'm/84h/0h/0h',
          network: BitcoinNetworkKind.mainnet);
      expect(material.xpub, _xpub);
      expect(material.fingerprint, '73c5da0a');
      expect(material.derivationPath, "m/84'/0'/0'");
      expect(material.scriptPolicy, 'wpkh([73c5da0a/84h/0h/0h]$_xpub/0/*)');
    });
  }
  for (final network in [
    BitcoinNetworkKind.testnet,
    BitcoinNetworkKind.regtest
  ]) {
    for (final version in [
      Bip32Const.testNetKeyNetVersions,
      Bip84Conf.bitcoinTestNet.keyNetVer
    ]) {
      test('accepts public account 7 for $network / ${version.public}', () {
        final root =
            Bip32Slip10Secp256k1.fromSeed(List.generate(32, (i) => i), version);
        final key = root.derivePath("m/84'/1'/7'").publicKey.toExtended;
        final material = parseWatchOnlyImport(
            extendedPublicKey: key,
            fingerprint: root.fingerPrint.toHex(),
            derivationPath: "m/84'/1'/7'",
            network: network);
        expect(material.xpub, startsWith('tpub'));
        expect(
            Bip32Slip10Secp256k1.fromExtendedKey(
                    material.xpub, Bip32Const.testNetKeyNetVersions)
                .publicKey
                .toHex(),
            root.derivePath("m/84'/1'/7'").publicKey.toHex());
      });
    }
  }
  for (final prefix in ['xprv', 'tprv', 'zprv', 'vprv', 'yprv', 'uprv']) {
    test('rejects private material before decoding: $prefix', () {
      expect(
          () => parseWatchOnlyImport(
              extendedPublicKey: '${prefix}private-fixture',
              fingerprint: '73c5da0a',
              derivationPath: "m/84'/0'/0'",
              network: BitcoinNetworkKind.mainnet),
          throwsA(WatchOnlyImportError.privateKey));
    });
  }
  for (final wrong in ['', '73c5da0', '73c5da0az', 'zzzzzzzz']) {
    test('rejects invalid master identifier $wrong', () {
      expect(
          () => parseWatchOnlyImport(
              extendedPublicKey: _xpub,
              fingerprint: wrong,
              derivationPath: "m/84'/0'/0'",
              network: BitcoinNetworkKind.mainnet),
          throwsA(WatchOnlyImportError.fingerprint));
    });
  }
  for (final wrong in [
    'm',
    "m/44'/0'/0'",
    "m/84'/0'/0'/0",
    'm/84/0/0',
    "m/84'/0'/2147483648'"
  ]) {
    test(
        'rejects a path incompatible with current native SegWit account contract: $wrong',
        () {
      expect(
          () => parseWatchOnlyImport(
              extendedPublicKey: _xpub,
              fingerprint: '73c5da0a',
              derivationPath: wrong,
              network: BitcoinNetworkKind.mainnet),
          throwsA(WatchOnlyImportError.path));
    });
  }
  test(
      'rejects network conversion instead of silently changing the wallet network',
      () {
    expect(
        () => parseWatchOnlyImport(
            extendedPublicKey: _xpub,
            fingerprint: '73c5da0a',
            derivationPath: "m/84'/1'/0'",
            network: BitcoinNetworkKind.testnet),
        throwsA(WatchOnlyImportError.network));
  });
  test('rejects key/path account mismatch', () {
    expect(
        () => parseWatchOnlyImport(
            extendedPublicKey: _xpub,
            fingerprint: '73c5da0a',
            derivationPath: "m/84'/0'/1'",
            network: BitcoinNetworkKind.mainnet),
        throwsA(WatchOnlyImportError.account));
  });
  test('rejects invalid checksum without embedding key data in the error', () {
    expect(
        () => parseWatchOnlyImport(
            extendedPublicKey: '${_xpub.substring(0, _xpub.length - 1)}1',
            fingerprint: '73c5da0a',
            derivationPath: "m/84'/0'/0'",
            network: BitcoinNetworkKind.mainnet),
        throwsA(WatchOnlyImportError.key));
  });
  test('rejects a master key supplied instead of an account key', () {
    final root = Bip32Slip10Secp256k1.fromSeed(List.generate(32, (i) => i));
    expect(
        () => parseWatchOnlyImport(
            extendedPublicKey: root.publicKey.toExtended,
            fingerprint: root.fingerPrint.toHex(),
            derivationPath: "m/84'/0'/0'",
            network: BitcoinNetworkKind.mainnet),
        throwsA(WatchOnlyImportError.account));
  });
}
