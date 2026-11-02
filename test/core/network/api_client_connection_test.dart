import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/app/network/payment_submission_interceptor.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/core/network/api_client_route_policy.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/tor_providers.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart'
    show authApiClientProvider;
import '../security/payment_submission_store_test.dart'
    show MemorySubmissionStorage, payment;

class _EchoAdapter implements HttpClientAdapter {
  final uris = <Uri>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    uris.add(options.uri);
    return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {'route': options.uri.host}
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'explicit direct requests preserve their host and do not require Tor bootstrap',
      () async {
    final adapter = _EchoAdapter();
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
    client.syncBaseUrlForResolvedRoute('http://127.0.0.1:43123');
    final response = await client.get('/ping');
    expect(adapter.uris.single.host, 'public.example.test');
    expect(response.data['route'], 'public.example.test');
  });

  test('onion endpoints cannot be transmitted through an explicit direct route',
      () async {
    final adapter = _EchoAdapter();
    final factory = Provider<ApiClient>((ref) {
      final client = ApiClient(
          baseUrl: 'http://privateexample.onion',
          ref: ref,
          routePolicy: ApiClientRoutePolicy.clearnet);
      client.dio.httpClientAdapter = adapter;
      ref.onDispose(() => client.dio.close(force: true));
      return client;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(container.read(factory).get('/kfe/transactions'),
        throwsA(isA<NetworkException>()));
    expect(adapter.uris, isEmpty);
  });

  test('local submission guards retain their typed cause through ApiClient',
      () async {
    final adapter = _EchoAdapter();
    final factory = Provider<ApiClient>((ref) {
      final client = ApiClient(
          baseUrl: 'https://example.test',
          ref: ref,
          routePolicy: ApiClientRoutePolicy.clearnet);
      client.dio.httpClientAdapter = adapter;
      client.dio.interceptors.add(PaymentSubmissionInterceptor(
          store: PaymentSubmissionStore(
              MemorySubmissionStorage()..failWrite = true),
          currentScope: () => 'user_42'));
      ref.onDispose(() => client.dio.close(force: true));
      return client;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
        container
            .read(factory)
            .post('/kfe/transactions', data: payment('original')),
        throwsA(isA<PaymentRecoveryException>().having(
            (error) => error.outcomeUncertain, 'not transmitted', false)));
    expect(adapter.uris, isEmpty);
  });

  test(
      'relay changes keep the app and auth clients stable instead of rebuilding PIN dependencies',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final app = container.read(apiClientProvider);
    final auth = container.read(authApiClientProvider);
    container
        .read(torApiUrlProvider.notifier)
        .updateUrl('http://127.0.0.1:43123');
    expect(identical(container.read(apiClientProvider), app), isTrue);
    expect(identical(container.read(authApiClientProvider), auth), isTrue);
    expect(app.dio.options.baseUrl, 'http://127.0.0.1:43123');
    expect(auth.dio.options.baseUrl, 'http://127.0.0.1:43123');
  });
}
