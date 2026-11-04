import 'package:flutter/foundation.dart';
import 'package:kerosene/features/movement/data/entities/transaction_dto.dart' show Satoshis;

extension type const WalletId(String value) {
  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
}

/// Lightweight Wallet and Balance DTO using Dart 3.13 concepts.
@immutable
class WalletDto {
  final WalletId id;
  final String name;
  final String type;
  final Satoshis balanceSatoshis;
  final double balanceBtc;
  final String? address;
  final bool isDefault;
  final Map<String, dynamic> rawPayload;

  const WalletDto({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceSatoshis,
    required this.balanceBtc,
    this.address,
    this.isDefault = false,
    this.rawPayload = const {},
  });

  factory WalletDto.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['walletId']?.toString() ?? '';
    final rawName = json['name']?.toString() ?? 'Wallet';
    final rawType = json['type']?.toString() ?? 'ONCHAIN';
    final rawSat = json['balanceSatoshis'] is int
        ? json['balanceSatoshis'] as int
        : (int.tryParse(json['balanceSatoshis']?.toString() ?? '') ?? 0);
    final rawBtc = json['balance'] is num
        ? (json['balance'] as num).toDouble()
        : (double.tryParse(json['balance']?.toString() ?? '') ?? (rawSat / 100000000.0));

    return WalletDto(
      id: WalletId(rawId),
      name: rawName,
      type: rawType,
      balanceSatoshis: Satoshis(rawSat),
      balanceBtc: rawBtc,
      address: json['address']?.toString(),
      isDefault: json['isDefault'] == true,
      rawPayload: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'name': name,
        'type': type,
        'balanceSatoshis': balanceSatoshis.value,
        'balance': balanceBtc,
        'address': address,
        'isDefault': isDefault,
        ...rawPayload,
      };
}
