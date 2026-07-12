import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  test('remote logout posts to the authenticated logout endpoint', () async {
    final apiClient = _RecordingApiClient();
    final dataSource = AuthRemoteDataSourceImpl(apiClient);

    await dataSource.logout();

    expect(apiClient.postedPath, AppConfig.authLogout);
    expect(apiClient.postedHeaders, isNull);
  });

  test('logout clears the local session when remote revocation fails',
      () async {
    final events = <String>[];
    final repository = AuthRepositoryImpl(
      remoteDataSource: _FailingLogoutRemoteDataSource(events),
      localDataSource: _RecordingLogoutLocalDataSource(events),
    );

    final result = await repository.logout();

    expect(result.isRight(), isTrue);
    expect(events, ['remoteLogout', 'clearAll']);
  });
}

class _RecordingApiClient implements ApiClient {
  String? postedPath;
  Map<String, String>? postedHeaders;

  @override
  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    postedPath = path;
    postedHeaders = headers;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingLogoutRemoteDataSource implements AuthRemoteDataSource {
  final List<String> events;

  _FailingLogoutRemoteDataSource(this.events);

  @override
  Future<void> logout() async {
    events.add('remoteLogout');
    throw StateError('backend unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingLogoutLocalDataSource implements AuthLocalDataSource {
  final List<String> events;

  _RecordingLogoutLocalDataSource(this.events);

  @override
  Future<void> clearAll() async {
    events.add('clearAll');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
