import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

void main() {
  group('SessionNotificationItem timestamp parsing', () {
    test('treats bare ISO from REST as UTC wall clock', () {
      final item = SessionNotificationItem.fromJson({
        'id': '1',
        'title': 'Test',
        'body': 'Body',
        'createdAt': '2026-07-15T22:47:00',
        'kind': SessionNotificationItem.kindSystemInfo,
        'severity': SessionNotificationItem.severityInfo,
      });

      expect(item.timestamp.toUtc().year, 2026);
      expect(item.timestamp.toUtc().month, 7);
      expect(item.timestamp.toUtc().day, 15);
      expect(item.timestamp.toUtc().hour, 22);
      expect(item.timestamp.toUtc().minute, 47);
      expect(item.timestamp.isUtc, isFalse);
    });

    test('honors explicit Z offset from websocket payloads', () {
      final item = SessionNotificationItem.fromJson({
        'id': '2',
        'title': 'Live',
        'body': 'Push',
        'timestamp': '2026-07-15T22:47:00Z',
      });

      expect(item.timestamp.toUtc().hour, 22);
      expect(item.timestamp.toUtc().minute, 47);
    });

    test('round-trips through toJson with UTC Z so cache stays stable', () {
      final original = SessionNotificationItem.fromJson({
        'id': '3',
        'title': 'Cache',
        'body': 'Round trip',
        'createdAt': '2026-07-15T22:47:00',
      });

      final encoded = original.toJson();
      expect(encoded['timestamp'], contains('Z'));

      final restored = SessionNotificationItem.fromJson(encoded);
      expect(
        restored.timestamp.toUtc().millisecondsSinceEpoch,
        original.timestamp.toUtc().millisecondsSinceEpoch,
      );
    });
  });
}
