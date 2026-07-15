import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_psbt_signer.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('matchesXpub agrees with public material deriver', () {
    final material = const ColdWalletPublicMaterialDeriver().derive(
      mnemonic: mnemonic,
    );
    final signer = ColdWalletPsbtSigner(addressLookahead: 5);
    expect(
      signer.matchesXpub(mnemonic: mnemonic, expectedXpub: material.xpub),
      isTrue,
    );
    expect(
      signer.matchesXpub(mnemonic: mnemonic, expectedXpub: 'xpub-wrong'),
      isFalse,
    );
  });

  test('rejects empty PSBT', () {
    final signer = ColdWalletPsbtSigner(addressLookahead: 5);
    expect(
      () => signer.signPsbtWithMnemonic(
        mnemonic: mnemonic,
        unsignedPsbtBase64: '   ',
      ),
      throwsA(isA<ColdWalletPsbtSignerException>()),
    );
  });
}
