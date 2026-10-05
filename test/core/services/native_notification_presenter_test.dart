import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/notifications/native_notification_presenter.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

void main() {
  const presenter = NativeNotificationPresenter();

  group('NativeNotificationPresenter', () {
    test('deposit_detected exposes amount from creditedSats + pending channel',
        () {
      final p = presenter.present(
        id: '1',
        kind: SessionNotificationItem.kindDepositDetected,
        title: 'Depósito pendente',
        body: 'Depósito de 0.001 BTC aguardando confirmações.',
        metadata: {
          'creditedSats': '100000',
          'rail': 'ONCHAIN',
          'confirmations': '0',
        },
        entityType: 'transaction',
        entityId: 'tx-1',
      );

      expect(p.channelId, NativeNotificationChannels.transactions);
      expect(p.family, NativeNotificationFamily.transactionPending);
      expect(p.title, contains('0.001'));
      expect(p.body, contains('On-chain'));
      expect(p.body, contains('0 conf'));
      expect(p.summary, 'Pendente');
      expect(p.dedupeKey, 'deposit_detected|transaction|tx-1');
      expect(p.incoming, isTrue);
    });

    test('deposit_confirmed uses receive copy and success family', () {
      final p = presenter.present(
        id: '2',
        kind: SessionNotificationItem.kindDepositConfirmed,
        title: 'Depósito confirmado',
        body: 'Depósito on-chain confirmado. Crédito líquido: 0.0025 BTC.',
        metadata: {
          'creditedSats': '250000',
          'rail': 'ONCHAIN',
          'confirmations': '3',
        },
        entityId: 'tx-2',
        entityType: 'transaction',
      );

      expect(p.family, NativeNotificationFamily.transactionIncoming);
      expect(p.title, 'Recebeu 0.0025 BTC');
      expect(p.body, contains('On-chain'));
      expect(p.summary, 'On-chain');
    });

    test('lightning rail maps network label', () {
      final p = presenter.present(
        id: '3',
        kind: SessionNotificationItem.kindDepositConfirmed,
        title: 'Depósito confirmado',
        body: 'Depósito Lightning liquidado. Crédito líquido: 0.0001 BTC.',
        metadata: {
          'creditedSats': '10000',
          'rail': 'LIGHTNING',
        },
      );
      expect(p.summary, 'Lightning');
      expect(p.body, contains('Lightning'));
    });

    test('outbound cold payment_sent is outgoing', () {
      final p = presenter.present(
        id: '4',
        kind: SessionNotificationItem.kindPaymentSent,
        title: 'Envio na cold wallet',
        body: 'Envio de 0.01 BTC detectado na carteira fria (mempool/rede).',
        metadata: {
          'amountSats': '1000000',
          'rail': 'ONCHAIN',
          'direction': 'OUTBOUND',
        },
      );
      expect(p.family, NativeNotificationFamily.transactionOutgoing);
      expect(p.title, contains('Enviou'));
      expect(p.incoming, isFalse);
    });

    test('security login uses security channel', () {
      final p = presenter.present(
        id: '5',
        kind: SessionNotificationItem.kindSecurityLoginDetected,
        title: 'Novo acesso detectado',
        body: 'Identificamos um novo acesso à sua conta Kerosene.',
      );
      expect(p.channelId, NativeNotificationChannels.security);
      expect(p.family, NativeNotificationFamily.security);
      expect(
        NativeNotificationPresenter.isSecurityKind(
          SessionNotificationItem.kindSecurityLoginDetected,
        ),
        isTrue,
      );
    });

    test('kind classification helpers', () {
      expect(
        NativeNotificationPresenter.isFinancialKind(
          SessionNotificationItem.kindDepositDetected,
        ),
        isTrue,
      );
      expect(
        NativeNotificationPresenter.isNativeAlertKind(
          SessionNotificationItem.kindSecurityLoginDetected,
        ),
        isTrue,
      );
      expect(
        NativeNotificationPresenter.isNativeAlertKind(
          SessionNotificationItem.kindSystemInfo,
        ),
        isFalse,
      );
      expect(
        NativeNotificationPresenter.isNativeAlertKind(
          SessionNotificationItem.kindMarketAlert,
        ),
        isFalse,
      );
    });

    test('presentSession maps session item', () {
      final item = SessionNotificationItem(
        id: '9',
        title: 'Depósito pendente',
        body: 'Depósito de 0.001 BTC aguardando confirmações.',
        timestamp: DateTime.now(),
        kind: SessionNotificationItem.kindDepositDetected,
        metadata: const {
          'creditedSats': '100000',
          'rail': 'ONCHAIN',
        },
        entityType: 'transaction',
        entityId: 'tx-9',
      );
      final p = presenter.presentSession(item);
      expect(p.title, contains('0.001'));
      expect(p.dedupeKey, contains('tx-9'));
    });
  });
}
