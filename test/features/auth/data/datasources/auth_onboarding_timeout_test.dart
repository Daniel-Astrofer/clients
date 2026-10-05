import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  for (final path in [
    AppConfig.authPasskeyOnboardingFinish,
    AppConfig.authPasskeyVerify,
    AppConfig.authDeviceKeyOnboardingFinish,
    AppConfig.authDeviceKeyVerify,
    AppConfig.authDeviceKeyRegisterFinish,
  ]) {
    test('retry policy does not replay one-time proof for $path', () {
      expect(ApiClient.shouldRetryRequest(method: 'POST', path: path), isFalse);
      expect(
          ApiClient.shouldRetryRequest(
              method: 'POST', path: 'http://127.0.0.1$path?sessionId=test'),
          isFalse);
    });
  }

  test(
      'finish waits for provisioning without changing request or status policy',
      () async {
    final client = _RecordingClient();
    final source = AuthRemoteDataSourceImpl(client);
    final credential = <String, dynamic>{'id': 'test-credential'};

    final result = await source.passkeyRegisterOnboardingFinish(
        'test-session', credential);

    expect(client.path, AppConfig.authPasskeyOnboardingFinish);
    expect(client.query, {'sessionId': 'test-session'});
    expect(client.body, same(credential));
    expect(client.options?.receiveTimeout, const Duration(seconds: 210));
    expect(client.options?.validateStatus, isNull);
    expect(client.calls, 1);
    expect(result.userId, '42');
  });

  test('start keeps default timeout', () async {
    final client = _RecordingClient();
    await AuthRemoteDataSourceImpl(client)
        .passkeyRegisterOnboardingStart(sessionId: 'test-session');

    expect(client.path, AppConfig.authPasskeyOnboardingStart);
    expect(client.options, isNull);
    expect(client.calls, 1);
  });

  test('passkey login allows repair of previously committed signup', () async {
    final client = _RecordingClient();
    await AuthRemoteDataSourceImpl(client).passkeyLoginFinish(
        'test-user', const {'credentialId': 'test-credential'});
    expect(client.path, AppConfig.authPasskeyVerify);
    expect(client.options?.receiveTimeout, const Duration(seconds: 210));
    expect(client.options?.validateStatus, isNull);
    expect(client.calls, 1);
  });

  test('device-key onboarding shares the provisioning budget', () async {
    final client = _RecordingClient();
    await AuthRemoteDataSourceImpl(client)
        .deviceKeyRegisterOnboardingFinish('test-session', const {});
    expect(client.path, AppConfig.authDeviceKeyOnboardingFinish);
    expect(client.options?.receiveTimeout, const Duration(seconds: 210));
    expect(client.options?.validateStatus, isNull);
    expect(client.calls, 1);
  });

  test('device-key login shares the wallet repair budget', () async {
    final client = _RecordingClient();
    await AuthRemoteDataSourceImpl(client).deviceKeyLoginFinish(const {});
    expect(client.path, AppConfig.authDeviceKeyVerify);
    expect(client.options?.receiveTimeout, const Duration(seconds: 210));
    expect(client.options?.validateStatus, isNull);
    expect(client.calls, 1);
  });

  test('finish preserves backend failure without replaying consumed challenge',
      () async {
    const failure =
        ServerException(message: 'Temporarily unavailable', statusCode: 503);
    final client = _RecordingClient(failure: failure);

    await expectLater(
      AuthRemoteDataSourceImpl(client)
          .passkeyRegisterOnboardingFinish('test-session', const {}),
      throwsA(same(failure)),
    );
    expect(client.calls, 1);
  });
}

class _RecordingClient implements ApiClient {
  _RecordingClient({this.failure});

  final AppException? failure;
  int calls = 0;
  String? path;
  Object? body;
  Map<String, dynamic>? query;
  Options? options;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    calls++;
    this.path = path;
    body = data;
    query = queryParameters;
    this.options = options;
    if (failure != null) throw failure!;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: '42 test.jwt.token',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
