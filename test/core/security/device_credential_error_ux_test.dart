import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/device_credential_enroll_policy.dart';
import 'package:kerosene/core/security/device_credential_error_ux.dart';

void main() {
  group('DeviceCredentialErrorUx.classify', () {
    test('detects soft-lock AUTH_025', () {
      expect(
        DeviceCredentialErrorUx.classify('error AUTH_025 locked'),
        DeviceCredentialErrorKind.replayLocked,
      );
    });

    test('detects REPLAY AUTH_016', () {
      expect(
        DeviceCredentialErrorUx.classify('AUTH_016 counter'),
        DeviceCredentialErrorKind.replayConflict,
      );
    });

    test('detects reconfigure required', () {
      expect(
        DeviceCredentialErrorUx.classify(
          DeviceCredentialEnrollPolicy.reconfigureRequiredCode,
        ),
        DeviceCredentialErrorKind.reconfigureRequired,
      );
    });

    test('other for unrelated errors', () {
      expect(
        DeviceCredentialErrorUx.classify('LEDGER_004 insufficient'),
        DeviceCredentialErrorKind.other,
      );
    });
  });
}
