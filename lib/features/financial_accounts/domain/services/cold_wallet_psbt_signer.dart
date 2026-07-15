import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_key_vault.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';

/// Signs a Core-funded watch-only PSBT using the local seed.
///
/// Supports BIP39+BIP84 and Electrum native seeds (segwit `m/0'/{0,1}/*`).
class ColdWalletPsbtSigner {
  ColdWalletPsbtSigner({
    ColdWalletKeyVault? vault,
    int addressLookahead = 40,
  })  : _vault = vault ?? ColdWalletKeyVault.instance,
        _addressLookahead = addressLookahead < 5 ? 5 : addressLookahead;

  ColdWalletPsbtSigner._internal() : this();

  static final ColdWalletPsbtSigner instance = ColdWalletPsbtSigner._internal();

  final ColdWalletKeyVault _vault;
  final int _addressLookahead;

  /// Unlocks seed, signs all inputs, returns signed PSBT base64.
  Future<String> signPsbt({
    required String walletId,
    required String unsignedPsbtBase64,
    BasedUtxoNetwork network = BitcoinNetwork.testnet,
  }) async {
    final material = await _vault.unlockSeed(
      walletId: walletId,
      localizedReason: 'Confirme para assinar a transação da carteira fria.',
    );
    try {
      return signPsbtWithMnemonic(
        mnemonic: material.mnemonic,
        passphrase: material.passphrase,
        unsignedPsbtBase64: unsignedPsbtBase64,
        network: network,
        seedKind: material.seedKind,
      );
    } finally {
      material.dispose();
    }
  }

  /// Pure signing helper (used by tests without vault/biometrics).
  String signPsbtWithMnemonic({
    required String mnemonic,
    required String unsignedPsbtBase64,
    String passphrase = '',
    BasedUtxoNetwork network = BitcoinNetwork.testnet,
    ColdWalletSeedKind? seedKind,
  }) {
    final normalized = mnemonic.trim().toLowerCase();
    final kind = seedKind ??
        (ElectrumSeedUtils.isElectrumSeed(normalized)
            ? ColdWalletSeedKind.electrum
            : ColdWalletSeedKind.bip39);

    if (kind == ColdWalletSeedKind.bip39 &&
        !bip39.validateMnemonic(normalized) &&
        !ElectrumSeedUtils.isElectrumSeed(normalized)) {
      throw const ColdWalletPsbtSignerException(
        'ERR_COLD_SIGN_INVALID_MNEMONIC',
        'Seed inválida para assinar a PSBT.',
      );
    }
    if (kind == ColdWalletSeedKind.electrum &&
        ElectrumSeedUtils.detect(normalized) == null) {
      throw const ColdWalletPsbtSignerException(
        'ERR_COLD_SIGN_INVALID_ELECTRUM',
        'Seed Electrum inválida para assinar a PSBT.',
      );
    }
    final psbtRaw = unsignedPsbtBase64.trim();
    if (psbtRaw.isEmpty) {
      throw const ColdWalletPsbtSignerException(
        'ERR_COLD_SIGN_EMPTY_PSBT',
        'PSBT unsigned vazia.',
      );
    }

    final keyring = _deriveKeyring(
      mnemonic: normalized,
      passphrase: passphrase,
      network: network,
      seedKind: kind,
    );

    final builder = PsbtBuilder.fromBase64(psbtRaw);
    var signedAny = false;
    builder.signAllInput((params) {
      final address = params.address.toAddress(network);
      final key = keyring[address];
      if (key == null) {
        // Also try without network-specific formatting edge cases.
        final alt = params.address.toAddress(BitcoinNetwork.mainnet);
        final mainnetKey = keyring[alt];
        if (mainnetKey == null) {
          return null;
        }
        signedAny = true;
        return PsbtSignerResponse(signers: [PsbtDefaultSigner(mainnetKey)]);
      }
      signedAny = true;
      return PsbtSignerResponse(signers: [PsbtDefaultSigner(key)]);
    });

    if (!signedAny) {
      throw const ColdWalletPsbtSignerException(
        'ERR_COLD_SIGN_NO_MATCHING_KEYS',
        'Nenhuma chave local corresponde aos inputs desta PSBT. '
            'Confira se a seed é a mesma da carteira fria importada.',
      );
    }
    return builder.toBase64();
  }

  /// Public verification that [mnemonic] matches the expected watch-only xpub.
  bool matchesXpub({
    required String mnemonic,
    required String expectedXpub,
    String passphrase = '',
  }) {
    try {
      final material = const ColdWalletPublicMaterialDeriver().derive(
        mnemonic: mnemonic,
        extraWord: passphrase,
      );
      return material.xpub.trim() == expectedXpub.trim();
    } catch (_) {
      return false;
    }
  }

  Map<String, ECPrivate> _deriveKeyring({
    required String mnemonic,
    required String passphrase,
    required BasedUtxoNetwork network,
    required ColdWalletSeedKind seedKind,
  }) {
    late final Uint8List seed;
    late final String accountPath;
    if (seedKind == ColdWalletSeedKind.electrum) {
      final info = ElectrumSeedUtils.detect(mnemonic)!;
      seed = ElectrumSeedUtils.mnemonicToSeed(
        info.phrase,
        passphrase: passphrase,
      );
      accountPath = info.accountDerivationPath;
    } else {
      seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
      accountPath = appColdWalletDerivationPath;
    }
    try {
      final root = Bip32Slip10Secp256k1.fromSeed(seed);
      final account = (accountPath == 'm' || accountPath == "m/")
          ? root
          : root.derivePath(accountPath);
      final keys = <String, ECPrivate>{};

      void indexChain(String chain) {
        for (var i = 0; i < _addressLookahead; i++) {
          final child = account.derivePath('$chain/$i');
          final privBytes = child.privateKey.raw;
          final priv = ECPrivate.fromBytes(privBytes);
          final addr = priv.getPublic().toSegwitAddress().toAddress(network);
          keys[addr] = priv;
          // Legacy P2PKH for standard Electrum wallets.
          if (seedKind == ColdWalletSeedKind.electrum &&
              !ElectrumSeedUtils.detect(mnemonic)!.isSegwit) {
            final legacy =
                priv.getPublic().toAddress().toAddress(network);
            keys[legacy] = priv;
          }
        }
      }

      indexChain('0'); // receive
      indexChain('1'); // change
      return keys;
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }
}

class ColdWalletPsbtSignerException implements Exception {
  final String code;
  final String message;

  const ColdWalletPsbtSignerException(this.code, this.message);

  @override
  String toString() => 'ColdWalletPsbtSignerException($code): $message';
}
