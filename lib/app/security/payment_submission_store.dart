import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart'
    show secureStorageServiceProvider;
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';

/// Recovery identity and financial facts only. Authorization factors never enter
/// this model, the journal, its fingerprints, or its textual representation.
class PaymentSubmission {
  final String key;
  final Map<String, Object?> financial;
  final Map<String, Object?> display;
  final DateTime createdAt;
  final String? transactionId;

  PaymentSubmission(
      {required this.key,
      required Map<String, Object?> financial,
      Map<String, Object?> display = const {},
      required this.createdAt,
      this.transactionId})
      : financial = Map.unmodifiable(financial),
        display = Map.unmodifiable(display);

  String get walletId => financial['sourceWalletId'] as String;
  String get rail => financial['rail'] as String;
  int get amountSats => financial['amountSats'] as int;
  String get destination =>
      (financial['destinationWalletId'] ?? financial['externalReference'] ?? '')
          as String;
  String get fingerprint => jsonEncode(financial);
  String get identity => jsonEncode([
        walletId,
        rail,
        financial['direction'],
        destination,
        amountSats,
        financial['paymentRequestPublicId']
      ]);

  Map<String, Object?> toJson() => {
        'key': key,
        'financial': financial,
        'display': display,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'transactionId': transactionId
      };

  factory PaymentSubmission.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final created = DateTime.tryParse('${json['createdAt']}');
    if (key is! String ||
        key.trim().isEmpty ||
        key.length > 180 ||
        created == null ||
        json['financial'] is! Map) {
      throw const FormatException('Invalid submission journal.');
    }
    final financial = PaymentSubmissionStore.financialFacts(
        Map<String, dynamic>.from(json['financial'] as Map));
    final id = json['transactionId'];
    if (id != null &&
        (id is! String || !PaymentSubmissionStore.validTransactionId(id))) {
      throw const FormatException('Invalid submission result identity.');
    }
    return PaymentSubmission(
        key: key,
        financial: financial,
        display: PaymentSubmissionStore.displayFacts(
            Map<String, Object?>.from((json['display'] as Map?) ?? {})),
        createdAt: created,
        transactionId: id as String?);
  }

  @override
  String toString() => 'PaymentSubmission[identity=REDACTED]';
}

/// Serializes journal mutations so simultaneous responses cannot lose records.
/// A storage failure blocks a new HTTP submission; it never turns a known
/// successful payment response into a financial failure.
class PaymentSubmissionStore {
  PaymentSubmissionStore(this.storage, {this.onChanged});
  final SecureStorageService storage;
  final void Function(String scope)? onChanged;
  Future<void> _tail = Future.value();
  final Map<String, Map<String, Object?>> _display = {};
  static const _financialKeys = {
    'rail',
    'direction',
    'sourceWalletId',
    'destinationWalletId',
    'amountSats',
    'networkFeeSats',
    'externalReference',
    'memo',
    'paymentRequestPublicId',
    'feeRateSatPerVbyte',
    'feeTargetBlocks',
    'quoteId'
  };
  static const _authorizationKeys = {
    'idempotencyKey',
    'totpCode',
    'appPin',
    'passkeyAssertionJson',
    'confirmationPassphrase'
  };
  static const _displayKeys = {
    'currency',
    'locale',
    'btcDecimalPlaces',
    'btcUsd',
    'btcEur',
    'btcBrl'
  };

  static Map<String, Object?> displayFacts(Map<String, Object?> data) {
    if (data.keys.any((key) => !_displayKeys.contains(key))) {
      throw const FormatException('Unsupported submission display field.');
    }
    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (entry.key == 'currency') {
        if (!{'BTC', 'BRL', 'USD', 'EUR'}.contains(value)) {
          throw const FormatException('Invalid display currency.');
        }
      } else if (entry.key == 'locale') {
        if (value is! String ||
            !RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(value)) {
          throw const FormatException('Invalid display locale.');
        }
      } else if (entry.key == 'btcDecimalPlaces') {
        if (value is! int || !{2, 4, 8}.contains(value)) {
          throw const FormatException('Invalid submission display precision.');
        }
      } else if (value is! num || !value.isFinite || value <= 0) {
        throw const FormatException('Invalid submission display quote.');
      }
    }
    return Map.of(data);
  }

  static bool validTransactionId(String id) =>
      RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
          .hasMatch(id);

  static Map<String, Object?> financialFacts(Map<String, dynamic> body) {
    if (body.keys.any((key) =>
        !_financialKeys.contains(key) && !_authorizationKeys.contains(key))) {
      throw const FormatException('Unsupported financial request field.');
    }
    if (body['sourceWalletId'] is! String ||
        (body['sourceWalletId'] as String).isEmpty ||
        body['amountSats'] is! int ||
        (body['amountSats'] as int) <= 0 ||
        !{'INTERNAL', 'ONCHAIN', 'LIGHTNING'}.contains(body['rail']) ||
        !{'INTERNAL', 'OUTBOUND', 'INBOUND'}.contains(body['direction'])) {
      throw const FormatException('Invalid financial submission.');
    }
    final keys = _financialKeys.where(body.containsKey).toList()..sort();
    final facts = <String, Object?>{};
    for (final key in keys) {
      final value = body[key];
      if (value != null && value is! String && value is! int) {
        throw const FormatException('Invalid financial request value.');
      }
      facts[key] = value;
    }
    return facts;
  }

  void rememberDisplay(String key, Map<String, Object?> display) {
    _display[key] = displayFacts(display);
  }

  String _storageKey(String scope) {
    if (scope.trim().isEmpty) {
      throw StateError('Submission account scope is required.');
    }
    return 'payment_submissions_v1:${sha256.convert(utf8.encode(scope))}';
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    // The caller receives the error; the mutation queue must remain usable.
    _tail = next.then((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<List<PaymentSubmission>> _read(String scope) async {
    final raw = await storage.readStrict(key: _storageKey(scope));
    if (raw == null) return [];
    final json = jsonDecode(raw);
    if (json is! Map || json['schema'] != 1 || json['submissions'] is! List) {
      throw const FormatException('Invalid submission journal schema.');
    }
    final records = (json['submissions'] as List)
        .map((value) =>
            PaymentSubmission.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
    if (records.map((record) => record.key).toSet().length != records.length) {
      throw const FormatException('Duplicate submission recovery identity.');
    }
    return records;
  }

  Future<List<PaymentSubmission>> load(String scope) =>
      _exclusive(() => _read(scope));

  Future<void> _write(String scope, List<PaymentSubmission> records) async {
    await storage.write(
        key: _storageKey(scope),
        value: jsonEncode({
          'schema': 1,
          'submissions': records.map((record) => record.toJson()).toList()
        }));
    onChanged?.call(scope);
  }

  Future<PaymentSubmission> begin(String scope, Map<String, dynamic> body) =>
      _exclusive(() async {
        final key = body['idempotencyKey'];
        if (key is! String || key.trim().isEmpty || key.length > 180) {
          throw const FormatException('Submission key is required.');
        }
        final candidate = PaymentSubmission(
            key: key,
            financial: financialFacts(body),
            display: _display[key] ?? const {},
            createdAt: DateTime.now().toUtc());
        final records = await _read(scope);
        for (final existing in records) {
          if (existing.key == key) {
            if (existing.fingerprint != candidate.fingerprint) {
              throw const PaymentRecoveryException(
                  outcomeUncertain: true,
                  message: 'The original payment is still being checked.',
                  errorCode: 'ERR_PAYMENT_RECOVERY_PENDING');
            }
            _display.remove(key);
            return existing;
          }
          if (existing.transactionId == null &&
              existing.identity == candidate.identity) {
            if (existing.fingerprint != candidate.fingerprint) {
              throw const PaymentRecoveryException(
                  outcomeUncertain: true,
                  message: 'The original payment is still being checked.',
                  errorCode: 'ERR_PAYMENT_RECOVERY_PENDING');
            }
            // A deliberate, newly authorized retry of the same request keeps its
            // original key, including after the review route or process closes.
            _display.remove(key);
            return existing;
          }
          if (existing.transactionId != null &&
              existing.identity == candidate.identity) {
            throw const PaymentRecoveryException(
                outcomeUncertain: true,
                message: 'An earlier payment still needs your acknowledgment.',
                errorCode: 'ERR_PAYMENT_RECOVERY_EXISTING');
          }
        }
        await _write(scope, [...records, candidate]);
        _display.remove(key);
        return candidate;
      });

  Future<void> accepted(String scope, String key, String transactionId) =>
      _exclusive(() async {
        if (!validTransactionId(transactionId)) {
          throw const FormatException('Invalid accepted payment identity.');
        }
        final records = await _read(scope);
        final index = records.indexWhere((record) => record.key == key);
        if (index < 0) {
          throw StateError('Submission recovery record is missing.');
        }
        final existing = records[index];
        if (existing.transactionId == transactionId) return;
        if (existing.transactionId != null) {
          throw StateError('Submission result identity changed.');
        }
        records[index] = PaymentSubmission(
            key: key,
            financial: existing.financial,
            display: existing.display,
            createdAt: existing.createdAt,
            transactionId: transactionId);
        await _write(scope, records);
        _display.remove(key);
      });

  Future<void> acknowledge(String scope, String key,
          {String? resolvedTransactionId}) =>
      _exclusive(() async {
        final records = await _read(scope);
        final record = records.where((record) => record.key == key).firstOrNull;
        if (record == null) return;
        if (resolvedTransactionId != null &&
            (!validTransactionId(resolvedTransactionId) ||
                (record.transactionId != null &&
                    record.transactionId != resolvedTransactionId))) {
          throw StateError('Acknowledged payment identity does not match.');
        }
        if (record.transactionId == null && resolvedTransactionId == null) {
          throw StateError('An unresolved submission cannot be dismissed.');
        }
        await _write(
            scope, records.where((record) => record.key != key).toList());
        _display.remove(key);
      });

  /// Ordinary receipt/detail viewers know the server ID, not a submission key.
  /// Only already-resolved records can be acknowledged through this path.
  Future<void> acknowledgeTransaction(String scope, String transactionId) =>
      _exclusive(() async {
        if (!validTransactionId(transactionId)) return;
        final records = await _read(scope);
        final remaining = records
            .where((record) => record.transactionId != transactionId)
            .toList();
        if (remaining.length != records.length) await _write(scope, remaining);
      });
}

final paymentSubmissionRevisionProvider =
    NotifierProvider<PaymentSubmissionRevision, int>(
        PaymentSubmissionRevision.new);

class PaymentSubmissionRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final paymentSubmissionStoreProvider = Provider<PaymentSubmissionStore>((ref) =>
    PaymentSubmissionStore(ref.watch(secureStorageServiceProvider),
        onChanged: (_) {
      if (ref.mounted) {
        ref.read(paymentSubmissionRevisionProvider.notifier).changed();
      }
    }));
