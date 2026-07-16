import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/sovereign_auth_service.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';

void main() {
  group('isAuthUserCancellation', () {
    test('detects DeviceKeyException cancel code', () {
      expect(
        isAuthUserCancellation(
          const DeviceKeyException(
            'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED',
            'cancelled',
          ),
        ),
        isTrue,
      );
    });

    test('detects SovereignAuthException cancel code', () {
      expect(
        isAuthUserCancellation(
          const SovereignAuthException(
            code: SovereignAuthErrorCodes.authCancelled,
            message: 'cancelled',
          ),
        ),
        isTrue,
      );
    });

    test('detects cancel codes embedded in strings', () {
      expect(
        isAuthUserCancellation(
          Exception('ERR_COLD_VAULT_AUTH_CANCELLED: vault'),
        ),
        isTrue,
      );
    });

    test('does not treat real auth failures as cancel', () {
      expect(
        isAuthUserCancellation(
          const DeviceKeyException(
            'ERR_AUTH_DEVICE_KEY_NO_LOCAL_CREDENTIALS',
            'no biometrics',
          ),
        ),
        isFalse,
      );
      expect(
        isAuthUserCancellation(
          Exception('ERR_LEDGER_INSUFFICIENT_BALANCE'),
        ),
        isFalse,
      );
    });
  });

  group('TransactionAuthResult', () {
    test('cancelled is not authenticated and not unavailable', () {
      const result = TransactionAuthResult.cancelled();
      expect(result.isAuthenticated, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.isUnavailable, isFalse);
    });

    test('unavailable is not authenticated and not cancelled', () {
      const result = TransactionAuthResult.unavailable();
      expect(result.isAuthenticated, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.isUnavailable, isTrue);
    });

    test('success is authenticated with factors', () {
      const result = TransactionAuthResult.success(
        totpCode: '123456',
        appPin: '1234',
      );
      expect(result.isAuthenticated, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.isUnavailable, isFalse);
      expect(result.totpCode, '123456');
      expect(result.appPin, '1234');
    });
  });
}
