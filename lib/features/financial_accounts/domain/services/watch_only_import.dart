import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'cold_wallet_public_material.dart';

enum WatchOnlyImportError {
  key,
  privateKey,
  network,
  fingerprint,
  path,
  account
}

/// Validates the public account material supported by the current KFE receiver.
/// Origin metadata is supplied by the exporter; an account key cannot prove its
/// full ancestor path or master fingerprint. Private keys are never accepted.
ColdWalletPublicMaterial parseWatchOnlyImport({
  required String extendedPublicKey,
  required String fingerprint,
  required String derivationPath,
  required BitcoinNetworkKind network,
}) {
  final key = extendedPublicKey.trim();
  if (RegExp(r'^[xtzyuv]prv').hasMatch(key)) {
    throw WatchOnlyImportError.privateKey;
  }
  if (key.length > 128 || key.length < 4) throw WatchOnlyImportError.key;
  final prefix = key.substring(0, 4);
  final mainnet = prefix == 'xpub' || prefix == 'zpub';
  final testnet = prefix == 'tpub' || prefix == 'vpub';
  if (!mainnet && !testnet) throw WatchOnlyImportError.key;
  if (network == BitcoinNetworkKind.unknown ||
      mainnet != (network == BitcoinNetworkKind.mainnet)) {
    throw WatchOnlyImportError.network;
  }
  final origin = fingerprint.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(origin)) {
    throw WatchOnlyImportError.fingerprint;
  }
  final path = RegExp(r"^m/84['hH]/([01])['hH]/(0|[1-9][0-9]*)['hH]$")
      .firstMatch(derivationPath.trim());
  if (path == null) throw WatchOnlyImportError.path;
  final coin = mainnet ? 0 : 1;
  if (int.parse(path.group(1)!) != coin) throw WatchOnlyImportError.network;
  final account = int.tryParse(path.group(2)!);
  if (account == null || account > 0x7fffffff) throw WatchOnlyImportError.path;
  final keyVersion = switch (prefix) {
    'xpub' => Bip32Const.mainNetKeyNetVersions,
    'tpub' => Bip32Const.testNetKeyNetVersions,
    'zpub' => Bip84Conf.bip84BtcKeyNetVer,
    _ => Bip84Conf.bitcoinTestNet.keyNetVer,
  };
  final Bip32Slip10Secp256k1 parsed;
  try {
    parsed = Bip32Slip10Secp256k1.fromExtendedKey(key, keyVersion);
  } catch (_) {
    throw WatchOnlyImportError.key;
  }
  if (!parsed.isPublicOnly) throw WatchOnlyImportError.privateKey;
  if (parsed.depth.depth != 3 || parsed.index.toInt() != account + 0x80000000) {
    throw WatchOnlyImportError.account;
  }
  final normalized = Bip32PublicKeySerializer.serialize(
      parsed.publicKey.pubKey,
      parsed.publicKey.keyData,
      mainnet
          ? Bip32Const.mainNetKeyNetVersions
          : Bip32Const.testNetKeyNetVersions);
  return ColdWalletPublicMaterial(
    xpub: normalized,
    fingerprint: origin,
    derivationPath: "m/84'/$coin'/$account'",
    scriptPolicy: 'wpkh([$origin/84h/${coin}h/${account}h]$normalized/0/*)',
  );
}
