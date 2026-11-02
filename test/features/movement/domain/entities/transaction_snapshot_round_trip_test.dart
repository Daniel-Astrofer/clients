import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

void main() {
  for (final type in TransactionType.values) {
    for (final status in TransactionStatus.values) {
      test('stored $type / $status preserves the complete recorded operation',
          () {
        final original = Transaction(
            id: 'stored-operation',
            fromAddress: 'bc1qsource-full-public-address',
            toAddress: 'bc1qdestination-full-public-address',
            walletId: 'wallet-history',
            sourceWalletId: 'source-wallet',
            destinationWalletId: 'destination-wallet',
            senderDisplayName: 'Origem',
            receiverDisplayName: 'Destino',
            walletLabel: 'Conta de uso diário',
            sourceWalletLabel: 'Conta de origem',
            destinationWalletLabel: 'Conta de destino',
            counterpartyLabel: 'Contraparte',
            amountSatoshis: 987654321,
            feeSatoshis: 1234,
            serviceFeeSatoshis: 56,
            totalDebitedSatoshis: 987655611,
            status: status,
            type: type,
            confirmations: 2,
            timestamp: DateTime.utc(2026, 10, 10, 12),
            updatedAt: DateTime.utc(2026, 10, 10, 12, 5),
            blockchainTxid: 'full-public-chain-reference',
            blockHash: 'full-public-block-reference',
            blockHeight: 123,
            externalReference: 'full-public-checkout-reference',
            externalTransferId: 'external-operation',
            externalTransferStatus: 'EXECUTING',
            externalTransferType: 'OUTBOUND',
            invoiceId: 'invoice-id',
            lightningInvoice: 'public-invoice-fixture',
            paymentHash: 'full-public-payment-hash',
            description: 'Nota registrada',
            rail: 'ONCHAIN',
            provider: 'BITCOIN_CORE',
            hasNetworkFee: true,
            failureCode: 'PUBLIC_FAILURE_CODE',
            cancellable: true,
            cancelTarget: 'TRANSACTION',
            paymentRequestId: 'request-id',
            paymentRequestPublicId: 'public-request-id',
            paymentRequestStatus: 'OPEN',
            displayAmountUsd: 123.45,
            displayAmountEur: 120.12,
            displayAmountBrl: 650.67,
            displayBtcUsd: 50000,
            displayBtcEur: 48000,
            displayBtcBrl: 250000);
        final restored = Transaction.fromJson(
            jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
        expect(restored.toJson(), original.toJson());
      });
    }
  }

  for (final rail in ['INTERNAL', 'LIGHTNING']) {
    test('stored $rail operation retains its network and zero fees', () {
      final original = Transaction(
          id: 'stored-$rail',
          fromAddress: 'Conta de origem',
          toAddress: 'Conta de destino',
          amountSatoshis: 1,
          feeSatoshis: 0,
          serviceFeeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.receive,
          confirmations: 0,
          timestamp: DateTime.utc(2026, 10, 10),
          updatedAt: DateTime.utc(2026, 10, 10),
          rail: rail,
          isInternal: rail == 'INTERNAL',
          isLightning: rail == 'LIGHTNING');
      expect(
          Transaction.fromJson(original.toJson()).toJson(), original.toJson());
    });
  }

  test('KFE payload with amountSatoshis retains authoritative API rules', () {
    final tx = Transaction.fromJson({
      'id': 'remote-operation',
      'amountSatoshis': 1000,
      'feeSatoshis': 99,
      'networkFeeSats': 5,
      'fromAddress': 'legacy-source',
      'toAddress': 'legacy-destination',
      'externalReference': 'bc1qactual-public-destination',
      'timestamp': '2026-10-10T12:00:00Z',
      'status': 'SETTLED',
      'type': 'send',
      'rail': 'ONCHAIN',
      'direction': 'OUTBOUND',
      'confirmations': 6,
    });
    expect(tx.status, TransactionStatus.confirmed);
    expect(tx.feeSatoshis, 5);
    expect(tx.toAddress, 'bc1qactual-public-destination');
  });

  for (final timestamp in ['invalid-date', null]) {
    test(
        'invalid stored timestamp is rejected instead of becoming now: $timestamp',
        () {
      final stored = Transaction(
              id: 'stored-invalid-date',
              fromAddress: 'source',
              toAddress: 'destination',
              amountSatoshis: 1,
              feeSatoshis: 0,
              status: TransactionStatus.pending,
              type: TransactionType.send,
              confirmations: 0,
              timestamp: DateTime.utc(2026))
          .toJson();
      stored['timestamp'] = timestamp;
      expect(() => Transaction.fromJson(stored), throwsFormatException);
    });
  }

  for (final timestamp in [
    DateTime(2026, 10, 10, 12),
    DateTime.utc(2026, 10, 10, 12)
  ]) {
    test(
        'stored ISO keeps its original zone representation: utc=${timestamp.isUtc}',
        () {
      final original = Transaction(
          id: 'stored-clock',
          fromAddress: 'source',
          toAddress: 'destination',
          amountSatoshis: 1,
          feeSatoshis: 0,
          status: TransactionStatus.pending,
          type: TransactionType.send,
          confirmations: 0,
          timestamp: timestamp,
          updatedAt: timestamp);
      final restored = Transaction.fromJson(original.toJson());
      expect(restored.timestamp.isAtSameMomentAs(timestamp), isTrue);
      expect(restored.timestamp.isUtc, timestamp.isUtc);
      expect(restored.toJson(), original.toJson());
    });
  }
}
