    test('walletMatchesSendRail checks spendability appropriately', () {
      final internalSpendable = Wallet.empty().copyWith(
        id: '1',
        isInternalCustody: true,
        spendable: true,
      );
      final internalNotSpendable = Wallet.empty().copyWith(
        id: '2',
        isInternalCustody: true,
        spendable: false,
      );
      final custodialSpendable = Wallet.empty().copyWith(
        id: '3',
        isCustodialOnchain: true,
        spendable: true,
      );
      final custodialNotSpendable = Wallet.empty().copyWith(
        id: '4',
        isCustodialOnchain: true,
        spendable: false,
      );
      final cold = Wallet.empty().copyWith(
        id: '5',
        isColdWallet: true,
      );

      // Internal rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.internal), isTrue);
      expect(walletMatchesSendRail(internalNotSpendable, PaymentRail.internal), isFalse);

      // Lightning rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.lightning), isTrue);
      expect(walletMatchesSendRail(custodialSpendable, PaymentRail.lightning), isFalse);

      // Onchain rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(custodialSpendable, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(custodialNotSpendable, PaymentRail.onchain), isFalse);
      expect(walletMatchesSendRail(cold, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(cold, PaymentRail.coldOnchain), isTrue);
    });
