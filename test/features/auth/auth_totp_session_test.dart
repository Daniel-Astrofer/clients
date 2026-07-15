import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/data/models/user_model.dart';
import 'package:kerosene/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';

void main() {
  test('TOTP datasource preserves user id with the final JWT', () async {
    final apiClient = _RecordingApiClient();
    final dataSource = AuthRemoteDataSourceImpl(apiClient);

    final result = await dataSource.verifyLoginTotp(
      username: 'alice',
      totpCode: '123456',
      preAuthToken: 'pre-auth-token',
    );

    expect(result.userId, '42');
    expect(result.jwt, 'jwt.token.value');
    expect(result.requiresTotp, isFalse);
    expect(apiClient.postedPath, AppConfig.authLoginVerify);
    expect(apiClient.postedData, {
      'username': 'alice',
      'totpCode': '123456',
      'preAuthToken': 'pre-auth-token',
    });
  });

  test('TOTP repository caches the authenticated user with the real id',
      () async {
    final localDataSource = _RecordingAuthLocalDataSource();
    final repository = AuthRepositoryImpl(
      remoteDataSource: _TotpAuthRemoteDataSource(
        const LoginResult(userId: '42', jwt: 'jwt.token.value'),
      ),
      localDataSource: localDataSource,
    );

    final result = await repository.verifyLoginTotp(
      username: 'alice',
      passphrase: 'unused',
      totpCode: '123456',
      preAuthToken: 'pre-auth-token',
    );

    expect(result.isRight(), isTrue);
    expect(localDataSource.savedToken, 'jwt.token.value');
    expect(localDataSource.savedUser?.id, '42');
    expect(localDataSource.savedUser?.username, 'alice');
  });

  test('TOTP repository rejects a final session without user id', () async {
    final localDataSource = _RecordingAuthLocalDataSource();
    final repository = AuthRepositoryImpl(
      remoteDataSource: _TotpAuthRemoteDataSource(
        const LoginResult(jwt: 'jwt.token.value'),
      ),
      localDataSource: localDataSource,
    );

    final result = await repository.verifyLoginTotp(
      username: 'alice',
      passphrase: 'unused',
      totpCode: '123456',
      preAuthToken: 'pre-auth-token',
    );

    expect(result.isLeft(), isTrue);
    expect(localDataSource.savedToken, isNull);
    expect(localDataSource.savedUser, isNull);
  });
}

class _RecordingApiClient implements ApiClient {
  String? postedPath;
  Object? postedData;

  @override
  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    postedPath = path;
    postedData = data;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: '42 jwt.token.value',
      statusCode: 202,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TotpAuthRemoteDataSource implements AuthRemoteDataSource {
  final LoginResult result;

  _TotpAuthRemoteDataSource(this.result);

  @override
  Future<LoginResult> verifyLoginTotp({
    required String username,
    required String totpCode,
    required String preAuthToken,
  }) async {
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAuthLocalDataSource implements AuthLocalDataSource {
  String? savedToken;
  UserModel? savedUser;

  @override
  Future<void> saveToken(String token) async {
    savedToken = token;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    savedUser = user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
