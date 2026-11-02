import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/balance_websocket_service.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/notification_translator.dart';

void main() {
  test(
      'realtime missing time stays unknown and gets a stable fallback identity',
      () {
    final payload = {'body': 'Public fixture', 'timestamp': 'malformed'};
    final first = RealtimeNotificationEvent.fromJson(payload);
    final second = RealtimeNotificationEvent.fromJson(payload);
    expect(first.timestamp, isNull);
    expect(first.id, second.id);
    expect(first.title, isEmpty);
  });
  test('realtime and REST use the same valid date alias', () {
    final payload = {
      'timestamp': 'malformed',
      'createdAt': '2020-01-02T03:04:05Z'
    };
    expect(RealtimeNotificationEvent.fromJson(payload).timestamp?.toUtc(),
        SessionNotificationItem.fromJson(payload).timestamp?.toUtc());
  });
  test('undated notice never produces a dated financial statement row', () {
    final item = SessionNotificationItem.fromJson({
      'id': '1',
      'kind': SessionNotificationItem.kindDepositConfirmed,
      'entityId': 'public-operation',
      'metadata': {'amountSats': '123', 'confirmations': '3'},
    });
    expect(optimisticTransactionFromNotification(item), isNull);
  });
  test('unknown dates sort after genuine instants', () {
    expect(AppDateTime.compareNewestFirst(null, DateTime.utc(2020)),
        greaterThan(0));
    expect(
        AppDateTime.compareNewestFirst(DateTime.utc(2020), null), lessThan(0));
    expect(AppDateTime.compareNewestFirst(null, null), 0);
  });
  test('server-authored title and precise body survive rendering unchanged',
      () {
    final item = SessionNotificationItem.fromJson({
      'title': 'Operação em análise',
      'body': 'Valor registrado: 0.00000001 BTC. Aguarde a confirmação.',
      'kind': SessionNotificationItem.kindTransferSent,
      'metadata': {'amount': '999', 'currency': 'USD'},
    });
    expect(NotificationTranslator.resolveTitle(null, item), item.title);
    expect(NotificationTranslator.resolveBody(null, item), item.body);
  });
  test(
      'legacy missing metadata never names a default wallet, currency or destination',
      () {
    final item = SessionNotificationItem.fromJson({
      'title': 'notification.transaction.cold.inbound.detected.title',
      'body': 'notification.transaction.cold.inbound.detected.body',
      'kind': SessionNotificationItem.kindTransferReceived,
    });
    final body = NotificationTranslator.resolveBody(null, item);
    expect(body, 'Consulte os detalhes para ver os dados desta operação.');
    expect(body, isNot(contains('Principal')));
    expect(body, isNot(contains('BTC')));
    expect(body, isNot(contains('endereço externo')));
  });
  test('legacy explicit amount retains every digit with the known unit', () {
    final item = SessionNotificationItem.fromJson({
      'body': 'notification.transaction.cold.outbound.detected.body',
      'kind': SessionNotificationItem.kindTransferSent,
      'metadata': {'amountBtc': '0.00000001'},
    });
    expect(NotificationTranslator.resolveBody(null, item),
        contains('0.00000001 BTC'));
  });
  test(
      'legacy satoshi fields keep the explicit unit even when another currency exists',
      () {
    final item = SessionNotificationItem.fromJson({
      'kind': SessionNotificationItem.kindTransferSent,
      'metadata': {'creditedSats': '123456789', 'currency': 'BTC'},
    });
    expect(NotificationTranslator.resolveBody(null, item),
        contains('123456789 sats'));
  });
}
