// ignore_for_file: depend_on_referenced_packages

import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';
import 'package:test/test.dart';
import 'support/emergency_recovery_fixtures.dart';

void main() {
  test('EmergencyRecoveryStartResult parses backend response', () {
    final result = EmergencyRecoveryStartResult.fromJson(const {
      'recoverySessionId': 'session-1',
      'otpUri': 'otpauth://totp/Kerosene:user?secret=JBSWY3DPEHPK3PXP',
      'passkeyChallenge':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'expiresInSeconds': 600,
      'requiredRecoveryCodes': 3,
    });

    expect(result.recoverySessionId, 'session-1');
    expect(result.isUsable, isTrue);
    expect(result.expiresInSeconds, 600);
    expect(result.requiredRecoveryCodes, 3);
  });

  test('EmergencyRecoveryFinishResult keeps new backup codes', () {
    final result = EmergencyRecoveryFinishResult.fromJson(const {
      'username': 'satoshi',
      'newBackupCodes': ['12345678', '87654321', '00001111'],
    });

    expect(result.username, 'satoshi');
    expect(result.newBackupCodes, ['12345678', '87654321', '00001111']);
    expect(result.isUsable, isFalse);
  });

  test('the full server code set is required for completion', () {
    expect(recoveryFixtureFinish.isUsable, isTrue);
    for (final codes in [
      <String>[],
      [...recoveryFixtureCodes.take(9)],
      [...recoveryFixtureCodes.take(9), recoveryFixtureCodes.first],
      [...recoveryFixtureCodes.take(9), 'not-a-code']
    ]) {
      expect(
          EmergencyRecoveryFinishResult(
                  username: recoveryFixtureUsername, newBackupCodes: codes)
              .isUsable,
          isFalse);
    }
  });

  test('invalid scalar and list entries are not coerced into recovery codes',
      () {
    final result = EmergencyRecoveryFinishResult.fromJson({
      'username': 42,
      'newBackupCodes': [...recoveryFixtureCodes.take(9), 12345678]
    });
    expect(result.isUsable, isFalse);
    expect(result.newBackupCodes.last, '');
  });

  test('start needs valid TOTP material, challenge, lifetime and code policy',
      () {
    final valid = {
      'recoverySessionId': recoveryFixtureStart.recoverySessionId,
      'otpUri': recoveryFixtureStart.otpUri,
      'passkeyChallenge': recoveryFixtureStart.passkeyChallenge,
      'expiresInSeconds': 600,
      'requiredRecoveryCodes': 3
    };
    expect(EmergencyRecoveryStartResult.fromJson(valid).isUsable, isTrue);
    for (final entry in <String, List<Object?>>{
      'expiresInSeconds': [0, -1, 1.5, double.nan],
      'requiredRecoveryCodes': [0, 2, 11],
      'otpUri': [
        'https://example.com',
        'otpauth://totp/fixture?secret=JBSWY3DPEHPK3PXP&secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/fixture',
        'otpauth://hotp/fixture?secret=JBSWY3DPEHPK3PXP'
      ],
      'passkeyChallenge': ['', 'invalid', 42],
      'recoverySessionId': ['', {}, 42],
    }.entries) {
      for (final value in entry.value) {
        expect(
            EmergencyRecoveryStartResult.fromJson({...valid, entry.key: value})
                .isUsable,
            isFalse,
            reason: entry.key);
      }
    }
  });
}
