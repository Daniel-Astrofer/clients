import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/presentation/providers/incoming_transfer_theater.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

void main() {
  group('formatBtcAmountLabel', () {
    test('formats sats as compact BTC', () {
      expect(formatBtcAmountLabel(100000), '0.001 BTC');
      expect(formatBtcAmountLabel(1500), '0.000015 BTC');
      expect(formatBtcAmountLabel(0), 'fundos');
    });
  });

  group('payloadFromNotification', () {
    test('reads creditedSats metadata and entityId for dedupe', () {
      final n = SessionNotificationItem(
        id: '99',
        title: 'Depósito pendente',
        body: 'Depósito de 0.001 BTC aguardando confirmações.',
        timestamp: DateTime.now(),
        kind: SessionNotificationItem.kindDepositDetected,
        metadata: {
          'creditedSats': '100000',
          'rail': 'ONCHAIN',
          'walletId': 'w1',
        },
        entityType: 'transaction',
        entityId: 'tx-uuid-1',
      );

      final payload = payloadFromNotification(n);
      expect(payload, isNotNull);
      expect(payload!.id, 'tx-uuid-1');
      expect(payload.amountLabel, '0.001 BTC');
      expect(payload.networkLabel, 'Onchain');
    });

    test('maps lightning rail from metadata', () {
      final n = SessionNotificationItem(
        id: '1',
        title: 'Depósito confirmado',
        body: 'Depósito Lightning liquidado. Crédito líquido: 0.0001 BTC.',
        timestamp: DateTime.now(),
        kind: SessionNotificationItem.kindDepositConfirmed,
        metadata: {
          'creditedSats': '10000',
          'rail': 'LIGHTNING',
        },
        entityId: 'tx-ln-1',
      );

      final payload = payloadFromNotification(n)!;
      expect(payload.networkLabel, 'Lightning');
      expect(payload.amountLabel, '0.0001 BTC');
    });

    test('ignores outgoing kinds', () {
      final n = SessionNotificationItem(
        id: '1',
        title: 'Envio',
        body: 'Envio de 0.01 BTC',
        timestamp: DateTime.now(),
        kind: SessionNotificationItem.kindPaymentSent,
      );
      expect(payloadFromNotification(n), isNull);
    });
  });

  group('payloadFromTransaction', () {
    test('builds theater payload for credit deposit', () {
      final tx = Transaction(
        id: 'tx-abc',
        fromAddress: 'a',
        toAddress: 'b',
        amountSatoshis: 250000,
        feeSatoshis: 0,
        status: TransactionStatus.confirmed,
        type: TransactionType.deposit,
        confirmations: 1,
        timestamp: DateTime.now(),
        walletLabel: 'Fria',
        rail: 'ONCHAIN',
      );

      final payload = payloadFromTransaction(tx)!;
      expect(payload.id, 'tx-abc');
      expect(payload.amountLabel, '0.0025 BTC');
      expect(payload.walletName, 'Fria');
      expect(payload.networkLabel, 'Onchain');
    });

    test('skips debits', () {
      final tx = Transaction(
        id: 'tx-out',
        fromAddress: 'a',
        toAddress: 'b',
        amountSatoshis: 1000,
        feeSatoshis: 0,
        status: TransactionStatus.confirmed,
        type: TransactionType.send,
        confirmations: 1,
        timestamp: DateTime.now(),
      );
      expect(payloadFromTransaction(tx), isNull);
    });
  });

  group('isInboundBalanceCredit', () {
    test('accepts crédito / observado credits', () {
      expect(
        isInboundBalanceCredit(amountBtc: 0.01, context: 'crédito'),
        isTrue,
      );
      expect(
        isInboundBalanceCredit(amountBtc: 0.01, context: 'crédito observado'),
        isTrue,
      );
    });

    test('rejects reserve unlock and outbound contexts', () {
      expect(
        isInboundBalanceCredit(amountBtc: 0.01, context: 'liberação de reserva'),
        isFalse,
      );
      expect(
        isInboundBalanceCredit(amountBtc: 0.01, context: 'reserva'),
        isFalse,
      );
      expect(
        isInboundBalanceCredit(amountBtc: -0.01, context: 'crédito'),
        isFalse,
      );
    });
  });
}
