import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/network/api_client_provider.dart';
import 'package:kerosene/core/providers/tor_providers.dart';
import 'package:kerosene/features/security/data/datasources/security_remote_datasource.dart';
import 'package:kerosene/features/security/data/repositories/security_repository_impl.dart';
import 'package:kerosene/features/security/domain/repositories/security_repository.dart';

/// Stable for the lifetime of a given API base URL. Uses [Ref.read] so
/// incidental provider noise does not recreate the datasource mid-PIN.
final securityRemoteDataSourceProvider =
    Provider<SecurityRemoteDataSource>((ref) {
  // Only rebuild when the Tor/clearnet base URL actually changes.
  ref.watch(torApiUrlProvider);
  final apiClient = ref.read(apiClientProvider);
  return SecurityRemoteDataSourceImpl(apiClient);
});

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  final remoteDataSource = ref.watch(securityRemoteDataSourceProvider);
  return SecurityRepositoryImpl(remoteDataSource: remoteDataSource);
});
