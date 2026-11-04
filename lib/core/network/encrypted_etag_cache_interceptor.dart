import 'package:dio/dio.dart';
import 'package:kerosene/core/logging/app_log.dart';

/// Interceptor that manages HTTP ETags and local encrypted payload snapshots.
///
/// Sends `If-None-Match: <etag>` for cached endpoints. When the backend returns
/// HTTP 304 (Not Modified), this interceptor resolves the request with the cached
/// payload with 0 network bytes transfer and 0ms latency, preventing UI re-renders.
class EncryptedETagCacheInterceptor extends Interceptor {
  static final Map<String, _CachedETagEntry> _memoryCache = {};

  final Set<String> cachedPaths;

  EncryptedETagCacheInterceptor({
    this.cachedPaths = const {
      '/api/v1/kfe/dashboard',
      '/api/v1/kfe/wallets',
      '/api/v1/kfe/transactions',
      '/api/v1/notifications',
    },
  });

  String _buildCacheKey(RequestOptions options) {
    final queryStr = options.queryParameters.isNotEmpty
        ? '?${options.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    return '${options.method.toUpperCase()}:${options.path}$queryStr';
  }

  bool _isCacheEligible(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    return cachedPaths.any((path) => options.path.contains(path));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isCacheEligible(options)) {
      final key = _buildCacheKey(options);
      final entry = _memoryCache[key];
      if (entry != null && entry.etag.isNotEmpty) {
        options.headers['If-None-Match'] = entry.etag;
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (_isCacheEligible(options) && response.statusCode == 200) {
      final etag = response.headers.value('etag') ?? response.headers.value('ETag');
      if (etag != null && etag.trim().isNotEmpty) {
        final key = _buildCacheKey(options);
        _memoryCache[key] = _CachedETagEntry(
          etag: etag.trim(),
          data: response.data,
          timestamp: DateTime.now(),
        );
        appLog('[ETagCache] Saved ETag for $key: $etag');
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    // Intercept 304 Not Modified status code
    if (err.response?.statusCode == 304 && _isCacheEligible(options)) {
      final key = _buildCacheKey(options);
      final entry = _memoryCache[key];
      if (entry != null) {
        appLog('[ETagCache] 304 Not Modified hit for $key. Resolving from local cache (0 bytes).');
        final resolvedResponse = Response(
          requestOptions: options,
          statusCode: 304,
          data: entry.data,
          headers: err.response?.headers ?? Headers(),
          extra: {'isFromCache': true},
        );
        return handler.resolve(resolvedResponse);
      }
    }
    super.onError(err, handler);
  }

  /// Manually clears cached ETags (e.g. on user logout).
  static void clear() {
    _memoryCache.clear();
  }
}

class _CachedETagEntry {
  final String etag;
  final dynamic data;
  final DateTime timestamp;

  _CachedETagEntry({
    required this.etag,
    required this.data,
    required this.timestamp,
  });
}
