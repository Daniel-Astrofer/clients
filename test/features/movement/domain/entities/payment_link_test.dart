import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';

void main() {
  for (final value in [9007199254740993, '9007199254740993']) {
    test('integer request and credit survive projection: $value', () {
      final link = PaymentLink.fromJson({
        'id': 'exact',
        'status': 'PAID',
        'settlementStatus': 'SETTLED',
        'amountSats': value,
        'receiverAmountSats': value,
      });
      expect(link.amountSatoshis, 9007199254740993);
      expect(link.netAmountSatoshis, 9007199254740993);
      expect(link.toTransaction().amountSatoshis, 9007199254740993);
    });
  }
  for (final value in [
    -1,
    1.5,
    '1.5',
    double.nan,
    double.infinity,
    9007199254740992.0
  ]) {
    test('invalid canonical sats never become a fabricated amount: $value', () {
      expect(
          () => PaymentLink.fromJson(
              {'id': 'invalid', 'receiverAmountSats': value}),
          throwsFormatException);
    });
  }
  test('BTC-only legacy requests retain their existing projection', () {
    final link = PaymentLink.fromJson({
      'id': 'legacy',
      'status': 'PAID',
      'settlementStatus': 'SETTLED',
      'amountBtc': 0.0015,
      'netAmountBtc': 0.0014
    });
    expect(link.amountSatoshis, isNull);
    expect(link.netAmountSatoshis, isNull);
    expect(link.toTransaction().amountSatoshis, 140000);
  });
  group('PaymentLink settlement fields', () {
    for (final status in ['EXPIRED', 'CANCELED', 'FAILED']) {
      test('$status terminal request does not become a confirmed credit', () {
        final link = PaymentLink.fromJson({
          'id': 'closed',
          'status': status,
          'terminal': true,
          'amountSats': 150000,
          'confirmations': 6,
        });
        expect(
            link.toTransaction().status,
            status == 'FAILED'
                ? TransactionStatus.failed
                : TransactionStatus.cancelled);
      });
    }
    test('block confirmations alone do not prove settlement', () {
      final link = PaymentLink.fromJson({
        'id': 'observed',
        'status': 'PAID',
        'settlementStatus': 'VALIDATING',
        'blockchainTxid': 'chain-1',
        'confirmations': 6,
        'amountSats': 150000,
      });
      expect(link.toTransaction().status, TransactionStatus.confirming);
    });
    test('settled credit remains confirmed after request expiry', () {
      final link = PaymentLink.fromJson({
        'id': 'settled',
        'status': 'PAID',
        'settlementStatus': 'SETTLED',
        'expiresAt': '2020-01-01T00:00:00Z',
        'amountSats': 150000,
      });
      expect(link.toTransaction().status, TransactionStatus.confirmed);
      expect(link.toTransaction().description, isNot(contains('expirado')));
      expect(link.toTransaction().confirmations, 0);
    });
    for (final netSats in [0, 140000]) {
      test(
          'preserves explicit receiver amount $netSats independently of request',
          () {
        final link = PaymentLink.fromJson({
          'id': 'net',
          'status': 'PAID',
          'settlementStatus': 'SETTLED',
          'amountSats': 150000,
          'receiverAmountSats': netSats,
          'partialPaymentReceived': 10000,
        });
        expect(link.hasNetAmount, isTrue);
        expect(link.netAmountBtc, netSats / 100000000);
        expect(link.toTransaction().amountSatoshis, netSats);
        expect(link.partialPaymentReceivedSats, 10000);
      });
    }

    test('expired request with an observed payment keeps tracking settlement',
        () {
      final link = PaymentLink.fromJson({
        'id': 'late',
        'status': 'PENDING',
        'settlementStatus': 'VALIDATING',
        'amountSats': 150000,
        'blockchainTxid': 'chain-1',
        'expiresAt': '2020-01-01T00:00:00Z'
      });
      expect(link.toTransaction().status, TransactionStatus.confirming);
    });
    test(
        'failure is preserved even if stale settlement metadata says validating',
        () {
      final link = PaymentLink.fromJson({
        'id': 'failed',
        'status': 'FAILED',
        'settlementStatus': 'VALIDATING',
        'amountSats': 150000
      });
      expect(link.status, 'failed');
      expect(link.toTransaction().status, TransactionStatus.failed);
    });

    test('parses KFE settlement metadata', () {
      final link = PaymentLink.fromJson({
        'id': 'pay_1',
        'userId': 10,
        'amountBtc': 0.0002,
        'description': 'Invoice',
        'depositAddress': 'bc1qexample',
        'status': 'paid',
        'txid': 'tx-1',
        'paymentRail': 'ONCHAIN',
        'settlementStatus': 'SETTLED',
        'settlementReference': 'tx-1',
        'terminal': true,
      });

      expect(link.paymentRail, 'ONCHAIN');
      expect(link.settlementStatus, 'SETTLED');
      expect(link.settlementReference, 'tx-1');
      expect(link.terminal, isTrue);
    });

    test('derives settlement metadata from KFE status', () {
      final link = PaymentLink.fromJson({
        'id': 'pay_2',
        'userId': 10,
        'amountBtc': 0.0002,
        'description': 'Invoice',
        'depositAddress': 'bc1qexample',
        'status': 'cancelled',
      });

      expect(link.paymentRail, 'ONCHAIN');
      expect(link.settlementStatus, 'CANCELED');
      expect(link.terminal, isTrue);
    });

    test('parses LIGHTNING bolt11 payment request fields', () {
      final link = PaymentLink.fromJson({
        'id': 'pay_ln_1',
        'userId': 10,
        'amountBtc': 0.0001,
        'description': 'Lightning invoice',
        'paymentRail': 'LIGHTNING',
        'paymentRequest': 'lntb100n1pexamplebolt11invoicepayloadforqrencoding',
        'paymentHash': 'abc123paymenthash',
        'status': 'pending',
      });

      expect(link.isLightningPaymentRequest, isTrue);
      expect(
          link.shareablePaymentPayload, startsWith('lntb100n1pexamplebolt11'));
      expect(link.paymentHash, 'abc123paymenthash');

      final tx = link.toTransaction();
      expect(tx.isLightning, isTrue);
      expect(tx.rail, 'LIGHTNING');
      expect(tx.lightningInvoice, startsWith('lntb100n1pexamplebolt11'));
      expect(tx.paymentHash, 'abc123paymenthash');
    });
  });
}
