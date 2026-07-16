import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/push_token_source.dart';

void main() {
  tearDown(PushTokenSource.clearRemoteToken);

  group('PushTokenSource', () {
    test('defaults to local-alert token', () {
      expect(
        PushTokenSource.primaryToken(installId: 'abc-123'),
        'local-alert:abc-123',
      );
      expect(PushTokenSource.hasRemoteToken, isFalse);
      expect(
        PushTokenSource.secondaryLocalAlertToken(installId: 'abc-123'),
        isNull,
      );
    });

    test('prefers remote override and keeps local secondary', () {
      PushTokenSource.remoteTokenOverride =
          'fcm-token-value-long-enough-0123456789';
      expect(PushTokenSource.hasRemoteToken, isTrue);
      expect(
        PushTokenSource.primaryToken(installId: 'abc-123'),
        'fcm-token-value-long-enough-0123456789',
      );
      expect(
        PushTokenSource.secondaryLocalAlertToken(installId: 'abc-123'),
        'local-alert:abc-123',
      );
    });

    test('ignores local-alert style override as remote', () {
      PushTokenSource.remoteTokenOverride = 'local-alert:xyz';
      expect(PushTokenSource.hasRemoteToken, isFalse);
      expect(
        PushTokenSource.primaryToken(installId: 'xyz'),
        'local-alert:xyz',
      );
    });
  });
}
