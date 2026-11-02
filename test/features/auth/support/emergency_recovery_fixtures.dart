import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';

const recoveryFixtureUsername = 'public_fixture';
const recoveryFixtureStart = EmergencyRecoveryStartResult(
  recoverySessionId: 'fixture-session',
  otpUri:
      'otpauth://totp/Kerosene:public_fixture?secret=JBSWY3DPEHPK3PXP&issuer=Kerosene',
  passkeyChallenge:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  expiresInSeconds: 600,
  requiredRecoveryCodes: 3,
);
const recoveryFixtureCodes = [
  '01010101',
  '02020202',
  '03030303',
  '04040404',
  '05050505',
  '06060606',
  '07070707',
  '08080808',
  '09090909',
  '10101010',
];
const recoveryFixtureFinish = EmergencyRecoveryFinishResult(
  username: recoveryFixtureUsername,
  newBackupCodes: recoveryFixtureCodes,
);
