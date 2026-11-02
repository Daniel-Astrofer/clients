import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/domain/entities/account_security_change_factors.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';
import 'package:kerosene/features/security/application/security_change_authorizer.dart';
import 'package:kerosene/storybook/storybook_mocks.dart'
    show MockAuthController;

final _scopeProvider = NotifierProvider<_Scope, String?>(_Scope.new);

class _Scope extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change() => state = 'owner-b';
}

class _Key extends DeviceKeyService {
  bool enrolled = true;
  int signatures = 0;
  @override
  Future<bool> hasRegisteredDeviceKey(String username) async => enrolled;
  @override
  Future<Map<String, dynamic>> authenticate({
    required DeviceKeyChallenge challenge,
    required String username,
    bool requireStrictUserPresence = false,
  }) async {
    expect(username, 'alice');
    signatures++;
    return {
      'credentialId': 'PUBLIC-CREDENTIAL',
      'signature': 'PUBLIC-SIGNATURE'
    };
  }
}

class _Passkey extends PasskeyService {
  int commits = 0;
  @override
  Future<Map<String, dynamic>> authenticate(
          {required String challengeHex, required String username}) async =>
      {
        'signature': 'PUBLIC-SIGNATURE',
        'authData': 'PUBLIC-DATA',
        'clientDataJSON': 'PUBLIC-JSON',
        '_signatureCounter': 2,
        '_subject': 'alice',
      };
  @override
  Future<void> commitAuthenticationCounter(
      Map<String, dynamic> credential) async {
    commits++;
  }
}

class _Repository implements AuthRepository {
  int starts = 0;
  Completer<Either<Failure, Map<String, dynamic>>>? pending;
  @override
  Future<Either<Failure, Map<String, dynamic>>> deviceKeyLoginStart(
      String username) async {
    expect(username, 'alice');
    starts++;
    if (pending != null) return pending!.future;
    return const Right({
      'challengeId': 'PUBLIC-ID',
      'challenge': 'PUBLIC-CHALLENGE',
      'onionServiceId': 'fixture.onion'
    });
  }

  @override
  Future<Either<Failure, String>> passkeyLoginStart(String username) async {
    starts++;
    return const Right('PUBLIC-CHALLENGE');
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Key key;
  late _Passkey passkey;
  late _Repository repository;
  late SecurityChangeAuthorizer authorizer;
  setUp(() {
    key = _Key();
    passkey = _Passkey();
    repository = _Repository();
    container = ProviderContainer(overrides: [
      sessionStorageScopeProvider
          .overrideWith((ref) => ref.watch(_scopeProvider)),
      authRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => MockAuthController(
          initialOverride: AuthAuthenticated(User(
              id: 'fixture',
              username: 'alice',
              createdAt: DateTime.utc(2026))))),
      securityChangeAuthorizerProvider.overrideWith((ref) =>
          SecurityChangeAuthorizer(ref, deviceKey: key, passkey: passkey)),
    ]);
    authorizer = container.read(securityChangeAuthorizerProvider);
  });
  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  test('canonical proof uses the current username and preserves manual factors',
      () async {
    final factors = await authorizer.authorize(
        expectedScope: 'owner-a',
        requiresPasskey: true,
        manualFactors: const AccountSecurityChangeFactors(
            totpCode: '012345', confirmationPassphrase: ' Public Password '));
    expect(jsonDecode(factors.passkeyAssertionJson!)['type'], 'DEVICE_KEY');
    expect(factors.confirmationPassphrase, ' Public Password ');
    expect(factors.totpCode, '012345');
    expect(repository.starts, 1);
    expect(key.signatures, 1);
  });
  test('session change during challenge retrieval prevents signing', () async {
    repository.pending = Completer<Either<Failure, Map<String, dynamic>>>();
    final pending = authorizer.authorize(
        expectedScope: 'owner-a',
        requiresPasskey: true,
        manualFactors: const AccountSecurityChangeFactors());
    final assertion = expectLater(pending, throwsA(isA<ServerException>()));
    await Future<void>.delayed(Duration.zero);
    container.read(_scopeProvider.notifier).change();
    repository.pending!.complete(const Right(
        {'challengeId': 'PUBLIC-ID', 'challenge': 'PUBLIC-CHALLENGE'}));
    await assertion;
    expect(key.signatures, 0);
  });
  test('manual-factor modes do not create an unnecessary device challenge',
      () async {
    const original = AccountSecurityChangeFactors(
        totpCode: '012345', confirmationPassphrase: ' Public Password ');
    final result = await authorizer.authorize(
        expectedScope: 'owner-a',
        requiresPasskey: false,
        manualFactors: original);
    expect(result, same(original));
    expect(repository.starts, 0);
    expect(key.signatures, 0);
  });
  test('legacy counter is reserved before returning a submit-ready proof',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    key.enrolled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (call) async => call.method == 'getAvailableBiometrics'
                ? ['fingerprint']
                : true);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null));
    final result = await authorizer.authorize(
        expectedScope: 'owner-a',
        requiresPasskey: true,
        manualFactors: const AccountSecurityChangeFactors());
    expect(passkey.commits, 1);
    final wire = jsonDecode(result.passkeyAssertionJson!) as Map;
    expect(wire.containsKey('_signatureCounter'), isFalse);
    expect(wire.containsKey('_subject'), isFalse);
  });
}
