import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'package:kerosene/core/constants/app_copy.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';

/// Local BIP39 vault for software cold wallets.
///
/// Seed material never leaves the device. Access is gated by biometrics / device
/// lock. Storage uses the shared Kerosene secure-storage namespace so values
/// survive process death consistently with device-key material.
class ColdWalletKeyVault {
  ColdWalletKeyVault({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuthentication,
    ColdWalletPublicMaterialDeriver? materialDeriver,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuthentication = localAuthentication ?? LocalAuthentication(),
        _materialDeriver =
            materialDeriver ?? const ColdWalletPublicMaterialDeriver();

  ColdWalletKeyVault._internal() : this();

  static final ColdWalletKeyVault instance = ColdWalletKeyVault._internal();

  String get _seedKeyPrefix => '${keroseneSecurePrefix()}cold_wallet_seed';
  String get _passphraseKeyPrefix =>
      '${keroseneSecurePrefix()}cold_wallet_passphrase';
  String get _fingerprintKeyPrefix =>
      '${keroseneSecurePrefix()}cold_wallet_fingerprint';
  String get _seedKindKeyPrefix =>
      '${keroseneSecurePrefix()}cold_wallet_seed_kind';
  String get _indexKey => '${keroseneSecurePrefix()}cold_wallet_seed_index';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuthentication;
  final ColdWalletPublicMaterialDeriver _materialDeriver;

  IOSOptions _iosOptions() =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  AndroidOptions _androidOptions() => const AndroidOptions(
        storageNamespace: 'kerosene_secure_storage',
      );

  AndroidOptions _legacyAndroidOptions() => const AndroidOptions();

  /// Persists mnemonic for [walletId] after a successful KFE watch-only import.
  ///
  /// [fingerprint] is stored to support re-bind validation later.
  Future<void> saveSeed({
    required String walletId,
    required String mnemonic,
    required String fingerprint,
    String passphrase = '',
    ColdWalletSeedKind seedKind = ColdWalletSeedKind.bip39,
  }) async {
    final id = walletId.trim();
    final words = mnemonic.trim().toLowerCase();
    if (id.isEmpty || words.isEmpty) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_INVALID_ARGS',
        'Wallet id and mnemonic are required to store the local seed.',
      );
    }

    await _secureStorage.write(
      key: _seedStorageKey(id),
      value: words,
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    final pass = passphrase.trim();
    if (pass.isNotEmpty) {
      await _secureStorage.write(
        key: _passphraseStorageKey(id),
        value: pass,
        iOptions: _iosOptions(),
        aOptions: _androidOptions(),
      );
    } else {
      await _deleteKey(_passphraseStorageKey(id));
    }
    await _secureStorage.write(
      key: _fingerprintStorageKey(id),
      value: fingerprint.trim().toLowerCase(),
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    await _secureStorage.write(
      key: _seedKindStorageKey(id),
      value: seedKind.wireName,
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    await _indexAdd(id);
  }

  Future<bool> hasSeed(String walletId) async {
    final value = await _readStorageValue(_seedStorageKey(walletId.trim()));
    return value != null && value.trim().isNotEmpty;
  }

  /// Returns mnemonic after biometric confirmation. Caller must wipe usage ASAP.
  Future<ColdWalletSeedMaterial> unlockSeed({
    required String walletId,
    String localizedReason = '',
  }) async {
    final id = walletId.trim();
    final stored = await _readStorageValue(_seedStorageKey(id));
    if (stored == null || stored.trim().isEmpty) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_SEED_MISSING',
        'Nenhuma seed local foi encontrada para esta carteira fria. '
            'Recrie o backup BIP39 neste aparelho para assinar.',
      );
    }

    await _verifyUserPresence(
      localizedReason: localizedReason.isNotEmpty
          ? localizedReason
          : AppCopy.authReasonSovereignKeyAccess.en,
    );

    final passphrase =
        (await _readStorageValue(_passphraseStorageKey(id)))?.trim() ?? '';
    final fingerprint =
        (await _readStorageValue(_fingerprintStorageKey(id)))?.trim() ?? '';
    final kindRaw =
        (await _readStorageValue(_seedKindStorageKey(id)))?.trim() ?? '';
    // Auto-detect Electrum if kind missing (legacy vault entries).
    final kind = kindRaw.isNotEmpty
        ? ColdWalletSeedKindWire.parse(kindRaw)
        : (ElectrumSeedUtils.isElectrumSeed(stored)
            ? ColdWalletSeedKind.electrum
            : ColdWalletSeedKind.bip39);

    return ColdWalletSeedMaterial(
      walletId: id,
      mnemonic: stored.trim().toLowerCase(),
      passphrase: passphrase,
      fingerprint: fingerprint,
      seedKind: kind,
    );
  }

  /// Re-bind a seed to an existing watch-only wallet after verifying xpub match.
  Future<void> rebindSeed({
    required String walletId,
    required String mnemonic,
    required String expectedXpub,
    String passphrase = '',
    String expectedFingerprint = '',
  }) async {
    final material = _materialDeriver.derive(
      mnemonic: mnemonic,
      extraWord: passphrase,
    );
    if (material.xpub.trim() != expectedXpub.trim()) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_XPUB_MISMATCH',
        'A seed informada não corresponde ao xpub desta carteira fria.',
      );
    }
    if (expectedFingerprint.trim().isNotEmpty &&
        material.fingerprint.trim().toLowerCase() !=
            expectedFingerprint.trim().toLowerCase()) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_FINGERPRINT_MISMATCH',
        'A seed informada não corresponde à fingerprint desta carteira fria.',
      );
    }
    await saveSeed(
      walletId: walletId,
      mnemonic: mnemonic,
      fingerprint: material.fingerprint,
      passphrase: passphrase,
      seedKind: material.seedKind,
    );
  }

  Future<void> deleteSeed(String walletId) async {
    final id = walletId.trim();
    await _deleteKey(_seedStorageKey(id));
    await _deleteKey(_passphraseStorageKey(id));
    await _deleteKey(_fingerprintStorageKey(id));
    await _deleteKey(_seedKindStorageKey(id));
    await _indexRemove(id);
  }

  Future<List<String>> listedWalletIds() async {
    final raw = await _readStorageValue(_indexKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _verifyUserPresence({required String localizedReason}) async {
    final canCheck = await _localAuthentication.canCheckBiometrics;
    final supported = await _localAuthentication.isDeviceSupported();
    if (!canCheck && !supported) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_NO_LOCAL_AUTH',
        'Configure biometria ou bloqueio de tela para usar a seed da carteira fria.',
      );
    }
    final ok = await _localAuthentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
    if (!ok) {
      throw const ColdWalletKeyVaultException(
        'ERR_COLD_VAULT_AUTH_CANCELLED',
        'Confirmação do dispositivo cancelada.',
      );
    }
  }

  Future<void> _indexAdd(String walletId) async {
    final current = await listedWalletIds();
    if (current.contains(walletId)) {
      return;
    }
    final next = [...current, walletId];
    await _secureStorage.write(
      key: _indexKey,
      value: jsonEncode(next),
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
  }

  Future<void> _indexRemove(String walletId) async {
    final current = await listedWalletIds();
    final next = current.where((id) => id != walletId).toList();
    await _secureStorage.write(
      key: _indexKey,
      value: jsonEncode(next),
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
  }

  Future<String?> _readStorageValue(String key) async {
    final current = await _secureStorage.read(
      key: key,
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    if (current != null && current.trim().isNotEmpty) {
      return current;
    }
    final legacy = await _secureStorage.read(
      key: key,
      iOptions: _iosOptions(),
      aOptions: _legacyAndroidOptions(),
    );
    if (legacy == null || legacy.trim().isEmpty) {
      return null;
    }
    await _secureStorage.write(
      key: key,
      value: legacy,
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    await _secureStorage.delete(
      key: key,
      iOptions: _iosOptions(),
      aOptions: _legacyAndroidOptions(),
    );
    return legacy;
  }

  Future<void> _deleteKey(String key) async {
    await _secureStorage.delete(
      key: key,
      iOptions: _iosOptions(),
      aOptions: _androidOptions(),
    );
    await _secureStorage.delete(
      key: key,
      iOptions: _iosOptions(),
      aOptions: _legacyAndroidOptions(),
    );
  }

  String _seedStorageKey(String walletId) =>
      '$_seedKeyPrefix.${_subjectToken(walletId)}';

  String _passphraseStorageKey(String walletId) =>
      '$_passphraseKeyPrefix.${_subjectToken(walletId)}';

  String _fingerprintStorageKey(String walletId) =>
      '$_fingerprintKeyPrefix.${_subjectToken(walletId)}';

  String _seedKindStorageKey(String walletId) =>
      '$_seedKindKeyPrefix.${_subjectToken(walletId)}';

  String _subjectToken(String value) =>
      base64Url.encode(utf8.encode(value.trim())).replaceAll('=', '');
}

class ColdWalletSeedMaterial {
  final String walletId;
  final String mnemonic;
  final String passphrase;
  final String fingerprint;
  final ColdWalletSeedKind seedKind;

  const ColdWalletSeedMaterial({
    required this.walletId,
    required this.mnemonic,
    this.passphrase = '',
    this.fingerprint = '',
    this.seedKind = ColdWalletSeedKind.bip39,
  });

  /// Best-effort wipe of string content (Dart strings are immutable; clears local refs).
  void dispose() {
    // No-op placeholder — callers should drop references promptly.
  }
}

class ColdWalletKeyVaultException implements Exception {
  final String code;
  final String message;

  const ColdWalletKeyVaultException(this.code, this.message);

  @override
  String toString() => 'ColdWalletKeyVaultException($code): $message';
}
