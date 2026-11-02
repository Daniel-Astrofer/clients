import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/notifications/data/datasources/notification_remote_datasource.dart';

class _DeviceClient implements ApiClient {
  int? status = 204;
  Object? body = const [];
  int? readStatus = 200;
  String? path;
  @override
  Future<Response> get(String path,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers,
          Options? options}) async =>
      Response(
          requestOptions: RequestOptions(path: path),
          statusCode: readStatus,
          data: body);
  @override
  Future<Response> delete(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      Options? options}) async {
    this.path = path;
    return Response(
        requestOptions: RequestOptions(path: path), statusCode: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('an inbox requires a successful full list with stable record identities',
      () async {
    final client = _DeviceClient();
    for (final body in [
      {'unexpected': 'envelope'},
      [null],
      ['invalid-record'],
      [
        {'id': '1'},
        'invalid-record'
      ],
      [
        {'title': 'Missing identity'}
      ],
      [
        {'id': ' '}
      ],
    ]) {
      client.body = body;
      await expectLater(
          NotificationRemoteDataSourceImpl(client).getNotifications(),
          throwsA(isA<ServerException>()));
    }
    client.body = [
      {'id': '1', 'timestamp': null, 'body': 'Recorded notice'}
    ];
    final records =
        await NotificationRemoteDataSourceImpl(client).getNotifications();
    expect(records.single.timestamp, isNull);
    client.readStatus = 202;
    await expectLater(
        NotificationRemoteDataSourceImpl(client).getNotifications(),
        throwsA(isA<ServerException>()));
  });
  test('completed revocation requires the Core 204 acknowledgment', () async {
    final client = _DeviceClient();
    await NotificationRemoteDataSourceImpl(client).revokeDeviceToken('123');
    expect(client.path, '/notifications/device-tokens/123');
  });
  for (final status in [202, 200, null]) {
    test('status $status cannot announce a completed revocation', () async {
      final client = _DeviceClient()..status = status;
      await expectLater(
          NotificationRemoteDataSourceImpl(client).revokeDeviceToken('123'),
          throwsA(isA<ServerException>().having((e) => e.errorCode, 'code',
              'ERR_NOTIFICATION_REVOKE_UNCONFIRMED')));
    });
  }
  test('a blank registration never issues a delete', () async {
    final client = _DeviceClient();
    await expectLater(
        NotificationRemoteDataSourceImpl(client).revokeDeviceToken(' '),
        throwsA(isA<ServerException>()));
    expect(client.path, isNull);
  });
  test('the registration remains a single URL path segment', () async {
    final client = _DeviceClient();
    await NotificationRemoteDataSourceImpl(client)
        .revokeDeviceToken('123/other?all=true');
    expect(
        client.path, '/notifications/device-tokens/123%2Fother%3Fall%3Dtrue');
  });
  test('a recognized list preserves active and inactive registration data',
      () async {
    final client = _DeviceClient()
      ..body = [
        {'id': 123, 'active': true, 'deviceRef': 'public-ref'},
        {'id': '456', 'active': false},
      ];
    final rows =
        await NotificationRemoteDataSourceImpl(client).activeDeviceTokens();
    expect(rows.map((item) => item.id), ['123', '456']);
    expect(rows.first.deviceRef, 'public-ref');
    expect(rows.map((item) => item.active), [true, false]);
  });
  for (final body in [
    [null],
    [
      {'id': 123}
    ],
    [
      {'id': 123, 'active': 'true'}
    ],
    [
      {'id': '', 'active': true}
    ],
    [
      {'id': 1.5, 'active': true}
    ],
  ]) {
    test('malformed list $body cannot become an empty or inactive device list',
        () async {
      final client = _DeviceClient()..body = body;
      await expectLater(
          NotificationRemoteDataSourceImpl(client).activeDeviceTokens(),
          throwsA(isA<ServerException>().having((e) => e.errorCode, 'code',
              'ERR_NOTIFICATION_DEVICES_INVALID_RESPONSE')));
    });
  }
  test('a queued lookup cannot establish that no registrations exist',
      () async {
    final client = _DeviceClient()..readStatus = 202;
    await expectLater(
        NotificationRemoteDataSourceImpl(client).activeDeviceTokens(),
        throwsA(isA<ServerException>()));
  });
}
