import 'package:dio/dio.dart';

/// Request boundary implemented by the authenticated ApiClient.
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
