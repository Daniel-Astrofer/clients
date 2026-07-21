import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';

void main() {
  group('Transaction display rules', () {
    test('internal ledger settles without on-chain confs or network fee', () {
      final tx = Transaction.fromJson({
        'rail': 'INTERNAL',
        'direction': 'INTERNAL',
        'status': 'SETTLED',
        'grossAmountSats': 100000,
        'receiverAmountSats': 100000,
        'networkFeeSats': 0,
        'keroseneFeeSats': 0,
        'confirmations': 3,
        'sourceWalletId': 'a',
        'destinationWalletId': 'b',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isInternal, isTrue);
      expect(tx.isLedgerInternal, isTrue);
      expect(tx.isOnChain, isFalse);
      expect(tx.showsOnchainConfirmations, isFalse);
      expect(tx.showsNetworkFee, isFalse);
      expect(tx.showsServiceFee, isFalse);
      expect(tx.confirmations, 0);
      expect(tx.status, TransactionStatus.confirmed);
      expect(tx.isConfirmed, isTrue);
    });

    test('on-chain outbound exposes confirmations and network fee', () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'status': 'EXECUTING',
        'grossAmountSats': 50000,
        'receiverAmountSats': 50000,
        'networkFeeSats': 250,
        'keroseneFeeSats': 0,
        'confirmations': 2,
        'blockchainTxid': 'deadbeef',
        'sourceWalletId': 'cold',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isOnChain, isTrue);
      expect(tx.showsOnchainConfirmations, isTrue);
      expect(tx.showsNetworkFee, isTrue);
      expect(tx.feeSatoshis, 250);
      expect(tx.confirmations, 2);
      expect(tx.status, TransactionStatus.confirming);
      expect(tx.isConfirmed, isFalse);
    });

    test('settled on-chain with confs is confirmed without faking 6', () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'INBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 1000,
        'receiverAmountSats': 1000,
        'networkFeeSats': 0,
        'confirmations': 3,
        'blockchainTxid': 'aabb',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.status, TransactionStatus.confirmed);
      expect(tx.confirmations, 3);
      expect(tx.showsOnchainConfirmations, isTrue);
      expect(tx.onchainConfirmationTarget, 6);
      expect(tx.isConfirmed, isTrue);
    });

    test('mempool cold spend shows 0/6 not fake confirmed rings', () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'status': 'VALIDATING',
        'grossAmountSats': 200000,
        'receiverAmountSats': 200000,
        'networkFeeSats': 300,
        'confirmations': 0,
        'blockchainTxid': '90dfd930',
        'provider': 'BITCOIN_CORE_COLD_EXTERNAL_SPEND',
        'sourceWalletId': 'cold',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isOnChain, isTrue);
      expect(tx.showsOnchainConfirmations, isTrue);
      expect(tx.confirmations, 0);
      expect(tx.onchainConfirmationTarget, 6);
      expect(tx.status, TransactionStatus.confirming);
      expect(tx.isConfirmed, isFalse);
    });

    test('lightning does not use block confirmation UI', () {
      final tx = Transaction.fromJson({
        'rail': 'LIGHTNING',
        'direction': 'OUTBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 2000,
        'receiverAmountSats': 2000,
        'networkFeeSats': 10,
        'confirmations': 5,
        'paymentHash': 'ph',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isLightning, isTrue);
      expect(tx.isLightningEffective, isTrue);
      expect(tx.showsOnchainConfirmations, isFalse);
      expect(tx.confirmations, 0);
      expect(tx.showsNetworkFee, isTrue);
      expect(tx.status, TransactionStatus.confirmed);
    });

    test('lightning detected by paymentHash alone never shows confs', () {
      final tx = Transaction.fromJson({
        'id': 'local-ln-1',
        'fromAddress': 'a',
        'toAddress': 'b',
        'amountSatoshis': 1000,
        'feeSatoshis': 1,
        'status': 'pending',
        'type': 'withdrawal',
        'confirmations': 0,
        'timestamp': '2026-07-01T12:00:00Z',
        'isInternal': false,
        'isLightning': false,
        'paymentHash': 'abc123paymenthash',
      });

      expect(tx.isLightningEffective, isTrue);
      expect(tx.isOnChain, isFalse);
      expect(tx.showsOnchainConfirmations, isFalse);
    });

    test(
        'on-chain inbound receipt parses amount when receiverAmountSats is 0 or missing',
        () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'INBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 50000,
        'receiverAmountSats': 0,
        'networkFeeSats': 0,
        'confirmations': 6,
        'blockchainTxid': 'deadbeef123',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isCredit, isTrue);
      expect(tx.isOnChain, isTrue);
      expect(tx.amountSatoshis, 50000);
      expect(tx.amountBTC, 0.0005);
      expect(tx.signedDisplayAmountBTC, 0.0005);
    });

    test('on-chain inbound receipt parses amount from amountSats or amountBtc',
        () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'INBOUND',
        'status': 'SETTLED',
        'amountSats': 75000,
        'networkFeeSats': 0,
        'confirmations': 6,
        'blockchainTxid': 'feedbeef',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isCredit, isTrue);
      expect(tx.isOnChain, isTrue);
      expect(tx.amountSatoshis, 75000);
      expect(tx.amountBTC, 0.00075);
    });

    test(
        'on-chain outbound recovers amount from totalDebitSats when gross is 0',
        () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 0,
        'receiverAmountSats': 0,
        'networkFeeSats': 300,
        'keroseneFeeSats': 100,
        'totalDebitSats': 100400,
        'confirmations': 2,
        'blockchainTxid': 'deadbeef',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.isDebit, isTrue);
      expect(tx.isOnChain, isTrue);
      expect(tx.amountSatoshis, 100000);
      expect(tx.confirmations, 2);
      expect(tx.showsOnchainConfirmations, isTrue);
    });

    test('ignores zero fiat snapshots so display recomputes from sats', () {
      final tx = Transaction.fromJson({
        'rail': 'ONCHAIN',
        'direction': 'INBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 50000,
        'displayAmountBrl': 0,
        'displayAmountUsd': 0,
        'confirmations': 3,
        'blockchainTxid': 'abc',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(tx.amountSatoshis, 50000);
      expect(tx.displayAmountBrl, isNull);
      expect(tx.displayAmountUsd, isNull);
    });

    test('lightning and internal never show on-chain confirmation UI', () {
      final ln = Transaction.fromJson({
        'rail': 'LIGHTNING',
        'direction': 'INBOUND',
        'status': 'SETTLED',
        'grossAmountSats': 1000,
        'confirmations': 6,
        'createdAt': '2026-07-01T12:00:00Z',
      });
      final internal = Transaction.fromJson({
        'rail': 'INTERNAL',
        'direction': 'INTERNAL',
        'status': 'SETTLED',
        'grossAmountSats': 1000,
        'confirmations': 6,
        'walletId': 'a',
        'destinationWalletId': 'a',
        'createdAt': '2026-07-01T12:00:00Z',
      });

      expect(ln.showsOnchainConfirmations, isFalse);
      expect(ln.confirmations, 0);
      expect(internal.showsOnchainConfirmations, isFalse);
      expect(internal.confirmations, 0);
    });
  });
}
