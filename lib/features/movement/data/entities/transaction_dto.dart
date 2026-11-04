import 'package:flutter/foundation.dart';

/// Dart 3.13 Zero-Allocation Extension Types for strongly-typed identifiers.
/// These compile down to their underlying types with zero heap allocation.
extension type const TxId(String value) {
  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
}

extension type const Satoshis(int value) {
  double toBtc() => value / 100000000.0;
  bool get isPositive => value > 0;
  bool get isNegative => value < 0;
}

/// Lightweight Transaction DTO using Dart 3.13 Primary Constructors (Option B).
/// Zero code generation, zero reflection, zero VM wrapper overhead.
@immutable
class TransactionDto {
  final TxId id;
  final String txid;
  final String status;
  final String type;
  final Satoshis amountSatoshis;
  final double amount;
  final int timestamp;
  final String? address;
  final String? description;
  final int confirmations;
  final String rail;
  final Map<String, dynamic> rawPayload;

  const TransactionDto({
    required this.id,
    required this.txid,
    required this.status,
    required this.type,
    required this.amountSatoshis,
    required this.amount,
    required this.timestamp,
    this.address,
    this.description,
    this.confirmations = 0,
    this.rail = 'ONCHAIN',
    this.rawPayload = const {},
  });

  factory TransactionDto.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['transactionId']?.toString() ?? '';
    final rawTxid = json['txid']?.toString() ?? rawId;
    final rawAmountSat = json['amountSatoshis'] is int
        ? json['amountSatoshis'] as int
        : (int.tryParse(json['amountSatoshis']?.toString() ?? '') ?? 0);
    final rawAmount = json['amount'] is num
        ? (json['amount'] as num).toDouble()
        : (double.tryParse(json['amount']?.toString() ?? '') ?? 0.0);
    final rawTimestamp = json['timestamp'] is int
        ? json['timestamp'] as int
        : (DateTime.tryParse(json['timestamp']?.toString() ?? '')?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch);

    return TransactionDto(
      id: TxId(rawId),
      txid: rawTxid,
      status: json['status']?.toString() ?? 'PENDING',
      type: json['type']?.toString() ?? 'UNKNOWN',
      amountSatoshis: Satoshis(rawAmountSat),
      amount: rawAmount,
      timestamp: rawTimestamp,
      address: json['address']?.toString() ?? json['destination']?.toString(),
      description: json['description']?.toString() ?? json['memo']?.toString(),
      confirmations: json['confirmations'] is int
          ? json['confirmations'] as int
          : (int.tryParse(json['confirmations']?.toString() ?? '') ?? 0),
      rail: json['rail']?.toString().toUpperCase() ?? 'ONCHAIN',
      rawPayload: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'txid': txid,
        'status': status,
        'type': type,
        'amountSatoshis': amountSatoshis.value,
        'amount': amount,
        'timestamp': timestamp,
        'address': address,
        'description': description,
        'confirmations': confirmations,
        'rail': rail,
        ...rawPayload,
      };
}
