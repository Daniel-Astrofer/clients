import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';

void main() {
  // Real Electrum-created segwit seed (version prefix 100). BIP39 checksum fails.
  const electrumSegwit =
      'nut bone peanut cotton donate omit gossip siren breeze concert make pole';

  group('ElectrumSeedUtils', () {
    test('detects segwit seed version 100', () {
      final info = ElectrumSeedUtils.detect(electrumSegwit);
      expect(info, isNotNull);
      expect(info!.type, ElectrumSeedType.segwit);
      expect(info.versionPrefix, '100');
      expect(info.accountDerivationPath, "m/0'");
      expect(info.isSegwit, isTrue);
    });

    test('BIP39 abandon vector is NOT electrum', () {
      const bip39 =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      expect(ElectrumSeedUtils.detect(bip39), isNull);
    });

    test('electrum seed bytes differ from BIP39 pbkdf2', () {
      final seed = ElectrumSeedUtils.mnemonicToSeed(electrumSegwit);
      expect(seed.length, 64);
      // Fixed vector from independent python pbkdf2 (electrum salt).
      expect(
          seed
              .sublist(0, 8)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
          '2820c2428a4c9e89');
    });
  });

  group('ColdWalletPublicMaterialDeriver electrum', () {
    test('derives network xpub/tpub for electrum segwit at m/0\'', () {
      const deriver = ColdWalletPublicMaterialDeriver();
      final material = deriver.derive(mnemonic: electrumSegwit);
      expect(material.seedKind, ColdWalletSeedKind.electrum);
      expect(material.derivationPath, "m/0'");
      expect(material.electrumVersion, '100');
      expect(material.xpub, isNotEmpty);
      // App defaults to testnet → tpub for Bitcoin Core descriptors.
      expect(
        material.xpub.startsWith('tpub') || material.xpub.startsWith('xpub'),
        isTrue,
      );
      expect(material.scriptPolicy, contains('wpkh'));
    });
  });
}
