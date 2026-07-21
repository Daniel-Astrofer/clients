import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_helpers.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

void main() {
  group('unified cold send copy', () {
    test('sendReviewNote describes cold source on-chain', () {
      expect(
        sendReviewNote(
          const SendDestinationAnalysis(
            type: SendDestinationType.onChain,
            normalizedValue: 'tb1qtest',
          ),
          isPaymentLink: false,
          coldSource: true,
        ),
        contains('aparelho'),
      );
    });

    test('wallet cold helpers', () {
      final cold = Wallet(
        id: 'w1',
        name: 'Cold',
        address: 'tb1qtest',
        balance: 0.001,
        derivationPath: "m/84'/0'/0'",
        type: WalletType.nativeSegwit,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        walletMode: 'SELF_CUSTODY',
        spendable: false,
      );
      expect(cold.isColdWallet, isTrue);
      expect(cold.spendable, isFalse);
    });
  });
}
