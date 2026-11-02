import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/data/models/user_model.dart';
import 'package:kerosene/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';

const _finalSession = LoginResult(userId: '42', jwt: 'final.device.jwt');
const _primarySession = LoginResult(userId: '42', jwt: 'primary.password.jwt');
const _totpChallenge = LoginResult(jwt: 'device-preauth', requiresTotp: true);

class _Local implements AuthLocalDataSource {
  String? token;
  UserModel? user;
  int tokenWrites = 0;
  List<String>? backupCodes;
  int backupCodeWrites = 0;
  Completer<void>? tokenWriteStarted;
  Completer<void>? tokenWriteGate;
  @override
  Future<void> saveToken(String value) async {
    tokenWrites++;
    tokenWriteStarted?.complete();
    if (tokenWriteGate != null) await tokenWriteGate!.future;
    token = value;
  }

  @override
  Future<void> removeToken() async => token = null;
  @override
  Future<void> removeUser() async => user = null;
  @override
  Future<void> saveUser(UserModel value) async => user = value;
  @override
  Future<bool> isAuthenticated() async => token != null;
  @override
  Future<void> removeTotpSecret() async {}
  @override
  Future<void> removeBackupCodes() async => backupCodes = null;
  @override
  Future<void> saveBackupCodes(List<String> value) async {
    backupCodeWrites++;
    backupCodes = List.of(value);
  }

  @override
  Future<void> clearAll() async {
    token = null;
    user = null;
    backupCodes = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements AuthRemoteDataSource {
  LoginResult primary = _primarySession;
  LoginResult device = _finalSession;
  LoginResult totp = _finalSession;
  Object? deviceFailure;
  Completer<LoginResult>? pendingPrimary;
  Completer<LoginResult>? pendingDevice;
  Completer<LoginResult>? pendingTotp;
  Completer<SignupInitResult>? pendingSignup;
  Completer<void>? signupStarted;
  @override
  Future<LoginResult> login(
          {required String username, required String passphrase}) async =>
      pendingPrimary == null ? primary : await pendingPrimary!.future;
  @override
  Future<LoginResult> verifyLoginTotp(
          {required String username,
          required String totpCode,
          required String preAuthToken}) async =>
      pendingTotp == null ? totp : await pendingTotp!.future;
  @override
  Future<LoginResult> deviceKeyLoginFinish(
      Map<String, dynamic> credential) async {
    if (deviceFailure != null) throw deviceFailure!;
    return pendingDevice == null ? device : await pendingDevice!.future;
  }

  @override
  Future<LoginResult> passkeyLoginFinish(
          String username, Map<String, dynamic> credential) async =>
      pendingDevice == null ? device : await pendingDevice!.future;
  @override
  Future<void> logout() async {}
  @override
  Future<SignupInitResult> signup({
    required String username,
    required String passphrase,
    required String accountSecurity,
    int? shamirTotalShares,
    int? shamirThreshold,
    int? multisigThreshold,
  }) async {
    signupStarted?.complete();
    return pendingSignup!.future;
  }

  @override
  Future<LoginResult> deviceKeyRegisterOnboardingFinish(
          String sessionId, Map<String, dynamic> credential) async =>
      _finalSession;
  @override
  Future<LoginResult> passkeyRegisterOnboardingFinish(
          String sessionId, Map<String, dynamic> credential) async =>
      _finalSession;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Local local;
  late _Remote remote;
  late AuthRepositoryImpl repository;
  AuthRepositoryImpl restarted() =>
      AuthRepositoryImpl(remoteDataSource: remote, localDataSource: local);
  Future<void> verifyTotp(
          {String username = 'alice', String token = 'device-preauth'}) async =>
      repository.verifyLoginTotp(
          username: username,
          passphrase: '',
          totpCode: '123456',
          preAuthToken: token);
  setUp(() {
    local = _Local();
    remote = _Remote();
    repository = restarted();
  });

  test('remembered final sessions survive repository reconstruction', () async {
    local.token = 'remembered.device.jwt';
    expect(await restarted().isAuthenticated(), isTrue);
    expect(local.token, 'remembered.device.jwt');
    expect(local.tokenWrites, 0);
  });

  test('password JWT is never persisted, including cancellation and restart',
      () async {
    final result = await repository.login(username: 'alice', passphrase: 'pw');
    expect(result.isRight(), isTrue);
    expect(local.tokenWrites, 0);
    expect(local.token, isNull);
    expect(local.user, isNull);
    expect(await restarted().isAuthenticated(), isFalse);
    remote.deviceFailure = const AuthException(message: 'cancelled');
    expect(
        (await repository.deviceKeyLoginFinish({'username': 'alice'})).isLeft(),
        isTrue);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  test('old token is removed before password request can complete', () async {
    local.token = 'previous.device.jwt';
    remote.pendingPrimary = Completer<LoginResult>();
    final attempt = repository.login(username: 'alice', passphrase: 'pw');
    await Future<void>.delayed(Duration.zero);
    expect(await restarted().isAuthenticated(), isFalse);
    remote.pendingPrimary!.complete(_primarySession);
    await attempt;
    expect(local.tokenWrites, 0);
  });

  test('password and primary TOTP still cannot create a restorable session',
      () async {
    remote.primary =
        const LoginResult(jwt: 'password-preauth', requiresTotp: true);
    await repository.login(username: 'alice', passphrase: 'pw');
    await verifyTotp(token: 'password-preauth');
    expect(local.tokenWrites, 0);
    expect(local.user, isNull);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  for (final webauthn in [false, true]) {
    test(
        'verified ${webauthn ? 'WebAuthn' : 'device-key'} final session restores',
        () async {
      final result = webauthn
          ? await repository
              .passkeyLoginFinish(username: 'alice', credential: {})
          : await repository.deviceKeyLoginFinish({'username': 'alice'});
      expect(result.isRight(), isTrue);
      expect(local.token, _finalSession.jwt);
      expect(local.user?.id, '42');
      expect(await restarted().isAuthenticated(), isTrue);
    });

    test(
        'TOTP after verified ${webauthn ? 'WebAuthn' : 'device-key'} creates final session',
        () async {
      remote.device = _totpChallenge;
      if (webauthn) {
        await repository.passkeyLoginFinish(username: 'alice', credential: {});
      } else {
        await repository.deviceKeyLoginFinish({'username': 'alice'});
      }
      expect(local.token, isNull);
      await verifyTotp();
      expect(local.token, _finalSession.jwt);
      expect(local.user?.id, '42');
      expect(await restarted().isAuthenticated(), isTrue);
    });
  }

  for (final mismatch in ['username', 'token']) {
    test('TOTP continuation cannot reuse device proof with different $mismatch',
        () async {
      remote.device = _totpChallenge;
      await repository.deviceKeyLoginFinish({'username': 'alice'});
      await verifyTotp(
          username: mismatch == 'username' ? 'bob' : 'alice',
          token: mismatch == 'token' ? 'different-preauth' : 'device-preauth');
      expect(local.tokenWrites, 0);
      expect(await restarted().isAuthenticated(), isFalse);
    });
  }

  test('restart before device TOTP requires fresh device confirmation',
      () async {
    remote.device = _totpChallenge;
    await repository.deviceKeyLoginFinish({'username': 'alice'});
    repository = restarted();
    await verifyTotp();
    expect(local.tokenWrites, 0);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  test('starting another password login invalidates a pending device TOTP',
      () async {
    remote.device = _totpChallenge;
    await repository.deviceKeyLoginFinish({'username': 'alice'});
    await repository.login(username: 'alice', passphrase: 'pw');
    await verifyTotp();
    expect(local.tokenWrites, 0);
  });

  for (final webauthn in [false, true]) {
    test('logout rejects a late ${webauthn ? 'WebAuthn' : 'device-key'} finish',
        () async {
      remote.pendingDevice = Completer<LoginResult>();
      final attempt = webauthn
          ? repository.passkeyLoginFinish(username: 'alice', credential: {})
          : repository.deviceKeyLoginFinish({'username': 'alice'});
      await repository.logout();
      remote.pendingDevice!.complete(_finalSession);
      expect((await attempt).isLeft(), isTrue);
      expect(local.tokenWrites, 0);
      expect(await restarted().isAuthenticated(), isFalse);
    });
  }

  test('account switch rejects an older device finish', () async {
    remote.pendingDevice = Completer<LoginResult>();
    final attempt = repository.deviceKeyLoginFinish({'username': 'alice'});
    await repository.login(username: 'bob', passphrase: 'pw');
    remote.pendingDevice!.complete(_finalSession);
    expect((await attempt).isLeft(), isTrue);
    expect(local.tokenWrites, 0);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  test('logout during a token write clears that write before returning',
      () async {
    local.tokenWriteStarted = Completer<void>();
    local.tokenWriteGate = Completer<void>();
    final attempt = repository.deviceKeyLoginFinish({'username': 'alice'});
    await local.tokenWriteStarted!.future;
    final logout = repository.logout();
    local.tokenWriteGate!.complete();
    expect((await attempt).isLeft(), isTrue);
    expect((await logout).isRight(), isTrue);
    expect(local.token, isNull);
    expect(local.user, isNull);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  test('logout while device TOTP is pending cannot restore a session',
      () async {
    remote.device = _totpChallenge;
    await repository.deviceKeyLoginFinish({'username': 'alice'});
    remote.pendingTotp = Completer<LoginResult>();
    final attempt = repository.verifyLoginTotp(
        username: 'alice',
        passphrase: '',
        totpCode: '123456',
        preAuthToken: 'device-preauth');
    await repository.logout();
    remote.pendingTotp!.complete(_finalSession);
    expect((await attempt).isLeft(), isTrue);
    expect(local.tokenWrites, 0);
    expect(await restarted().isAuthenticated(), isFalse);
  });

  test('logout during TOTP token storage rejects the stale success', () async {
    remote.device = _totpChallenge;
    await repository.deviceKeyLoginFinish({'username': 'alice'});
    local.tokenWriteStarted = Completer<void>();
    local.tokenWriteGate = Completer<void>();
    final attempt = repository.verifyLoginTotp(
        username: 'alice',
        passphrase: '',
        totpCode: '123456',
        preAuthToken: 'device-preauth');
    await local.tokenWriteStarted!.future;
    final logout = repository.logout();
    local.tokenWriteGate!.complete();
    expect((await attempt).isLeft(), isTrue);
    expect((await logout).isRight(), isTrue);
    expect(local.token, isNull);
    expect(local.user, isNull);
  });

  for (final switchAccount in [false, true]) {
    test(
        'late signup cannot save recovery codes after ${switchAccount ? 'account switch' : 'logout'}',
        () async {
      remote.pendingSignup = Completer<SignupInitResult>();
      remote.signupStarted = Completer<void>();
      final attempt = repository.signup(username: 'alice', passphrase: 'pw');
      await remote.signupStarted!.future;
      if (switchAccount) {
        await repository.login(username: 'bob', passphrase: 'pw');
      } else {
        await repository.logout();
      }
      remote.pendingSignup!.complete(const SignupInitResult(
          sessionId: 'old-signup',
          totpSecret: 'fixture',
          qrCodeUri: 'fixture',
          backupCodes: ['PUBLIC_FIXTURE_RECOVERY_CODE']));
      expect((await attempt).isLeft(), isTrue);
      expect(local.backupCodeWrites, 0);
      expect(local.backupCodes, isNull);
      expect(local.token, isNull);
    });
  }

  for (final webauthn in [false, true]) {
    test(
        'verified ${webauthn ? 'WebAuthn' : 'device-key'} signup still persists final session',
        () async {
      final result = webauthn
          ? await repository.passkeyRegisterOnboardingFinish('signup', {})
          : await repository.deviceKeyRegisterOnboardingFinish('signup', {});
      expect(result.isRight(), isTrue);
      expect(local.token, _finalSession.jwt);
      expect(await restarted().isAuthenticated(), isTrue);
    });
  }
}
