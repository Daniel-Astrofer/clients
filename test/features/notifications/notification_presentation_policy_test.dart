import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

SessionNotificationItem _item({
  required String id,
  String kind = SessionNotificationItem.kindSystemInfo,
  String severity = SessionNotificationItem.severityInfo,
  String? deeplink,
}) {
  return SessionNotificationItem(
    id: id,
    title: id,
    body: 'body',
    timestamp: DateTime(2026, 9, 26),
    kind: kind,
    severity: severity,
    deeplink: deeplink,
  );
}

void main() {
  test('financial and security events persist until seen or action', () {
    final financial = _item(
      id: 'payment-1',
      kind: SessionNotificationItem.kindPaymentSent,
      severity: SessionNotificationItem.severitySuccess,
    );
    final security = _item(
      id: 'security-1',
      kind: SessionNotificationItem.kindSecurityLoginDetected,
      severity: SessionNotificationItem.severityWarning,
      deeplink: '/settings/security',
    );

    expect(financial.presentationPriority, greaterThan(100));
    expect(
      financial.presentationPolicy,
      NotificationPresentationPolicy.persistUntilSeen,
    );
    expect(
      security.presentationPolicy,
      NotificationPresentationPolicy.persistUntilAction,
    );
  });

  test('critical event interrupts lower priority content and preserves it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(notificationBannerProvider.notifier);
    final first = _item(id: 'first');
    final second = _item(
      id: 'security',
      kind: SessionNotificationItem.kindSecurityLoginDetected,
      severity: SessionNotificationItem.severityWarning,
    );

    notifier.show(first);
    notifier.show(second);
    expect(container.read(notificationBannerProvider)?.id, 'security');

    notifier.dismiss();
    expect(container.read(notificationBannerProvider)?.id, 'first');
  });
}
