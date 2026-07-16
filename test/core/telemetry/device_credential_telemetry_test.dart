import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/device_credential_capabilities.dart';
import 'package:kerosene/core/telemetry/device_credential_telemetry.dart';

void main() {
  group('DeviceCredentialTelemetry.estimateHardwareBacked', () {
    test('tier A with hardwareBackedLikely → likely', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'android',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
      );
      expect(
        DeviceCredentialTelemetry.estimateHardwareBacked(caps),
        HardwareBackedStatus.likely,
      );
    });

    test('tier C Linux → unlikely', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'linux',
        canCheckBiometrics: false,
        isDeviceSupported: false,
        biometricsEnrolled: false,
        appPinConfigured: true,
      );
      expect(
        DeviceCredentialTelemetry.estimateHardwareBacked(caps),
        HardwareBackedStatus.unlikely,
      );
    });

    test('tier B Windows → unknown', () {
      final caps = DeviceCredentialCapabilitiesResolver.fromProbes(
        platformId: 'windows',
        canCheckBiometrics: true,
        isDeviceSupported: true,
        biometricsEnrolled: true,
      );
      expect(
        DeviceCredentialTelemetry.estimateHardwareBacked(caps),
        HardwareBackedStatus.unknown,
      );
    });
  });
}
