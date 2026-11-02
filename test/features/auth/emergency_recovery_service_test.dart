import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_transport.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/features/auth/data/emergency_recovery_service.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';
import 'support/emergency_recovery_fixtures.dart';

class _Transport implements ApiTransport {
  Object? failure;
  Object? finishFailure;
  final paths = <String>[];
  Object? response = {
    'username': recoveryFixtureUsername,
    'newBackupCodes': recoveryFixtureCodes
  };
  int status = 200;
  int posts = 0;
  String? path;
  Map? body;
  @override
  Future<Response> post(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      Options? options}) async {
    posts++;
    paths.add(path);
    this.path = path;
    body = data as Map;
    if (failure != null) throw failure!;
    if (path == AppConfig.authEmergencyRecoveryDeviceKeyChallenge) {
      return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'challengeId': 'fixture-key-challenge',
            'challenge': 'PUBLIC_FIXTURE_CHALLENGE',
            'expiresInSeconds': 90,
            'onionServiceId': 'fixture.onion',
            'algorithm': 'Ed25519',
            'canonicalization': 'KEROSENE_JSON_V1'
          });
    }
    if (finishFailure != null) throw finishFailure!;
    return Response(
        requestOptions: RequestOptions(path: path),
        data: response,
        statusCode: status);
  }

  @override
  Future<Response> get(String path,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers,
          Options? options}) async =>
      Response(
          requestOptions: RequestOptions(path: path),
          data: {'challenge': 'PUBLIC_FIXTURE_POW'},
          statusCode: 200);
}

class _DeviceEnrollment extends DeviceKeyService {
  String active = 'OLD_FIXTURE_KEY';
  int preparations = 0;
  int activations = 0;
  bool? immediate;
  bool? strict;
  bool activationFails = false;
  @override
  Future<Map<String, dynamic>> register(
      {required DeviceKeyChallenge challenge,
      required String username,
      required String sessionId,
      bool appPinConfigured = false,
      bool activateImmediately = true,
      bool requireStrictUserPresence = false}) async {
    preparations++;
    immediate = activateImmediately;
    strict = requireStrictUserPresence;
    return {
      'credentialId': 'PUBLIC_NEW_FIXTURE_KEY',
      'publicKey': 'PUBLIC_FIXTURE_KEY',
      'deviceInstallId': 'PUBLIC_FIXTURE_INSTALL',
      'signedPayload': 'PUBLIC_FIXTURE_PAYLOAD',
      'signature': 'PUBLIC_FIXTURE_SIGNATURE'
    };
  }

  @override
  Future<void> activateRegistration(
      {required String username, required String credentialId}) async {
    activations++;
    if (activationFails)
      throw const DeviceKeyException(
          'ERR_AUTH_DEVICE_KEY_STORAGE_UNAVAILABLE', 'Fixture storage failure');
    active = credentialId;
  }
}

class _Enrollment extends PasskeyService {
  Object? failure;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> register(
      {required String challengeHex,
      required String username,
      bool confirmUnlinkDevice = false,
      bool appPinConfigured = false}) async {
    calls++;
    if (failure != null) throw failure!;
    return {
      'publicKey': 'PUBLIC_FIXTURE_KEY',
      'signature': 'PUBLIC_FIXTURE_SIGNATURE'
    };
  }
}

void main() {
  late _Transport api;
  late _Enrollment enrollment;
  late RemoteEmergencyRecoveryService service;
  setUp(() {
    api = _Transport();
    enrollment = _Enrollment();
    service = RemoteEmergencyRecoveryService(api,
        passkeyService: enrollment, preferCanonical: () async => false);
  });
  Future<EmergencyRecoveryFinishResult> finish() => service.finish(
      username: recoveryFixtureUsername,
      started: recoveryFixtureStart,
      totpCode: '123456');

  test('valid completion sends exactly once and preserves the session identity',
      () async {
    final result = await finish();
    expect(result.isUsable, isTrue);
    expect(api.posts, 1);
    expect(api.path, AppConfig.authEmergencyRecoveryFinish);
    expect(
        api.body!['recoverySessionId'], recoveryFixtureStart.recoverySessionId);
    expect(api.body!['totpCode'], '123456');
    expect(api.body!['confirmUnlinkDevice'], isFalse);
  });
  test('local enrollment failure never transmits completion', () async {
    final failure = Exception('ERR_AUTH_PASSKEY_AUTH_CANCELLED');
    enrollment.failure = failure;
    await expectLater(finish(), throwsA(same(failure)));
    expect(api.posts, 0);
  });
  for (final status in [400, 401, 410, 429]) {
    test('explicit HTTP $status refusal is preserved for restart guidance',
        () async {
      final failure = ServerException(
          message: 'PUBLIC_REFUSAL',
          statusCode: status,
          errorCode: 'RECOVERY_REJECTED');
      api.failure = failure;
      await expectLater(finish(), throwsA(same(failure)));
      expect(api.posts, 1);
    });
  }
  for (final failure in <Object>[
    const ServerException(message: 'server unavailable', statusCode: 503),
    const NetworkException(),
    Exception('reply lost'),
  ]) {
    test(
        'lost or failed reply stays uncertain without repeating completion: ${failure.runtimeType}',
        () async {
      api.failure = failure;
      await expectLater(
          finish(), throwsA(isA<EmergencyRecoveryResultUnknownException>()));
      expect(api.posts, 1);
    });
  }
  for (final response in <Object?>[
    null,
    'invalid',
    {'username': recoveryFixtureUsername, 'newBackupCodes': []},
    {'username': 'another_fixture', 'newBackupCodes': recoveryFixtureCodes},
    {
      'username': recoveryFixtureUsername,
      'newBackupCodes': [...recoveryFixtureCodes.take(9), 12345678]
    },
  ]) {
    test(
        'malformed successful reply does not assert completed recovery: $response',
        () async {
      api.response = response;
      await expectLater(
          finish(), throwsA(isA<EmergencyRecoveryResultUnknownException>()));
      expect(api.posts, 1);
    });
  }
  test('an accepted HTTP 202 is not a completed recovery', () async {
    api.status = 202;
    await expectLater(
        finish(), throwsA(isA<EmergencyRecoveryResultUnknownException>()));
  });
  test('valid start preserves proofs and parses the server session', () async {
    api.status = 202;
    api.response = {
      'recoverySessionId': recoveryFixtureStart.recoverySessionId,
      'otpUri': recoveryFixtureStart.otpUri,
      'passkeyChallenge': recoveryFixtureStart.passkeyChallenge,
      'expiresInSeconds': 600,
      'requiredRecoveryCodes': 3
    };
    final result = await service.start(const EmergencyRecoveryStartDraft(
        username: recoveryFixtureUsername,
        newPassphrase: 'PUBLIC_FIXTURE_PASSPHRASE',
        recoveryCodes: ['01010101', '02020202', '03030303']));
    expect(result.isUsable, isTrue);
    expect(api.posts, 1);
    expect(api.path, AppConfig.authEmergencyRecoveryStart);
    expect(api.body!['challenge'], 'PUBLIC_FIXTURE_POW');
  });

  const canonicalStart = EmergencyRecoveryStartResult(
      recoverySessionId: 'fixture-session',
      otpUri: 'otpauth://totp/fixture?secret=JBSWY3DPEHPK3PXP',
      passkeyChallenge:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      expiresInSeconds: 600,
      requiredRecoveryCodes: 3,
      deviceKeyRecoverySupported: true);
  Future<EmergencyRecoveryFinishResult> canonicalFinish(_DeviceEnrollment key,
          {EmergencyRecoveryStartResult started = canonicalStart}) =>
      RemoteEmergencyRecoveryService(api,
              passkeyService: enrollment,
              deviceKeyService: key,
              preferCanonical: () async => true)
          .finish(
              username: recoveryFixtureUsername,
              started: started,
              totpCode: '123456');

  test(
      'canonical recovery prepares without activation then promotes the acknowledged key',
      () async {
    final key = _DeviceEnrollment();
    api.response = {
      'username': recoveryFixtureUsername,
      'newBackupCodes': recoveryFixtureCodes,
      'deviceKeyCredentialId': 'PUBLIC_NEW_FIXTURE_KEY'
    };
    final result = await canonicalFinish(key);
    expect(result.localDeviceKeyReady, isTrue);
    expect(api.paths, [
      AppConfig.authEmergencyRecoveryDeviceKeyChallenge,
      AppConfig.authEmergencyRecoveryFinish
    ]);
    expect(api.body!['deviceKeyRegistration']['confirmUnlinkDevice'], isFalse);
    expect(api.body!.containsKey('authData'), isFalse);
    expect(key.immediate, isFalse);
    expect(key.strict, isTrue);
    expect(key.active, 'PUBLIC_NEW_FIXTURE_KEY');
    expect(enrollment.calls, 0);
  });
  test(
      'a first-class device cannot fall back to legacy recovery on an old server',
      () async {
    final key = _DeviceEnrollment();
    await expectLater(
        canonicalFinish(key, started: recoveryFixtureStart),
        throwsA(isA<AppException>().having((error) => error.errorCode, 'code',
            'ERR_RECOVERY_DEVICE_KEY_UNSUPPORTED')));
    expect(api.posts, 0);
    expect(key.preparations, 0);
    expect(enrollment.calls, 0);
  });
  test(
      'preparation refusal preserves the session and never prepares local material',
      () async {
    final key = _DeviceEnrollment();
    api.failure = const ServerException(
        message: 'Proof rejected',
        statusCode: 401,
        errorCode: 'RECOVERY_REJECTED');
    await expectLater(
        canonicalFinish(key),
        throwsA(isA<EmergencyRecoveryPreparationException>()
            .having((error) => error.sessionClosed, 'closed', isFalse)));
    expect(key.preparations, 0);
    expect(api.posts, 1);
  });
  test('lost completion reply does not replace the existing active key',
      () async {
    final key = _DeviceEnrollment();
    api.finishFailure =
        const ServerException(message: 'Reply lost', statusCode: 503);
    await expectLater(canonicalFinish(key),
        throwsA(isA<EmergencyRecoveryResultUnknownException>()));
    expect(key.active, 'OLD_FIXTURE_KEY');
    expect(key.activations, 0);
    expect(api.posts, 2);
  });
  test('wrong credential acknowledgement never activates local material',
      () async {
    final key = _DeviceEnrollment();
    api.response = {
      'username': recoveryFixtureUsername,
      'newBackupCodes': recoveryFixtureCodes,
      'deviceKeyCredentialId': 'FOREIGN_FIXTURE_KEY'
    };
    await expectLater(canonicalFinish(key),
        throwsA(isA<EmergencyRecoveryResultUnknownException>()));
    expect(key.activations, 0);
  });
  test(
      'activation failure after server success retains the one-time code result',
      () async {
    final key = _DeviceEnrollment()..activationFails = true;
    api.response = {
      'username': recoveryFixtureUsername,
      'newBackupCodes': recoveryFixtureCodes,
      'deviceKeyCredentialId': 'PUBLIC_NEW_FIXTURE_KEY'
    };
    final result = await canonicalFinish(key);
    expect(result.localDeviceKeyReady, isFalse);
    expect(result.newBackupCodes, recoveryFixtureCodes);
    expect(key.active, 'OLD_FIXTURE_KEY');
  });
}
