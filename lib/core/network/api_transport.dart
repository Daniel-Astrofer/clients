import 'package:dio/dio.dart';

/// Application-facing HTTP port. Features depend on this contract instead of
/// constructing Dio clients or reaching into transport configuration.
abstract interface class ApiTransport {
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  });

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  });
}
