import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';

void main() {
  group('cold wallet network path', () {
    test('testnet uses coin type 1', () {
      expect(
        coldWalletDerivationPathFor(BitcoinNetworkKind.testnet),
        "m/84'/1'/0'",
      );
    });

    test('mainnet uses coin type 0', () {
      expect(
        coldWalletDerivationPathFor(BitcoinNetworkKind.mainnet),
        "m/84'/0'/0'",
      );
    });

    test('app path follows expectedBitcoinNetwork override', () {
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
      expect(appColdWalletDerivationPath, "m/84'/1'/0'");
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.mainnet;
      expect(appColdWalletDerivationPath, "m/84'/0'/0'");
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
    });
  });

  group('ColdWalletPublicMaterialDeriver network path', () {
    test('derives different xpub for testnet vs mainnet path', () {
      final mnemonic = bip39.generateMnemonic(strength: 128);
      const deriver = ColdWalletPublicMaterialDeriver();
      final main = deriver.derive(
        mnemonic: mnemonic,
        derivationPath: "m/84'/0'/0'",
      );
      final test = deriver.derive(
        mnemonic: mnemonic,
        derivationPath: "m/84'/1'/0'",
      );
      expect(main.xpub, isNot(equals(test.xpub)));
      expect(main.derivationPath, "m/84'/0'/0'");
      expect(test.derivationPath, "m/84'/1'/0'");
    });
  });

  group('RegisterColdWalletUseCase', () {
    test('stores seed under KFE account id', () async {
      final mnemonic = bip39.generateMnemonic(strength: 128);
      String? savedWalletId;
      String? savedMnemonic;

      final useCase = RegisterColdWalletUseCase(
        importColdWallet: ({
          required String label,
          required String xpub,
          required String fingerprint,
          required String derivationPath,
          required String scriptPolicy,
        }) async {
          return BitcoinAccount(
            id: 'kfe-wallet-uuid-001',
            type: 'WATCH_ONLY_COLD_WALLET',
            custody: 'WATCH_ONLY',
            status: 'ACTIVE',
            label: label,
            riskTier: 'BRONZE',
            coldWalletId: 'kfe-wallet-uuid-001',
          );
        },
        seedStore: _FakeSeedStore(
          onSave: (id, mnemonic, _) {
            savedWalletId = id;
            savedMnemonic = mnemonic;
          },
        ),
      );

      final result = await useCase.registerFromMnemonic(
        label: 'Test Cold',
        mnemonic: mnemonic,
        derivationPath: "m/84'/1'/0'",
      );

      expect(result.walletId, 'kfe-wallet-uuid-001');
      expect(result.seedStored, isTrue);
      expect(savedWalletId, 'kfe-wallet-uuid-001');
      expect(savedMnemonic, mnemonic.trim().toLowerCase());
      expect(result.material.derivationPath, "m/84'/1'/0'");
    });

    test('skips seed store when storeSeed is false', () async {
      final mnemonic = bip39.generateMnemonic(strength: 128);
      var saveCount = 0;
      final useCase = RegisterColdWalletUseCase(
        importColdWallet: ({
          required String label,
          required String xpub,
          required String fingerprint,
          required String derivationPath,
          required String scriptPolicy,
        }) async {
          return BitcoinAccount(
            id: 'watch-only-1',
            type: 'WATCH_ONLY_COLD_WALLET',
            custody: 'WATCH_ONLY',
            status: 'ACTIVE',
            label: label,
            riskTier: 'BRONZE',
          );
        },
        seedStore: _FakeSeedStore(
          onSave: (_, __, ___) => saveCount++,
        ),
      );

      final result = await useCase.registerFromMnemonic(
        label: 'Observe',
        mnemonic: mnemonic,
        storeSeed: false,
      );

      expect(result.seedStored, isFalse);
      expect(result.walletId, 'watch-only-1');
      expect(saveCount, 0);
    });

    test('friendly error for invalid mnemonic', () {
      expect(
        coldWalletRegisterErrorMessage(
          ArgumentError.value('bad', 'mnemonic'),
        ),
        contains('BIP39'),
      );
    });

    test('resolveColdWalletId prefers coldWalletId', () {
      final account = BitcoinAccount(
        id: 'account-id',
        type: 'WATCH_ONLY_COLD_WALLET',
        custody: 'WATCH_ONLY',
        status: 'ACTIVE',
        label: 'x',
        riskTier: 'BRONZE',
        coldWalletId: 'cold-id',
      );
      expect(
        RegisterColdWalletUseCase.resolveColdWalletId(account),
        'cold-id',
      );
    });

    test('ColdWalletFlowOutcome carries openSend intent', () {
      final account = BitcoinAccount(
        id: 'w1',
        type: 'WATCH_ONLY_COLD_WALLET',
        custody: 'WATCH_ONLY',
        status: 'ACTIVE',
        label: 'x',
        riskTier: 'BRONZE',
      );
      const material = ColdWalletPublicMaterial(
        xpub: 'xpub-test',
        fingerprint: 'aabbccdd',
      );
      final registration = RegisterColdWalletResult(
        account: account,
        walletId: 'w1',
        material: material,
        seedStored: true,
      );
      final outcome = ColdWalletFlowOutcome(
        registration: registration,
        openSend: true,
      );
      expect(outcome.walletId, 'w1');
      expect(outcome.openSend, isTrue);
      expect(outcome.seedStored, isTrue);
    });
  });
}

class _FakeSeedStore implements ColdWalletSeedStore {
  _FakeSeedStore({required this.onSave});

  final void Function(String id, String mnemonic, String fingerprint) onSave;

  @override
  Future<void> saveSeed({
    required String walletId,
    required String mnemonic,
    required String fingerprint,
    String passphrase = '',
    ColdWalletSeedKind seedKind = ColdWalletSeedKind.bip39,
  }) async {
    onSave(walletId, mnemonic, fingerprint);
  }
}
