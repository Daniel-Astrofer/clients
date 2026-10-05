import 'dart:convert';

import 'package:dio/dio.dart' show Options;
import 'package:kerosene/core/telemetry/ledger_telemetry.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';

abstract class LedgerRemoteDataSource {
  /// Retrieves all ledger accounts associated with the user's wallets.
  Future<List<dynamic>> getAllLedgers();

  /// Retrieves a specific ledger account.
  Future<Map<String, dynamic>> findLedger({required String walletName});

  /// Gets the current balance of a specific wallet.
  Future<double> getBalance({required String walletName});

  /// Retrieves paginated transaction history.
  ///
  /// [since] — when set, only rows with server `updatedAt` after this instant
  /// (incremental sync). Null = full page window.
  Future<List<dynamic>> getHistory({
    int page = 0,
    int size = 50,
    DateTime? since,
  });

  /// Single transaction by KFE UUID (deep-link / notification resolve).
  Future<Map<String, dynamic>?> getTransactionById(String transactionId);

  /// Processes an internal funds transfer between users.
  Future<Map<String, dynamic>> sendInternalTransaction({
    required String senderWalletName,
    required String receiverWalletName,
    required double amount,
    required String idempotencyKey,
    required int requestTimestamp,
  });
}

class LedgerRemoteDataSourceImpl implements LedgerRemoteDataSource {
  final ApiClient apiClient;

  LedgerRemoteDataSourceImpl(this.apiClient);

  Map<String, dynamic> _parseMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List<dynamic> _parseList(dynamic data) {
    if (data is List) return data;
    return const [];
  }

  List<dynamic> _parseApiList(dynamic data) {
    if (data is List) {
      return data;
    }
    final map = _parseMap(data);
    final unwrapped = map['data'] ?? map['result'] ?? map['items'];
    if (unwrapped is List) {
      return unwrapped;
    }
    if (unwrapped is Map) {
      final content = unwrapped['content'] ?? unwrapped['items'];
      if (content is List) {
        return content;
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> _getDashboard() async {
    final response = await apiClient.get(AppConfig.kfeDashboard);
    return _parseMap(response.data);
  }

  List<Map<String, dynamic>> _dashboardWallets(Map<String, dynamic> dashboard) {
    return _parseList(dashboard['wallets'])
        .whereType<Map>()
        .map(_parseMap)
        .toList();
  }

  Map<String, dynamic> _walletLedgerPayload(Map<String, dynamic> wallet) {
    final spendable = wallet['spendable'] != false;
    final kind = wallet['kind']?.toString().toUpperCase() ?? '';
    final available = wallet['availableSats'];
    final observed = wallet['observedSats'];
    // Primary display: cold/watch-only → observed; else available (LocalLedgerSync §4.3).
    final primarySats = (!spendable || kind == 'WATCH_ONLY')
        ? (observed ?? available)
        : (available ?? observed);
    return {
      'id': wallet['walletId'] ?? wallet['id'],
      'walletName': wallet['label'] ?? wallet['walletName'] ?? wallet['name'],
      'balance': _satsToBtc(primarySats),
      'availableSats': available,
      'observedSats': observed,
      'status': wallet['status'],
      'kind': wallet['kind'],
      'spendable': spendable,
      'walletMode': wallet['walletMode'],
      'walletTypeDescription': wallet['walletTypeDescription'],
    };
  }

  List<Map<String, dynamic>> _dashboardStatement(
    Map<String, dynamic> dashboard,
  ) {
    return _parseList(dashboard['recentStatement'])
        .whereType<Map>()
        .map(_statementPayload)
        .toList();
  }

  Map<String, dynamic> _statementPayload(Map<dynamic, dynamic> rawItem) {
    final item = _parseMap(rawItem);
    final payloadJson = item['displayPayloadJson']?.toString();
    Map<String, dynamic> payload = {};
    if (payloadJson != null && payloadJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payloadJson);
        payload = _parseMap(decoded);
      } catch (_) {}
    }
    return {
      ...payload,
      'id': payload['transactionId'] ?? item['transactionId'] ?? item['id'],
      'transactionId': payload['transactionId'] ?? item['transactionId'],
      'walletId': item['walletId'],
      'createdAt': item['createdAt'],
      'timestamp': item['createdAt'],
      'expiresAt': item['expiresAt'],
    };
  }

  double _satsToBtc(Object? value) {
    final sats = value is num ? value.toInt() : int.tryParse('$value');
    return (sats ?? 0) / 100000000.0;
  }

  int _btcToSats(double value) => (value * 100000000).round();

  bool _matchesWallet(Map<String, dynamic> wallet, String value) {
    final normalized = value.trim();
    return [
      wallet['id'],
      wallet['walletId'],
      wallet['walletName'],
      wallet['name'],
      wallet['label'],
    ].any((candidate) => candidate?.toString() == normalized);
  }

  @override
  Future<List<dynamic>> getAllLedgers() async {
    try {
      final dashboard = await _getDashboard();
      return _dashboardWallets(dashboard).map(_walletLedgerPayload).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao buscar todos ledgers: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> findLedger({required String walletName}) async {
    try {
      final dashboard = await _getDashboard();
      final wallet = _dashboardWallets(dashboard).firstWhere(
        (wallet) => _matchesWallet(wallet, walletName),
        orElse: () => const {},
      );
      if (wallet.isNotEmpty) {
        return _walletLedgerPayload(wallet);
      }
      throw const ValidationException(
        message: 'Conta financeira não encontrada.',
        statusCode: 404,
        errorCode: 'ERR_LEDGER_NOT_FOUND',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao buscar ledger: $e');
    }
  }

  @override
  Future<double> getBalance({required String walletName}) async {
    try {
      final ledger = await findLedger(walletName: walletName);
      return (ledger['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao buscar saldo: $e');
    }
  }

  @override
  Future<List<dynamic>> getHistory({
    int page = 0,
    int size = 50,
    DateTime? since,
  }) async {
    try {
      // Prefer live /kfe/transactions. A successful empty list is legitimate
      // (no rows / page beyond end) — do NOT fall back to the 24h statement
      // payload, which freezes confs and confuses users with balance > 0.
      Object? kfeError;
      try {
        final query = <String, dynamic>{
          'page': page,
          'size': size,
        };
        if (since != null) {
          query['since'] = since.toUtc().toIso8601String();
        }
        final response = await apiClient.get(
          AppConfig.kfeTransactions,
          queryParameters: query,
        );
        return _parseApiList(response.data);
      } catch (e) {
        kfeError = e;
      }

      // Incremental failed (old server?) → retry full page once without since.
      if (since != null) {
        try {
          final response = await apiClient.get(
            AppConfig.kfeTransactions,
            queryParameters: {
              'page': page,
              'size': size,
            },
          );
          return _parseApiList(response.data);
        } catch (e) {
          kfeError = e;
        }
      }

      // Network / server failure only → short statement window as last resort.
      try {
        final dashboard = await _getDashboard();
        final statement = _dashboardStatement(dashboard);
        final offset = page * size;
        // ignore: unawaited_futures
        LedgerTelemetry.recordStatementFallback();
        return statement.skip(offset).take(size).toList();
      } catch (_) {
        if (kfeError is AppException) rethrow;
        throw ServerException(
          message: 'Erro ao buscar histórico: $kfeError',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao buscar histórico: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getTransactionById(String transactionId) async {
    final id = transactionId.trim();
    if (id.isEmpty) return null;
    try {
      final response = await apiClient.get('${AppConfig.kfeTransactions}/$id');
      final map = _parseMap(response.data);
      final data = map['data'] ?? map['result'] ?? map;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao buscar transação: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> sendInternalTransaction({
    required String senderWalletName,
    required String receiverWalletName,
    required double amount,
    required String idempotencyKey,
    required int requestTimestamp,
  }) async {
    try {
      final response = await apiClient.post(
        AppConfig.kfeTransactions,
        data: {
          'idempotencyKey': idempotencyKey,
          'rail': 'INTERNAL',
          'direction': 'INTERNAL',
          'sourceWalletId': senderWalletName,
          'destinationWalletId': receiverWalletName,
          'amountSats': _btcToSats(amount),
          'networkFeeSats': 0,
          'memo': 'transfer',
        },
        options: Options(headers: {
          'X-Idempotency-Key': idempotencyKey,
        }),
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'result': response.data};
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Erro ao enviar transação interna: $e');
    }
  }
}
