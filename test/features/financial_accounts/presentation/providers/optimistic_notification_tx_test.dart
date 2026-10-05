import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

void main() {
  test('optimisticTransactionFromNotification builds inbound row from meta',
      () {
    final notification = SessionNotificationItem(
      id: 'n1',
      title: 'Depósito',
      body: 'Recebido',
      timestamp: DateTime.utc(2026, 7, 21, 12),
      kind: SessionNotificationItem.kindDepositDetected,
      entityType: 'transaction',
      entityId: 'tx-uuid-1',
      metadata: const {
        'transactionId': 'tx-uuid-1',
        'walletId': 'wallet-1',
        'rail': 'ONCHAIN',
        'creditedSats': '29326',
        'confirmations': '1',
        'direction': 'INBOUND',
      },
    );

    final tx = optimisticTransactionFromNotification(notification);
    expect(tx, isNotNull);
    expect(tx!.id, 'tx-uuid-1');
    expect(tx.amountSatoshis, 29326);
    expect(tx.isCredit, isTrue);
    expect(tx.rail, 'ONCHAIN');
    expect(tx.walletId, 'wallet-1');
    expect(tx.status, TransactionStatus.confirming);
    expect(tx.confirmations, 1);
  });

  test('optimisticTransactionFromNotification ignores non-incoming kinds', () {
    final notification = SessionNotificationItem(
      id: 'n2',
      title: 'Envio',
      body: 'Enviado',
      timestamp: DateTime.utc(2026, 7, 21, 12),
      kind: 'outbound_confirmed',
      metadata: const {
        'transactionId': 'tx-out',
        'creditedSats': '100',
      },
    );
    expect(optimisticTransactionFromNotification(notification), isNull);
  });
}
