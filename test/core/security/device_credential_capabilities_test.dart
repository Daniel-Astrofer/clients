import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/device_credential_capabilities.dart';

void main() {
  group('DeviceCredentialCapabilities.fromProbes', () {
    test('Android with biometrics is tier A and enrollable', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'android',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
      );

      expect(caps.tier, DeviceCredentialTier.a);
      expect(caps.canStoreDeviceKey, isTrue);
      expect(caps.canBiometricGate, isTrue);
      expect(caps.hardwareBackedLikely, isTrue);
      expect(caps.deviceKeyLoginPreferred, isTrue);
      expect(caps.requireAppPinWithDeviceKey, isFalse);
      expect(caps.canEnrollDeviceCredential, isTrue);
    });

    test('Linux without gate cannot enroll (third-class)', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'linux',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
      );

      expect(caps.tier, DeviceCredentialTier.c);
      expect(caps.deviceKeyLoginPreferred, isFalse);
      expect(caps.requireAppPinWithDeviceKey, isTrue);
      expect(caps.canEnrollDeviceCredential, isFalse);
      expect(caps.enrollBlockReasonCode, 'ERR_AUTH_DEVICE_KEY_APP_PIN_REQUIRED');
    });

    test('Linux with App PIN can enroll', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'linux',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
        appPinConfigured: true,
      );

      expect(caps.canEnrollDeviceCredential, isTrue);
      expect(caps.deviceKeyLoginPreferred, isFalse);
    });

    test('Windows without Hello prefers App PIN requirement', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'windows',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
      );

      expect(caps.tier, DeviceCredentialTier.b);
      expect(caps.requireAppPinWithDeviceKey, isTrue);
      expect(caps.deviceKeyLoginPreferred, isFalse);
      expect(caps.canEnrollDeviceCredential, isFalse);
    });

    test('Windows with Hello prefers device login', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'windows',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
      );

      expect(caps.deviceKeyLoginPreferred, isTrue);
      expect(caps.requireAppPinWithDeviceKey, isFalse);
      expect(caps.canEnrollDeviceCredential, isTrue);
    });

    test('Web is unsupported for storage/enroll', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'web',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
      );

      expect(caps.tier, DeviceCredentialTier.unsupported);
      expect(caps.canStoreDeviceKey, isFalse);
      expect(caps.canEnrollDeviceCredential, isFalse);
      expect(caps.deviceKeyLoginPreferred, isFalse);
    });

    test('deviceKeyLoginEnabled flag can disable preferred login on mobile', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'ios',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
        deviceKeyLoginEnabled: false,
      );

      expect(caps.deviceKeyLoginPreferred, isFalse);
      expect(caps.canEnrollDeviceCredential, isTrue);
    });
  });
}
