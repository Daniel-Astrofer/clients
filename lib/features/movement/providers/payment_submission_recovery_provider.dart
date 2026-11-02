import 'dart:convert';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/logging/app_log.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show lastTransactionHistoryProvider;

final pendingPaymentSubmissionsProvider = FutureProvider.autoDispose
    .family<List<PaymentSubmission>, String>((ref, scope) async {
  final activeScope = ref.watch(sessionStorageScopeProvider);
  ref.watch(paymentSubmissionRevisionProvider);
  if (scope != activeScope) return [];
  final records = await ref.read(paymentSubmissionStoreProvider).load(scope);
  records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return records;
}, retry: (_, __) => null);

typedef SubmissionLookupKey = (String scope, String key, String? transactionId);

/// Always uses fresh server reads. A 202 is uncertainty, never permission to
/// create another payment. This provider has no submission/replay operation.
final paymentSubmissionLookupProvider = FutureProvider.autoDispose
    .family<Transaction?, SubmissionLookupKey>((ref, identity) async {
  final scope = ref.watch(sessionStorageScopeProvider);
  if (scope == null || scope != identity.$1) return null;
  final store = ref.read(paymentSubmissionStoreProvider);
  final records = await store.load(scope);
  final record = records.where((item) => item.key == identity.$2).firstOrNull;
  if (record == null ||
      !ref.mounted ||
      ref.read(sessionStorageScopeProvider) != scope) {
    return null;
  }
  final response = await ref.read(apiClientProvider).get(
        record.transactionId == null
            ? AppConfig.kfeSubmissionLookup
            : AppConfig.kfeTransaction(record.transactionId!),
        queryParameters: record.transactionId == null
            ? {'idempotencyKey': record.key}
            : null,
        options:
            CacheOptions(store: null, policy: CachePolicy.noCache).toOptions(),
      );
  if (!ref.mounted || ref.read(sessionStorageScopeProvider) != scope) {
    return null;
  }
  if (response.statusCode == 202) return null;
  final raw = response.data is String
      ? jsonDecode(response.data as String)
      : response.data;
  final payload = raw is Map && raw['data'] is Map ? raw['data'] : raw;
  if (response.statusCode != 200 ||
      payload is! Map ||
      payload['id'] is! String ||
      !PaymentSubmissionStore.validTransactionId(payload['id'] as String) ||
      DateTime.tryParse(
              '${payload['createdAt'] ?? payload['timestamp'] ?? ''}') ==
          null) {
    throw const ServerException(
        message: 'The recovered payment response is incomplete.',
        errorCode: 'ERR_PAYMENT_RECOVERY_RESPONSE');
  }
  final operation = Transaction.fromJson(Map<String, dynamic>.from(payload));
  if ((record.transactionId != null && record.transactionId != operation.id) ||
      (operation.sourceWalletId != null &&
          operation.sourceWalletId != record.walletId)) {
    throw const ServerException(
        message: 'The recovered payment identity does not match.',
        errorCode: 'ERR_PAYMENT_RECOVERY_RESPONSE');
  }
  try {
    await store.accepted(scope, record.key, operation.id);
  } catch (_) {
    appLog('Recovered payment is visible; its journal update failed.');
  }
  if (ref.mounted && ref.read(sessionStorageScopeProvider) == scope) {
    ref.read(lastTransactionHistoryProvider.notifier).upsertFront(operation);
  }
  return operation;
}, retry: (_, __) => null);
