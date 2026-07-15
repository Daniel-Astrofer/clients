import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bip39_mnemonic_utils.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_key_vault.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/electrum_seed_utils.dart';

typedef ImportColdWalletFn = Future<BitcoinAccount> Function({
  required String label,
  required String xpub,
  required String fingerprint,
  required String derivationPath,
  required String scriptPolicy,
});

/// Narrow seed persistence surface used by registration (testable without KeyVault).
abstract class ColdWalletSeedStore {
  Future<void> saveSeed({
    required String walletId,
    required String mnemonic,
    required String fingerprint,
    String passphrase = '',
    ColdWalletSeedKind seedKind = ColdWalletSeedKind.bip39,
  });
}

/// Adapter so [ColdWalletKeyVault] satisfies [ColdWalletSeedStore].
class ColdWalletKeyVaultSeedStore implements ColdWalletSeedStore {
  ColdWalletKeyVaultSeedStore([ColdWalletKeyVault? vault])
      : _vault = vault ?? ColdWalletKeyVault.instance;

  final ColdWalletKeyVault _vault;

  @override
  Future<void> saveSeed({
    required String walletId,
    required String mnemonic,
    required String fingerprint,
    String passphrase = '',
    ColdWalletSeedKind seedKind = ColdWalletSeedKind.bip39,
  }) {
    return _vault.saveSeed(
      walletId: walletId,
      mnemonic: mnemonic,
      fingerprint: fingerprint,
      passphrase: passphrase,
      seedKind: seedKind,
    );
  }
}

/// Registers a WATCH_ONLY wallet on KFE and optionally stores BIP39 locally.
///
/// Contract with send flow:
/// - Seed is stored under the **KFE wallet id** returned by the API.
/// - Public material is derived with the app network path (testnet/mainnet).
class RegisterColdWalletUseCase {
  RegisterColdWalletUseCase({
    required ImportColdWalletFn importColdWallet,
    ColdWalletSeedStore? seedStore,
    ColdWalletPublicMaterialDeriver? deriver,
  })  : _importColdWallet = importColdWallet,
        _seedStore = seedStore ?? ColdWalletKeyVaultSeedStore(),
        _deriver = deriver ?? const ColdWalletPublicMaterialDeriver();

  final ImportColdWalletFn _importColdWallet;
  final ColdWalletSeedStore _seedStore;
  final ColdWalletPublicMaterialDeriver _deriver;

  /// Create or import: derive → register → save seed when [storeSeed] is true.
  ///
  /// Auto-detects **Electrum native** seeds (HMAC version). Those are not BIP39;
  /// BIP39 checksum errors on Electrum seeds are expected and handled.
  Future<RegisterColdWalletResult> registerFromMnemonic({
    required String label,
    required String mnemonic,
    String passphrase = '',
    String? derivationPath,
    bool storeSeed = true,
    bool allowInvalidChecksum = false,
  }) async {
    final electrum = ElectrumSeedUtils.detect(mnemonic);
    final String words;
    final String? path;
    final ColdWalletSeedKind kind;

    if (electrum != null) {
      words = electrum.phrase;
      // Never force BIP84 on Electrum — path is part of the seed type contract.
      path = electrum.accountDerivationPath;
      kind = ColdWalletSeedKind.electrum;
    } else {
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
      words = parsed.phrase;
      path = derivationPath ?? appColdWalletDerivationPath;
      kind = ColdWalletSeedKind.bip39;
    }

    final material = _deriver.derive(
      mnemonic: words,
      extraWord: passphrase,
      derivationPath: path,
      allowInvalidChecksum: allowInvalidChecksum,
      seedKind: kind,
    );

    final account = await _importColdWallet(
      label: label.trim().isEmpty ? 'Cold Wallet' : label.trim(),
      xpub: material.xpub,
      fingerprint: material.fingerprint,
      derivationPath: material.derivationPath,
      scriptPolicy: material.scriptPolicy,
    );

    final walletId = resolveColdWalletId(account);
    if (walletId.isEmpty) {
      throw const RegisterColdWalletException(
        'ERR_COLD_REGISTER_NO_ID',
        'O servidor não devolveu o id da carteira fria.',
      );
    }

    var seedStored = false;
    if (storeSeed) {
      try {
        await _seedStore.saveSeed(
          walletId: walletId,
          mnemonic: words,
          fingerprint: material.fingerprint,
          passphrase: passphrase,
          seedKind: material.seedKind,
        );
        seedStored = true;
      } catch (_) {
        // Server already registered the watch-only wallet. Local vault failure
        // must not surface as "create failed" after a success toast.
        seedStored = false;
      }
    }

    return RegisterColdWalletResult(
      account: account,
      walletId: walletId,
      material: material,
      seedStored: seedStored,
    );
  }

  /// Watch-only: register public material only (no local seed).
  Future<RegisterColdWalletResult> registerPublicOnly({
    required String label,
    required ColdWalletPublicMaterial material,
  }) async {
    final account = await _importColdWallet(
      label: label.trim().isEmpty ? 'Watch-only' : label.trim(),
      xpub: material.xpub,
      fingerprint: material.fingerprint,
      derivationPath: material.derivationPath,
      scriptPolicy: material.scriptPolicy,
    );
    final walletId = resolveColdWalletId(account);
    if (walletId.isEmpty) {
      throw const RegisterColdWalletException(
        'ERR_COLD_REGISTER_NO_ID',
        'O servidor não devolveu o id da carteira fria.',
      );
    }
    return RegisterColdWalletResult(
      account: account,
      walletId: walletId,
      material: material,
      seedStored: false,
    );
  }

  static String resolveColdWalletId(BitcoinAccount account) {
    final cold = account.coldWalletId?.trim() ?? '';
    if (cold.isNotEmpty) return cold;
    return account.id.trim();
  }
}

class RegisterColdWalletResult {
  final BitcoinAccount account;
  final String walletId;
  final ColdWalletPublicMaterial material;
  final bool seedStored;

  const RegisterColdWalletResult({
    required this.account,
    required this.walletId,
    required this.material,
    required this.seedStored,
  });
}

/// Navigation outcome after create/import success (hub / wizard).
class ColdWalletFlowOutcome {
  final RegisterColdWalletResult registration;
  /// When true, open unified [SendMoneyScreen] with the new wallet.
  final bool openSend;

  const ColdWalletFlowOutcome({
    required this.registration,
    this.openSend = false,
  });

  String get walletId => registration.walletId;
  bool get seedStored => registration.seedStored;
}

class RegisterColdWalletException implements Exception {
  final String code;
  final String message;

  const RegisterColdWalletException(this.code, this.message);

  @override
  String toString() => 'RegisterColdWalletException($code): $message';
}

/// User-facing error copy for create/import failures.
String coldWalletRegisterErrorMessage(Object error) {
  if (error is RegisterColdWalletException) {
    return error.message;
  }
  if (error is ArgumentError) {
    return 'Semente BIP39 inválida. Confira as palavras, a ordem e se usa 12 ou 24 palavras.';
  }
  if (error is ColdWalletKeyVaultException) {
    return error.message;
  }
  final raw = error.toString();
  if (raw.contains('ERR_WALLET_CUSTODY') ||
      raw.contains('no maximo duas') ||
      raw.contains('no máximo duas') ||
      raw.contains('máximo de carteiras frias')) {
    return 'Você já tem o máximo de carteiras frias ativas. Arquive uma para criar outra.';
  }
  if (raw.contains('SocketException') ||
      raw.contains('Timeout') ||
      raw.contains('Tor') ||
      raw.contains('connection') ||
      raw.contains('Connection')) {
    return 'Falha de rede/Tor ao registrar a carteira. Tente de novo com o circuito ativo.';
  }
  if (raw.contains('crypto port is not initialized') ||
      raw.contains('column crypto')) {
    return 'O servidor de carteiras (KFE) está sem criptografia de coluna configurada. Contate o time / reinicie o kfe-service.';
  }
  if (raw.contains('duplicate key') ||
      raw.contains('wallet_addresses_address_key') ||
      raw.contains('já está vinculado') ||
      raw.contains('already used by another')) {
    return 'Esta seed/endereço já foi importado antes. Arquive a carteira fria antiga e tente de novo (ou reabra o app se ela já existir).';
  }
  if (raw.contains('máximo duas carteiras frias') ||
      raw.contains('no maximo duas') ||
      raw.contains('no máximo duas')) {
    return 'Você já tem o máximo de carteiras frias ativas. Arquive uma para criar outra.';
  }
  if (raw.contains('400') ||
      raw.contains('409') ||
      raw.contains('500') ||
      raw.contains('ServerException') ||
      raw.contains('CONFLICT')) {
    return 'O servidor recusou o registro da carteira. Tente novamente em instantes.';
  }
  return 'Não foi possível registrar a carteira fria. Tente novamente.';
}
