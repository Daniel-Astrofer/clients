import 'package:equatable/equatable.dart';

/// Estimativa de taxa de transação Bitcoin
class FeeEstimate extends Equatable {
  final double fastSatPerByte;
  final double standardSatPerByte;
  final double slowSatPerByte;
  final double estimatedFastBtc;
  final double estimatedStandardBtc;
  final double estimatedSlowBtc;
  final double amountReceived;
  final double totalToSend;
  final double keroseneFeeBtc;
  final double totalFeeBtc;
  final int estimatedVbytes;
  final int estimatedConfirmationBlocks;
  final int? fastEstimatedSeconds;
  final int? standardEstimatedSeconds;
  final int? slowEstimatedSeconds;
  final int fastTargetBlocks;
  final int standardTargetBlocks;
  final int slowTargetBlocks;
  final String? feeSource;
  final DateTime? quoteExpiresAt;
  final bool serverPriced;

  const FeeEstimate({
    required this.fastSatPerByte,
    required this.standardSatPerByte,
    required this.slowSatPerByte,
    required this.estimatedFastBtc,
    required this.estimatedStandardBtc,
    required this.estimatedSlowBtc,
    required this.amountReceived,
    required this.totalToSend,
    this.keroseneFeeBtc = 0,
    this.totalFeeBtc = 0,
    this.estimatedVbytes = 0,
    this.estimatedConfirmationBlocks = 0,
    this.fastEstimatedSeconds,
    this.standardEstimatedSeconds,
    this.slowEstimatedSeconds,
    this.fastTargetBlocks = 2,
    this.standardTargetBlocks = 3,
    this.slowTargetBlocks = 6,
    this.feeSource,
    this.quoteExpiresAt,
    this.serverPriced = false,
  });

  factory FeeEstimate.fromJson(Map<String, dynamic> json) {
    return FeeEstimate(
      fastSatPerByte: (json['fastSatPerByte'] as num?)?.toDouble() ?? 0,
      standardSatPerByte: (json['standardSatPerByte'] as num?)?.toDouble() ?? 0,
      slowSatPerByte: (json['slowSatPerByte'] as num?)?.toDouble() ?? 0,
      estimatedFastBtc: (json['estimatedFastBtc'] as num?)?.toDouble() ?? 0,
      estimatedStandardBtc:
          (json['estimatedStandardBtc'] as num?)?.toDouble() ?? 0,
      estimatedSlowBtc: (json['estimatedSlowBtc'] as num?)?.toDouble() ?? 0,
      amountReceived: (json['amountReceived'] as num?)?.toDouble() ?? 0,
      totalToSend: (json['totalToSend'] as num?)?.toDouble() ?? 0,
      keroseneFeeBtc: (json['keroseneFeeBtc'] as num?)?.toDouble() ?? 0,
      totalFeeBtc: (json['totalFeeBtc'] as num?)?.toDouble() ?? 0,
      estimatedVbytes: (json['estimatedVbytes'] as num?)?.toInt() ?? 0,
      estimatedConfirmationBlocks:
          (json['estimatedConfirmationBlocks'] as num?)?.toInt() ?? 0,
      fastEstimatedSeconds: (json['fastEstimatedSeconds'] as num?)?.toInt(),
      standardEstimatedSeconds:
          (json['standardEstimatedSeconds'] as num?)?.toInt(),
      slowEstimatedSeconds: (json['slowEstimatedSeconds'] as num?)?.toInt(),
      fastTargetBlocks: (json['fastTargetBlocks'] as num?)?.toInt() ?? 2,
      standardTargetBlocks:
          (json['standardTargetBlocks'] as num?)?.toInt() ?? 3,
      slowTargetBlocks: (json['slowTargetBlocks'] as num?)?.toInt() ?? 6,
      feeSource: json['feeSource']?.toString(),
      quoteExpiresAt: DateTime.tryParse(
        json['quoteExpiresAt']?.toString() ?? '',
      ),
      serverPriced: json['serverPriced'] == true,
    );
  }

  @override
  List<Object?> get props => [
        fastSatPerByte,
        standardSatPerByte,
        slowSatPerByte,
        estimatedFastBtc,
        estimatedStandardBtc,
        estimatedSlowBtc,
        amountReceived,
        totalToSend,
        keroseneFeeBtc,
        totalFeeBtc,
        estimatedVbytes,
        estimatedConfirmationBlocks,
        fastEstimatedSeconds,
        standardEstimatedSeconds,
        slowEstimatedSeconds,
        fastTargetBlocks,
        standardTargetBlocks,
        slowTargetBlocks,
        feeSource,
        quoteExpiresAt,
        serverPriced,
      ];
}
