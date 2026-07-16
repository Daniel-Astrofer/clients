import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';

void main() {
  group('Wallet balance display (PR4)', () {
    test('cold wallet primary balance uses observed sats', () {
      final wallet = Wallet.fromJson({
        'id': 'cold-1',
        'label': 'Cold',
        'kind': 'WATCH_ONLY',
        'spendable': false,
        'availableSats': 0,
        'observedSats': 150000000,
      });
      expect(wallet.isColdWallet, isTrue);
      expect(wallet.balance, closeTo(1.5, 1e-9));
      expect(wallet.observedSats, 150000000);
      expect(wallet.primaryBalanceLabel, 'Saldo na rede');
      expect(wallet.chainObservedSubtitle, isNull);
    });

    test('custodial shows available and chain subtitle when diverged', () {
      final wallet = Wallet.fromJson({
        'id': 'cust-1',
        'label': 'Money',
        'kind': 'CUSTODIAL_ONCHAIN',
        'spendable': true,
        'availableSats': 100000000,
        'observedSats': 200000000,
      });
      expect(wallet.isCustodialOnchain, isTrue);
      expect(wallet.balance, closeTo(1.0, 1e-9));
      expect(wallet.primaryBalanceLabel, 'Disponível para enviar');
      expect(wallet.chainObservedSubtitle, 'Na rede (cadeia): 2 BTC');
    });

    test('bitcoin account visible balance + chain label', () {
      final cold = BitcoinAccount(
        id: 'c',
        type: 'WATCH_ONLY_COLD_WALLET',
        custody: 'WATCH_ONLY',
        status: 'ACTIVE',
        label: 'Cold',
        riskTier: 'BRONZE',
        observedBalanceSats: 5000,
      );
      final custodial = BitcoinAccount(
        id: 'm',
        type: 'CUSTODIAL',
        custody: 'CUSTODIAL_ONCHAIN',
        status: 'ACTIVE',
        label: 'Money',
        riskTier: 'BRONZE',
        balanceAvailableSats: 1000,
        balancePendingSats: 0,
        observedBalanceSats: 5000,
      );
      expect(bitcoinAccountVisibleBalance(cold), 5000);
      expect(bitcoinAccountVisibleBalance(custodial), 1000);
      expect(bitcoinAccountChainObservedLabel(custodial), 'Na rede: 0.00005 BTC');
      expect(bitcoinAccountChainObservedLabel(cold), isNull);
    });
  });
}
