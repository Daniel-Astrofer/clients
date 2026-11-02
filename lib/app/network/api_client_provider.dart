import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/core/network/locale_headers_interceptor.dart';
import 'package:kerosene/core/providers/tor_providers.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import 'package:kerosene/features/auth/data/interceptors/token_interceptor.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'payment_submission_interceptor.dart';

// App-level composition: wires the core API client with auth-specific material.
//
// Do NOT watch locale/currency here — LocaleHeadersInterceptor reads prefs per
// request. Rebuilding the client mid-PIN would restart appPinStatusProvider and
// tear down the pad (double PIN / no time to type).
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.read(torApiUrlProvider);
  final client = ApiClient(baseUrl: baseUrl, ref: ref);
  ref.onDispose(() => client.dio.close(force: true));
  ref.listen(
      torApiUrlProvider, (_, next) => client.syncBaseUrlForResolvedRoute(next));
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  String? currentSubmissionScope() =>
      ref.mounted ? ref.read(sessionStorageScopeProvider) : null;

  client.addInterceptor(LocaleHeadersInterceptor(ref));
  client.addInterceptor(
    TokenInterceptor(localDataSource: localDataSource, apiClient: client),
  );
  client.addInterceptor(
      PaymentSubmissionAccountInterceptor(currentSubmissionScope));
  // Run after auth on requests, and after response decoding on responses.
  client.dio.interceptors.add(PaymentSubmissionInterceptor(
    store: ref.watch(paymentSubmissionStoreProvider),
    currentScope: currentSubmissionScope,
  ));

  return client;
});
