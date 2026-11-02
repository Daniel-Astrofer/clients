import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_psbt_signer.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_key_vault.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';

const phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
      'leading and trailing password spaces produce the intended key and remain in storage',
      () async {
    const password = ' TREZOR ';
    const deriver = ColdWalletPublicMaterialDeriver();
    final literal = deriver.derive(mnemonic: phrase, extraWord: password);
    final trimmed =
        deriver.derive(mnemonic: phrase, extraWord: password.trim());
    expect(literal.xpub, isNot(trimmed.xpub));
    final signer = ColdWalletPsbtSigner();
    expect(
        signer.matchesXpub(
            mnemonic: phrase, passphrase: password, expectedXpub: literal.xpub),
        isTrue);
    expect(
        signer.matchesXpub(
            mnemonic: phrase,
            passphrase: password.trim(),
            expectedXpub: literal.xpub),
        isFalse);
    await ColdWalletKeyVault().saveSeed(
        walletId: 'wallet',
        mnemonic: phrase,
        passphrase: password,
        fingerprint: literal.fingerprint);
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.values, contains(password));
    expect(stored.values, isNot(contains(password.trim())));
  });

  test('invalid phrase errors never contain the supplied secret', () async {
    const secret = 'private recovery content never print this';
    Object? derivationError;
    try {
      const ColdWalletPublicMaterialDeriver().derive(mnemonic: secret);
    } catch (error) {
      derivationError = error;
    }
    expect(derivationError, isA<ArgumentError>());
    expect(derivationError.toString(), isNot(contains(secret)));
    final useCase = RegisterColdWalletUseCase(
        importColdWallet: (
                {required label,
                required xpub,
                required fingerprint,
                required derivationPath,
                required scriptPolicy}) async =>
            BitcoinAccount.fromJson(
                {'id': 'wallet', 'type': 'WATCH_ONLY', 'label': label}));
    try {
      await useCase.registerFromMnemonic(label: 'Imported', mnemonic: secret);
      fail('Invalid phrase must be rejected');
    } catch (error) {
      expect(error.toString(), isNot(contains(secret)));
    }
  });
}
