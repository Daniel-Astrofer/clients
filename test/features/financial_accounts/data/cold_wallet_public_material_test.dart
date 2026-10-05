import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';
import 'package:test/test.dart';

void main() {
  // Fixed BIP32 vectors use mainnet coin type (m/84'/0'/0').
  const mainnetPath = defaultColdWalletDerivationPath;

  setUp(() {
    expectedBitcoinNetworkOverride = BitcoinNetworkKind.mainnet;
  });

  tearDown(() {
    expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
  });

  test('derives public watch-only material without exposing the seed', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const deriver = ColdWalletPublicMaterialDeriver();

    final material = deriver.derive(
      mnemonic: mnemonic,
      derivationPath: mainnetPath,
    );
    final repeated = deriver.derive(
      mnemonic: mnemonic,
      derivationPath: mainnetPath,
    );
    final payload = material.toImportPayload();

    expect(
      material.xpub,
      'xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V',
    );
    expect(material.xpub, repeated.xpub);
    expect(material.fingerprint, '73c5da0a');
    expect(material.derivationPath, mainnetPath);
    expect(
      material.scriptPolicy,
      'wpkh([73c5da0a/84h/0h/0h]xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V/0/*)',
    );
    expect(payload.keys, isNot(contains('mnemonic')));
    expect(payload.keys, isNot(contains('seed')));
    expect(payload.keys, isNot(contains('extraWord')));
    expect(payload.values.join(' '), isNot(contains('abandon')));
  });

  test('uses the optional extra word in public material derivation', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const deriver = ColdWalletPublicMaterialDeriver();

    final standard = deriver.derive(
      mnemonic: mnemonic,
      derivationPath: mainnetPath,
    );
    final withExtra = deriver.derive(
      mnemonic: mnemonic,
      extraWord: 'offline-only',
      derivationPath: mainnetPath,
    );

    expect(withExtra.xpub, isNot(standard.xpub));
    expect(withExtra.fingerprint, isNot(standard.fingerprint));
    expect(
      withExtra.xpub,
      'xpub6CZsUXuo6AkJUfxbpYgeUt8LSFBYhWJJ2FR4ttk2wEHjE5z7ZrryvnSbQ14jqpgtWJob5sPuB3cSf8rrwDxmG11YDWY13cX9p3sfu6Tcgtb',
    );
    expect(withExtra.fingerprint, '31d167f4');
  });

  test('testnet coin type path differs from mainnet account xpub', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const deriver = ColdWalletPublicMaterialDeriver();

    final mainnet = deriver.derive(
      mnemonic: mnemonic,
      derivationPath: "m/84'/0'/0'",
    );
    final testnet = deriver.derive(
      mnemonic: mnemonic,
      derivationPath: "m/84'/1'/0'",
    );

    expect(testnet.xpub, isNot(mainnet.xpub));
    expect(testnet.derivationPath, "m/84'/1'/0'");
    expect(testnet.scriptPolicy, contains('84h/1h/0h'));
  });
}
