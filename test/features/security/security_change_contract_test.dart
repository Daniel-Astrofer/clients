import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/data/interceptors/token_interceptor.dart';
import 'package:kerosene/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kerosene/features/auth/domain/entities/account_security_change_factors.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';

const _factors = AccountSecurityChangeFactors(
    totpCode: '012345',
    passkeyAssertionJson: 'PUBLIC-PROOF',
    confirmationPassphrase: ' Public Password123! ');

class _Client implements ApiClient {
  Object? body;
  String? path;
  @override
  Future<Response> post(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      Options? options}) async {
    this.path = path;
    body = data;
    return Response(requestOptions: RequestOptions(path: path), data: {
      'data': {
        'enabled': true,
        'remainingCodes': 10,
        'newlyGeneratedCodes': ['PUBLIC-CODE']
      }
    });
  }

  @override
  Future<Response> delete(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      Options? options}) async {
    this.path = path;
    body = data;
    return Response(
        requestOptions: RequestOptions(path: path), data: {'data': 'OK'});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Local implements AuthLocalDataSource {
  final List<String> events;
  bool failClear = false;
  _Local(this.events);
  @override
  Future<void> removeBackupCodes() async {
    events.add('clear');
    if (failClear) throw const CacheException(message: 'fixture');
  }

  @override
  Future<void> saveBackupCodes(List<String> codes) async => events.add('save');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Remote implements AuthRemoteDataSource {
  final List<String> events;
  AccountSecurityChangeFactors? factors;
  _Remote(this.events);
  @override
  Future<BackupCodesStatusResult> regenerateBackupCodes(
      {AccountSecurityChangeFactors factors =
          const AccountSecurityChangeFactors()}) async {
    this.factors = factors;
    events.add('post');
    return const BackupCodesStatusResult(
        enabled: true,
        remainingCodes: 10,
        newlyGeneratedCodes: ['PUBLIC-CODE']);
  }

  @override
  Future<BackupCodesStatusResult> verifyTotpSetup(
      {required String totpCode}) async {
    events.add('verify');
    return const BackupCodesStatusResult(
        enabled: true,
        remainingCodes: 10,
        newlyGeneratedCodes: ['PUBLIC-CODE']);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('security POST and DELETE carry factors with unchanged password spaces',
      () async {
    final client = _Client();
    final source = AuthRemoteDataSourceImpl(client);
    await source.regenerateBackupCodes(factors: _factors);
    expect(client.path, AppConfig.authBackupCodesRegenerate);
    expect(client.body, _factors.toJson());
    await source.disableTotp(factors: _factors);
    expect(client.path, AppConfig.authTotpDisable);
    expect(client.body, {
      'totpCode': '012345',
      'passkeyAssertionJson': 'PUBLIC-PROOF',
      'confirmationPassphrase': ' Public Password123! '
    });
  });
  test('security mutations never retry automatically; status reads may retry',
      () {
    for (final path in [
      AppConfig.authBackupCodesRegenerate,
      AppConfig.authTotpSetup,
      AppConfig.authTotpVerify,
      AppConfig.authTotpDisable
    ]) {
      expect(
          ApiClient.shouldRetryRequest(
              method: path == AppConfig.authTotpDisable ? 'DELETE' : 'POST',
              path: path),
          isFalse);
      expect(ApiClient.shouldRetryRequest(method: 'GET', path: path), isTrue);
    }
  });
  test('factor rejection keeps the session; explicit expiry still clears it',
      () {
    for (final path in [
      AppConfig.authBackupCodesRegenerate,
      AppConfig.authTotpVerify,
      AppConfig.authTotpDisable
    ]) {
      for (final code in ['AUTH_008', 'AUTH_009', 'AUTH_023']) {
        expect(
            TokenInterceptor.shouldInvalidateSessionForError(
                statusCode: 401,
                path: path,
                errorCode: code,
                responseDataText: 'Invalid factor',
                requestHadAuthorizationHeader: true),
            isFalse);
      }
      expect(
          TokenInterceptor.shouldInvalidateSessionForError(
              statusCode: 401,
              path: path,
              errorCode: 'AUTH_013',
              responseDataText: 'Session expired',
              requestHadAuthorizationHeader: true),
          isTrue);
    }
  });
  test('one-time codes preserve leading zeroes in a valid nested status', () {
    final status = BackupCodesStatusResult.fromJson({
      'data': {
        'enabled': true,
        'remainingCodes': 1,
        'newlyGeneratedCodes': ['00001234']
      }
    });
    expect(status.remainingCodes, 1);
    expect(status.newlyGeneratedCodes, ['00001234']);
  });
  for (final payload in [
    <String, dynamic>{},
    {'enabled': true},
    {'enabled': true, 'remainingCodes': -1},
    {'enabled': true, 'remainingCodes': 1.5},
    {
      'enabled': true,
      'remainingCodes': 1,
      'newlyGeneratedCodes': [1234]
    }
  ]) {
    test('malformed status cannot become inactive or zero: $payload', () {
      expect(() => BackupCodesStatusResult.fromJson(payload),
          throwsA(isA<ServerException>()));
    });
  }
  for (final verify in [false, true]) {
    test(
        'security codes stay in returned memory after legacy cache cleanup: verify=$verify',
        () async {
      final events = <String>[];
      final remote = _Remote(events);
      final repo = AuthRepositoryImpl(
          localDataSource: _Local(events), remoteDataSource: remote);
      final result = verify
          ? await repo.verifyTotpSetup(totpCode: '012345')
          : await repo.regenerateBackupCodes(factors: _factors);
      expect(result.isRight(), isTrue);
      expect(events, ['clear', verify ? 'verify' : 'post']);
      if (!verify) expect(remote.factors, same(_factors));
    });
  }
  test(
      'a failed cache cleanup stops submission rather than hiding a storage error',
      () async {
    final events = <String>[];
    final local = _Local(events)..failClear = true;
    final repo = AuthRepositoryImpl(
        localDataSource: local, remoteDataSource: _Remote(events));
    expect(
        (await repo.regenerateBackupCodes(factors: _factors)).isLeft(), isTrue);
    expect(events, ['clear']);
  });
  test(
      'account changes derive required factors without altering cold/payment profiles',
      () {
    const standard = AccountSecurityProfile(
        mode: AccountSecurityMode.standard, requiredFactors: ['TOTP']);
    expect(standard.requiresPasskey, isFalse);
    expect(standard.forAccountSecurityChange().requiresPasskey, isTrue);
    const shamir = AccountSecurityProfile(
        mode: AccountSecurityMode.shamir, passkeyEnabledForTransactions: true);
    final change = shamir.forAccountSecurityChange();
    expect(change.requiresTotp, isTrue);
    expect(change.requiresShamirShares, isTrue);
    expect(change.requiresPasskey, isFalse);
    const multisig = AccountSecurityProfile(
        mode: AccountSecurityMode.multisig2fa, multisigThreshold: 3);
    final multi = multisig.forAccountSecurityChange();
    expect(multi.requiresPassphrase, isTrue);
    expect(multi.requiresTotp, isTrue);
    expect(multi.requiresPasskey, isTrue);
  });
}
