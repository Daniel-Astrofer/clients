import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart'
    show SignupInitResult;
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';

class _Repository implements AuthRepository {
  Failure? failure;
  Failure? enrollmentFailure = const NetworkFailure();
  Failure? completionFailure = const NetworkFailure();
  Object? completionException;
  int finishes = 0;
  Completer<void>? completionDelay;
  bool authenticated = false;
  int invalidSessionsCleared = 0;
  @override
  Future<void> clearInvalidSession() async {
    invalidSessionsCleared++;
    authenticated = false;
  }

  Completer<Either<Failure, User>>? remoteUser;
  bool forceRemoteRead = false;
  int enrollmentStarts = 0;
  Object? enrollmentException;
  final List<String> enrollmentPaths = [];
  final List<String?> enrollmentUsernames = [];
  Completer<void>? enrollmentDelay;

  Future<Either<Failure, T>> _startEnrollment<T>(
      String sessionId, String? username, String path) async {
    expect(sessionId, 'signup-test');
    enrollmentStarts++;
    enrollmentPaths.add(path);
    enrollmentUsernames.add(username);
    if (enrollmentDelay != null) await enrollmentDelay!.future;
    if (enrollmentException != null) throw enrollmentException!;
    if (enrollmentFailure != null) return Left(enrollmentFailure!);
    return Right((path == 'device-key'
        ? const <String, dynamic>{
            'challengeId': 'PUBLIC-CHALLENGE',
            'challenge': 'PUBLIC-CHALLENGE',
            'onionServiceId': 'fixture.onion',
            'algorithm': 'Ed25519',
            'canonicalization': 'KEROSENE_JSON_V1'
          }
        : 'PUBLIC-CHALLENGE') as T);
  }

  @override
  Future<Either<Failure, String>> passkeyRegisterOnboardingStart(
          {required String sessionId, String? username}) =>
      _startEnrollment<String>(sessionId, username, 'passkey');
  @override
  Future<Either<Failure, Map<String, dynamic>>>
      deviceKeyRegisterOnboardingStart(
              {required String sessionId, String? username}) =>
          _startEnrollment<Map<String, dynamic>>(
              sessionId, username, 'device-key');
  Future<Either<Failure, LoginResult>> _finish(
      String sessionId, Map<String, dynamic> credential) async {
    expect(sessionId, 'signup-test');
    expect(credential, contains('publicKey'));
    finishes++;
    if (completionDelay != null) await completionDelay!.future;
    if (completionException != null) throw completionException!;
    return completionFailure != null
        ? Left(completionFailure!)
        : const Right(LoginResult());
  }

  @override
  Future<Either<Failure, LoginResult>> passkeyRegisterOnboardingFinish(
          String sessionId, Map<String, dynamic> credential) =>
      _finish(sessionId, credential);
  @override
  Future<Either<Failure, LoginResult>> deviceKeyRegisterOnboardingFinish(
          String sessionId, Map<String, dynamic> credential) =>
      _finish(sessionId, credential);
  int verifies = 0;
  bool optional = true;
  String returnedSession = 'signup-test';
  Completer<Either<Failure, String>>? delayed;
  @override
  Future<bool> isAuthenticated() async => authenticated;
  @override
  Future<Either<Failure, User>> getCurrentUser(
      {bool forceRemote = false}) async {
    forceRemoteRead = forceRemote;
    if (remoteUser != null) return remoteUser!.future;
    return const Left(AuthFailure(message: 'No session'));
  }

  @override
  Future<Either<Failure, SignupInitResult>> signup(
          {required String username,
          required String passphrase,
          String accountSecurity = 'STANDARD',
          int? shamirTotalShares,
          int? shamirThreshold,
          int? multisigThreshold}) async =>
      Right(SignupInitResult(
          sessionId: 'signup-test',
          totpSecret: 'PUBLIC-TOTP-FIXTURE',
          qrCodeUri: 'otpauth://fixture',
          backupCodes: const ['PUBLIC-BACKUP-FIXTURE'],
          totpOptional: optional));
  @override
  Future<Either<Failure, String>> verifyTotp(
      {required String sessionId, String? totpCode}) async {
    verifies++;
    expect(sessionId, 'signup-test');
    if (delayed != null) return delayed!.future;
    return failure != null ? Left(failure!) : Right(returnedSession);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _verify(AuthController controller) => controller.verifyTotp(
    username: 'alice',
    passphrase: 'PublicPass123!',
    totpSecret: 'PUBLIC-TOTP-FIXTURE',
    totpCode: '123456');

class _DeviceKey extends DeviceKeyService {
  @override
  Future<Map<String, dynamic>> register({
    required DeviceKeyChallenge challenge,
    required String username,
    required String sessionId,
    bool appPinConfigured = false,
    bool activateImmediately = true,
    bool requireStrictUserPresence = false,
  }) async {
    expect(username, 'alice');
    expect(sessionId, 'signup-test');
    return {'publicKey': 'PUBLIC-KEY-FIXTURE'};
  }
}

class _Passkey extends PasskeyService {
  @override
  Future<Map<String, dynamic>> register({
    required String challengeHex,
    required String username,
    bool confirmUnlinkDevice = false,
    bool appPinConfigured = false,
  }) async =>
      {'publicKey': 'PUBLIC-KEY-FIXTURE'};
  @override
  Future<void> markDeviceBound({required String username}) async {}
}

class _Controller extends AuthController {
  @override
  DeviceKeyService get deviceKeyService => _DeviceKey();
  @override
  PasskeyService get passkeyService => _Passkey();
  void resetFlow() => state = const AuthUnauthenticated();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late ProviderContainer container;
  late _Controller controller;
  setUp(() async {
    repository = _Repository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(_Controller.new)
    ]);
    controller = container.read(authControllerProvider.notifier) as _Controller;
    await Future<void>.delayed(Duration.zero);
    await controller.signup(username: 'alice', password: 'PublicPass123!');
  });
  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null);
  });
  for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
    group('enrollment on $platform', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = platform;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/local_auth'),
                (call) async => call.method == 'getAvailableBiometrics'
                    ? ['fingerprint']
                    : true);
      });
      for (final failure in [
        const NetworkFailure(),
        const ServerFailure(message: 'Unavailable', statusCode: 503),
        const ServerFailure(message: 'Timeout', statusCode: 408),
      ]) {
        test(
            'unknown completion blocks enrollment replay: ${failure.runtimeType}/${failure.statusCode}',
            () async {
          await _verify(controller);
          repository.enrollmentFailure = null;
          repository.completionFailure = failure;
          await controller.registerPasskeyOnboarding('signup-test');
          final unknown = container.read(authControllerProvider);
          expect(unknown, isA<AuthOnboardingOutcomeUnknown>());
          expect((unknown as AuthOnboardingOutcomeUnknown).username, 'alice');
          await controller.registerPasskeyOnboarding('signup-test');
          expect(repository.enrollmentStarts, 1);
          expect(repository.finishes, 1);
          controller.clearError();
          expect(container.read(authControllerProvider),
              isA<AuthUnauthenticated>());
        });
      }
      test('completion exception cannot restart enrollment', () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionException =
            StateError('PRIVATE-DIAGNOSTIC-FIXTURE');
        await controller.registerPasskeyOnboarding('signup-test');
        expect(container.read(authControllerProvider),
            isA<AuthOnboardingOutcomeUnknown>());
        await controller.registerPasskeyOnboarding('signup-test');
        expect(repository.finishes, 1);
      });
      test('late completion cannot replace a reset flow', () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionDelay = Completer<void>();
        final pending = controller.registerPasskeyOnboarding('signup-test');
        for (var i = 0; i < 10 && repository.finishes == 0; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(repository.finishes, 1);
        controller.resetFlow();
        repository.completionDelay!.complete();
        await pending;
        expect(
            container.read(authControllerProvider), isA<AuthUnauthenticated>());
      });
      test('a definite binding rejection preserves its server action',
          () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionFailure = const AuthFailure(
            message: 'Bound',
            errorCode: 'AUTH_024',
            statusCode: 409,
            data: {'action': 'CONFIRM_UNLINK_DEVICE'});
        await controller.registerPasskeyOnboarding('signup-test');
        final error = container.read(authControllerProvider) as AuthError;
        expect(error.errorCode, 'AUTH_024');
        expect(error.data, {'action': 'CONFIRM_UNLINK_DEVICE'});
        expect(error.resumeState, isA<AuthTotpVerified>());
      });
      test('an unconfirmed session after completion remains unknown', () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionFailure = null;
        await controller.registerPasskeyOnboarding('signup-test');
        expect(container.read(authControllerProvider),
            isA<AuthOnboardingOutcomeUnknown>());
      });
      test('remote session for a different user cannot confirm signup',
          () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionFailure = null;
        repository.authenticated = true;
        repository.remoteUser = Completer<Either<Failure, User>>()
          ..complete(Right(User(
              id: 'other', username: 'bob', createdAt: DateTime.utc(2026))));
        await controller.registerPasskeyOnboarding('signup-test');
        expect(repository.forceRemoteRead, isTrue);
        expect(repository.invalidSessionsCleared, 1);
        expect(repository.authenticated, isFalse);
        expect(container.read(authControllerProvider),
            isA<AuthOnboardingOutcomeUnknown>());
      });
      test('late remote session verification cannot authenticate a reset flow',
          () async {
        await _verify(controller);
        repository.enrollmentFailure = null;
        repository.completionFailure = null;
        repository.authenticated = true;
        repository.remoteUser = Completer<Either<Failure, User>>();
        final pending = controller.registerPasskeyOnboarding('signup-test');
        for (var i = 0; i < 10 && !repository.forceRemoteRead; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(repository.forceRemoteRead, isTrue);
        controller.resetFlow();
        repository.remoteUser!.complete(Right(User(
            id: 'fixture', username: 'alice', createdAt: DateTime.utc(2026))));
        await pending;
        expect(
            container.read(authControllerProvider), isA<AuthUnauthenticated>());
      });
      test('retry preserves the verified identity and does not authenticate',
          () async {
        await _verify(controller);
        await controller.registerPasskeyOnboarding('signup-test');
        final error = container.read(authControllerProvider) as AuthError;
        expect(error.resumeState, isA<AuthTotpVerified>());
        await controller.registerPasskeyOnboarding('signup-test',
            confirmUnlinkDevice: true);
        expect(repository.enrollmentStarts, 2);
        expect(repository.enrollmentUsernames, ['alice', 'alice']);
        final expectedPath =
            platform == TargetPlatform.android ? 'device-key' : 'passkey';
        expect(repository.enrollmentPaths, [expectedPath, expectedPath]);
        expect(container.read(authControllerProvider), isA<AuthError>());
        expect(repository.verifies, 1);
      });
      test(
          'local cancellation retains its meaning without exposing raw diagnostics',
          () async {
        await _verify(controller);
        repository.enrollmentException = const DeviceKeyException(
            'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED',
            'A confirmação do dispositivo foi cancelada.');
        await controller.registerPasskeyOnboarding('signup-test');
        final canceled = container.read(authControllerProvider) as AuthError;
        expect(canceled.errorCode, 'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED');
        expect(canceled.resumeState, isA<AuthTotpVerified>());
        repository.enrollmentException =
            StateError('PRIVATE-DIAGNOSTIC-FIXTURE');
        await controller.registerPasskeyOnboarding('signup-test');
        final unknown = container.read(authControllerProvider) as AuthError;
        expect(
            unknown.toString(), isNot(contains('PRIVATE-DIAGNOSTIC-FIXTURE')));
        expect(unknown.resumeState, isA<AuthTotpVerified>());
      });
      test('expired session cannot be reused for enrollment', () async {
        await _verify(controller);
        repository.enrollmentFailure = const AuthFailure(
            message: 'Expired', errorCode: 'AUTH_013', statusCode: 401);
        await controller.registerPasskeyOnboarding('signup-test');
        expect(
            (container.read(authControllerProvider) as AuthError).resumeState,
            isNull);
        await controller.registerPasskeyOnboarding('signup-test');
        expect(repository.enrollmentStarts, 1);
      });
      test('pending enrollment blocks duplicates and ignores a reset response',
          () async {
        await _verify(controller);
        repository.enrollmentDelay = Completer<void>();
        final pending = controller.registerPasskeyOnboarding('signup-test');
        // Let capability discovery and the start request reach their await.
        for (var i = 0; i < 10 && repository.enrollmentStarts == 0; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(repository.enrollmentStarts, 1);
        await controller.registerPasskeyOnboarding('signup-test');
        expect(repository.enrollmentStarts, 1);
        controller.resetFlow();
        repository.enrollmentDelay!.complete();
        await pending;
        expect(
            container.read(authControllerProvider), isA<AuthUnauthenticated>());
      });
    });
  }
  test('enrollment refuses an unverified or different signup session',
      () async {
    await controller.registerPasskeyOnboarding('signup-test');
    expect(repository.enrollmentStarts, 0);
    await controller.signup(username: 'alice', password: 'PublicPass123!');
    await _verify(controller);
    await controller.registerPasskeyOnboarding('different-session');
    expect(repository.enrollmentStarts, 0);
    expect(container.read(authControllerProvider), isA<AuthError>());
  });
  for (final failure in [
    const ServerFailure(
        message: 'Wrong code', errorCode: 'AUTH_008', statusCode: 401),
    const NetworkFailure(),
    const ServerFailure(message: 'Unavailable', statusCode: 503)
  ]) {
    test(
        'recoverable TOTP failure preserves session without authenticating: ${failure.errorCode ?? failure.runtimeType}',
        () async {
      repository.failure = failure;
      await _verify(controller);
      final state = container.read(authControllerProvider) as AuthError;
      expect(state.resumeState, isA<AuthRequiresTotpSetup>());
      expect(state.toString(), isNot(contains('PUBLIC-TOTP-FIXTURE')));
      expect(state.toString(), isNot(contains('PublicPass123!')));
      expect(state.toString(), isNot(contains('PUBLIC-BACKUP-FIXTURE')));
      repository.failure = null;
      await _verify(controller);
      expect(container.read(authControllerProvider), isA<AuthTotpVerified>());
      expect(repository.verifies, 2);
    });
  }
  test('expired session cannot retry verification or skip into enrollment',
      () async {
    repository.failure = const ServerFailure(
        message: 'Expired', errorCode: 'AUTH_011', statusCode: 408);
    await _verify(controller);
    expect((container.read(authControllerProvider) as AuthError).resumeState,
        isNull);
    await _verify(controller);
    await controller.skipTotpSetup();
    expect(container.read(authControllerProvider), isA<AuthError>());
    expect(repository.verifies, 1);
  });
  test('verification ignores a response after the flow has been reset',
      () async {
    repository.delayed = Completer<Either<Failure, String>>();
    final pending = _verify(controller);
    controller.resetFlow();
    repository.delayed!.complete(const Right('signup-test'));
    await pending;
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(repository.verifies, 1);
  });
  test('a mismatched server session is never marked verified', () async {
    repository.returnedSession = 'other-session';
    await _verify(controller);
    expect(container.read(authControllerProvider), isA<AuthError>());
    expect((container.read(authControllerProvider) as AuthError).errorCode,
        'ERR_SIGNUP_SESSION_MISMATCH');
  });
  test('required TOTP cannot be skipped', () async {
    repository.optional = false;
    await controller.signup(username: 'alice', password: 'PublicPass123!');
    await controller.skipTotpSetup();
    expect(container.read(authControllerProvider), isA<AuthError>());
    expect((container.read(authControllerProvider) as AuthError).resumeState,
        isA<AuthRequiresTotpSetup>());
    expect(repository.verifies, 0);
  });
  test('parallel verification taps make one server request', () async {
    repository.delayed = Completer<Either<Failure, String>>();
    final first = _verify(controller);
    await _verify(controller);
    expect(repository.verifies, 1);
    repository.delayed!.complete(const Right('signup-test'));
    await first;
  });
}
