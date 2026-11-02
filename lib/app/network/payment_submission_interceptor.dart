import 'package:dio/dio.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/logging/app_log.dart';

bool _isFinancialSubmission(RequestOptions request) =>
    request.method.toUpperCase() == 'POST' &&
    request.uri.path
        .replaceFirst(RegExp(r'/$'), '')
        .endsWith('/kfe/transactions');

/// Binds the account before asynchronous token attachment. The final journal
/// interceptor verifies the same account immediately before transport.
class PaymentSubmissionAccountInterceptor extends Interceptor {
  PaymentSubmissionAccountInterceptor(this.currentScope);
  final String? Function() currentScope;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isFinancialSubmission(options)) {
      handler.next(options);
      return;
    }
    final scope = currentScope();
    final expected = options.extra[PaymentSubmissionInterceptor._scopeExtra];
    if (scope == null || (expected != null && expected != scope)) {
      handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: PaymentRecoveryException(
              message: 'The payment account changed.',
              errorCode: 'ERR_PAYMENT_RECOVERY_ACCOUNT_CHANGED',
              outcomeUncertain:
                  options.extra[PaymentSubmissionInterceptor._keyExtra] !=
                      null)));
      return;
    }
    options.extra[PaymentSubmissionInterceptor._scopeExtra] = scope;
    handler.next(options);
  }
}

/// Journal all authenticated financial submissions, including compatibility
/// adapters. Reads and account checks finish before Dio can transmit the body.
class PaymentSubmissionInterceptor extends Interceptor {
  PaymentSubmissionInterceptor(
      {required this.store, required this.currentScope});
  final PaymentSubmissionStore store;
  final String? Function() currentScope;
  static const _scopeExtra = 'kerosene.submissionScope';
  static const _keyExtra = 'kerosene.submissionKey';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isFinancialSubmission(options)) {
      handler.next(options);
      return;
    }
    try {
      final scope = currentScope();
      if (scope == null ||
          (options.extra[_scopeExtra] != null &&
              options.extra[_scopeExtra] != scope)) {
        throw const PaymentRecoveryException(
            message: 'The payment account changed.',
            errorCode: 'ERR_PAYMENT_RECOVERY_ACCOUNT_CHANGED');
      }
      if (options.data is! Map) {
        throw const FormatException('Financial request must be an object.');
      }
      final body = Map<String, dynamic>.from(options.data as Map);
      final record = await store.begin(scope, body);
      if (currentScope() != scope) {
        throw const PaymentRecoveryException(
            message: 'The payment account changed.',
            errorCode: 'ERR_PAYMENT_RECOVERY_ACCOUNT_CHANGED');
      }
      body['idempotencyKey'] = record.key;
      options.data = body;
      options.extra[_scopeExtra] = scope;
      options.extra[_keyExtra] = record.key;
      handler.next(options);
    } catch (error) {
      handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: error is AppException
              ? error
              : const PaymentRecoveryException(
                  message: 'Payment recovery could not be stored.',
                  errorCode: 'ERR_PAYMENT_RECOVERY_STORAGE')));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final scope = response.requestOptions.extra[_scopeExtra];
    final key = response.requestOptions.extra[_keyExtra];
    if (scope is String &&
        key is String &&
        response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      final root = response.data;
      final payload =
          root is Map && root['data'] is Map ? root['data'] as Map : root;
      final id =
          payload is Map ? payload['id'] ?? payload['transactionId'] : null;
      if (id is String && PaymentSubmissionStore.validTransactionId(id)) {
        try {
          await store.accepted(scope, key, id);
        } catch (_) {
          // The pre-request record remains sufficient for server recovery.
          // Never report a committed payment as failed due to local bookkeeping.
          appLog(
              'Payment submission accepted; its recovery journal update failed.');
        }
      }
      if (currentScope() != scope) {
        handler.reject(DioException(
            requestOptions: response.requestOptions,
            type: DioExceptionType.cancel,
            error: const PaymentRecoveryException(
                message: 'The payment account changed.',
                errorCode: 'ERR_PAYMENT_RECOVERY_ACCOUNT_CHANGED',
                outcomeUncertain: true)));
        return;
      }
    }
    handler.next(response);
  }
}
