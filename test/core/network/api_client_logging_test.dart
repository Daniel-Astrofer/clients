import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/core/network/api_client_route_policy.dart';

class _CredentialReply implements HttpClientAdapter {
  int status = 200;
  Object code = 'RECOVERY_REJECTED';
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
          jsonEncode({
            'success': status == 200,
            'errorCode': code,
            'data': {
              'newBackupCodes': ['PUBLIC_FIXTURE_BACKUP_CODE'],
              'otpUri': 'otpauth://totp/fixture?secret=PUBLIC_FIXTURE_TOTP',
              'token': 'PUBLIC_FIXTURE_RESPONSE_TOKEN'
            },
          }),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Linux logs diagnostics without request, header, query or recovery response secrets',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final lines = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = previousPrint);
    final adapter = _CredentialReply();
    final factory = Provider<ApiClient>((ref) {
      final client = ApiClient(
          baseUrl: 'https://public.example.test',
          ref: ref,
          routePolicy: ApiClientRoutePolicy.clearnet);
      client.dio.httpClientAdapter = adapter;
      ref.onDispose(() => client.dio.close(force: true));
      return client;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(factory);
    final options = Options(headers: {
      'Authorization': 'Bearer PUBLIC_FIXTURE_AUTH_TOKEN',
      'X-Private': 'PUBLIC_FIXTURE_HEADER'
    });
    await client.dio.post(
        '/auth/recovery/emergency/start?recoverySessionId=PUBLIC_FIXTURE_QUERY',
        data: {
          'newPassphrase': 'PUBLIC_FIXTURE_PASSWORD',
          'recoveryCodes': ['PUBLIC_FIXTURE_RECOVERY_CODE']
        },
        options: options);
    adapter.status = 401;
    await expectLater(
        client.dio.post('/auth/recovery/emergency/finish', options: options),
        throwsA(isA<DioException>()));
    adapter.code = {'private': 'PUBLIC_FIXTURE_MALFORMED_CODE'};
    await expectLater(
        client.dio.post('/auth/recovery/emergency/finish', options: options),
        throwsA(isA<DioException>()));
    expect(lines.join('\n'),
        contains('[POST] public.example.test/auth/recovery/emergency/start'));
    expect(lines.join('\n'), contains('(RECOVERY_REJECTED)'));
    expect(lines.join('\n'), isNot(contains('PUBLIC_FIXTURE_')));
    expect(lines.join('\n'), isNot(contains('otpauth://')));
  });
}
