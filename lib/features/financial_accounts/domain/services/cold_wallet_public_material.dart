import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bip39_mnemonic_utils.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';

/// Legacy default (mainnet). Prefer [appColdWalletDerivationPath] for new wallets.
const defaultColdWalletDerivationPath = "m/84'/0'/0'";
const defaultColdWalletScriptPolicy = 'wpkh';

class ColdWalletPublicMaterial {
  final String xpub;
  final String fingerprint;
  final String derivationPath;
  final String scriptPolicy;
  final ColdWalletSeedKind seedKind;

  /// Electrum version prefix (`100`, `01`, …) when [seedKind] is electrum.
  final String? electrumVersion;

  const ColdWalletPublicMaterial({
    required this.xpub,
    required this.fingerprint,
    this.derivationPath = defaultColdWalletDerivationPath,
    this.scriptPolicy = defaultColdWalletScriptPolicy,
    this.seedKind = ColdWalletSeedKind.bip39,
    this.electrumVersion,
  });

  Map<String, String> toImportPayload() => {
        'xpub': xpub,
        'fingerprint': fingerprint,
        'derivationPath': derivationPath,
        'scriptPolicy': scriptPolicy,
      };
}

class ColdWalletPublicMaterialDeriver {
  const ColdWalletPublicMaterialDeriver();

  /// Derive watch-only material. Auto-detects Electrum native seeds first
  /// (they fail BIP39 checksum by design).
  ColdWalletPublicMaterial derive({
    required String mnemonic,
    String extraWord = '',
    String? derivationPath,
    bool allowInvalidChecksum = false,
    ColdWalletSeedKind? seedKind,
  }) {
    final electrum = ElectrumSeedUtils.detect(mnemonic);
    final kind = seedKind ??
        (electrum != null
            ? ColdWalletSeedKind.electrum
            : ColdWalletSeedKind.bip39);

    if (kind == ColdWalletSeedKind.electrum) {
      return _deriveElectrum(
        mnemonic: mnemonic,
        passphrase: extraWord,
        detected: electrum,
        // Electrum account path is fixed by seed type (m/0' or m).
        derivationPathOverride: null,
      );
    }

    return _deriveBip39(
      mnemonic: mnemonic,
      extraWord: extraWord,
      derivationPath: derivationPath,
      allowInvalidChecksum: allowInvalidChecksum,
    );
  }

  ColdWalletPublicMaterial _deriveBip39({
    required String mnemonic,
    required String extraWord,
    String? derivationPath,
    required bool allowInvalidChecksum,
  }) {
    final parsed = Bip39MnemonicUtils.parse(
      mnemonic,
      allowInvalidChecksum: allowInvalidChecksum,
    );
    if (!parsed.isValid) {
      throw ArgumentError.value(
        mnemonic,
        'mnemonic',
        parsed.message ?? 'Invalid BIP39 mnemonic.',
      );
    }
    final normalizedMnemonic = parsed.phrase;
    final path = (derivationPath ?? appColdWalletDerivationPath).trim();
    final seed = bip39.mnemonicToSeed(
      normalizedMnemonic,
      passphrase: extraWord.trim(),
    );
    try {
      return _materialFromSeed(
        seed: seed,
        path: path,
        seedKind: ColdWalletSeedKind.bip39,
      );
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  ColdWalletPublicMaterial _deriveElectrum({
    required String mnemonic,
    required String passphrase,
    ElectrumSeedInfo? detected,
    String? derivationPathOverride,
  }) {
    final info = detected ?? ElectrumSeedUtils.detect(mnemonic);
    if (info == null) {
      throw ArgumentError.value(
        mnemonic,
        'mnemonic',
        'Semente não é Electrum válida (HMAC Seed version).',
      );
    }
    final path = (derivationPathOverride ?? info.accountDerivationPath).trim();
    final seed = ElectrumSeedUtils.mnemonicToSeed(
      info.phrase,
      passphrase: passphrase,
    );
    try {
      return _materialFromSeed(
        seed: seed,
        path: path,
        seedKind: ColdWalletSeedKind.electrum,
        electrumVersion: info.versionPrefix,
      );
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  ColdWalletPublicMaterial _materialFromSeed({
    required Uint8List seed,
    required String path,
    required ColdWalletSeedKind seedKind,
    String? electrumVersion,
  }) {
    // Bitcoin Core on testnet4 rejects mainnet xpub version bytes in descriptors.
    // Always serialize with the app network key version (xpub vs tpub).
    final keyNet = _bip32KeyNetVersionsForApp();
    final root = Bip32Slip10Secp256k1.fromSeed(seed, keyNet);
    // Path "m" means account = root itself (Electrum standard).
    final account = path == 'm' || path == "m/" ? root : root.derivePath(path);
    final xpub = account.publicKey.toExtended;
    final fingerprint = root.fingerPrint.toHex();

    return ColdWalletPublicMaterial(
      xpub: xpub,
      fingerprint: fingerprint,
      derivationPath: path == "m/" ? 'm' : path,
      scriptPolicy: _watchOnlyDescriptor(
        fingerprint: fingerprint,
        xpub: xpub,
        derivationPath: path == "m/" ? 'm' : path,
      ),
      seedKind: seedKind,
      electrumVersion: electrumVersion,
    );
  }

  static Bip32KeyNetVersions _bip32KeyNetVersionsForApp() {
    return switch (expectedBitcoinNetwork) {
      BitcoinNetworkKind.mainnet => Bip32Const.mainNetKeyNetVersions,
      BitcoinNetworkKind.testnet ||
      BitcoinNetworkKind.regtest ||
      BitcoinNetworkKind.unknown =>
        Bip32Const.testNetKeyNetVersions,
    };
  }

  String _watchOnlyDescriptor({
    required String fingerprint,
    required String xpub,
    required String derivationPath,
  }) {
    if (derivationPath == 'm' || derivationPath == "m/") {
      // Electrum standard: receive at m/0/*
      return '$defaultColdWalletScriptPolicy([$fingerprint]$xpub/0/*)';
    }
    final accountPath =
        derivationPath.replaceFirst(RegExp(r'^m/'), '').replaceAll("'", 'h');
    return '$defaultColdWalletScriptPolicy([$fingerprint/$accountPath]$xpub/0/*)';
  }
}
