import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/device_credential_capabilities.dart';

void main() {
  group('DeviceCredentialEnrollPolicy (via probes)', () {
    test('tier A can enroll and is first-class for canonical Device Key', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'android',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
      );
      expect(caps.tier, DeviceCredentialTier.a);
      expect(caps.canEnrollDeviceCredential, isTrue);
      expect(caps.deviceKeyLoginPreferred, isTrue);
    });

    test('tier C Linux can enroll without biometrics (session gate)', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'linux',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
      );
      expect(caps.canEnrollDeviceCredential, isTrue);
      expect(caps.deviceKeyLoginPreferred, isFalse);
    });
  });
}
