import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Single-Flight coalescing engine to prevent redundant Tor requests.
///
/// If concurrent identical requests arrive within [coalesceWindow], only one
/// request touches the network. Other callers await the same completion.
class RequestCoalescer {
  final Duration coalesceWindow;
  final Map<String, _InFlightRequest> _inFlight = {};

  RequestCoalescer({
    this.coalesceWindow = const Duration(seconds: 2),
  });

  /// Computes a unique cache key based on method, path, query and payload.
  String computeKey({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    dynamic data,
  }) {
    final queryStr = queryParameters != null && queryParameters.isNotEmpty
        ? '?${queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    String dataHash = '';
    if (data != null) {
      if (data is String) {
        dataHash = sha256.convert(utf8.encode(data)).toString();
      } else if (data is List<int>) {
        dataHash = sha256.convert(data).toString();
      } else {
        try {
          dataHash = sha256.convert(utf8.encode(jsonEncode(data))).toString();
        } catch (_) {
          dataHash = data.hashCode.toString();
        }
      }
    }
    return '${method.toUpperCase()}:$path$queryStr:$dataHash';
  }

  /// Executes [execute] or returns an already running execution for the same key.
  Future<Response<T>> run<T>(
    String key,
    Future<Response<T>> Function() execute,
  ) async {
    final existing = _inFlight[key];
    final now = DateTime.now();

    if (existing != null &&
        now.difference(existing.timestamp) < coalesceWindow &&
        !existing.completer.isCompleted) {
      return (await existing.completer.future) as Response<T>;
    }

    final completer = Completer<Response<dynamic>>();
    _inFlight[key] = _InFlightRequest(
      completer: completer,
      timestamp: now,
    );

    try {
      final response = await execute();
      completer.complete(response);
      return response;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      // Keep in cache for the remainder of the coalesce window to serve rapid bursts
      Future.delayed(coalesceWindow, () {
        if (_inFlight[key]?.completer == completer) {
          _inFlight.remove(key);
        }
      });
    }
  }

  /// Cancels / clears in-flight state.
  void clear() {
    _inFlight.clear();
  }
}

class _InFlightRequest {
  final Completer<Response<dynamic>> completer;
  final DateTime timestamp;

  _InFlightRequest({
    required this.completer,
    required this.timestamp,
  });
}
