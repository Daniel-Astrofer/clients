import 'package:kerosene/features/movement/domain/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';

/// Picks sat/vB, network fee BTC, and ETA seconds from a [FeeEstimate] by tier.
class FeeTierSelection {
  final double networkFeeBtc;
  final double feeRateSatPerByte;
  final int? estimatedSettlementSeconds;

  const FeeTierSelection({
    required this.networkFeeBtc,
    required this.feeRateSatPerByte,
    this.estimatedSettlementSeconds,
  });

  static FeeTierSelection fromEstimate(
    FeeEstimate fee, {
    NetworkFeeTier tier = NetworkFeeTier.standard,
  }) {
    return switch (tier) {
      NetworkFeeTier.fast => FeeTierSelection(
          networkFeeBtc: fee.estimatedFastBtc > 0
              ? fee.estimatedFastBtc
              : fee.estimatedStandardBtc,
          feeRateSatPerByte: fee.fastSatPerByte > 0
              ? fee.fastSatPerByte
              : fee.standardSatPerByte,
          estimatedSettlementSeconds:
              fee.fastEstimatedSeconds ?? fee.standardEstimatedSeconds,
        ),
      NetworkFeeTier.standard => FeeTierSelection(
          networkFeeBtc: fee.estimatedStandardBtc,
          feeRateSatPerByte: fee.standardSatPerByte,
          estimatedSettlementSeconds: fee.standardEstimatedSeconds,
        ),
      NetworkFeeTier.slow => FeeTierSelection(
          networkFeeBtc: fee.estimatedSlowBtc > 0
              ? fee.estimatedSlowBtc
              : fee.estimatedStandardBtc,
          feeRateSatPerByte: fee.slowSatPerByte > 0
              ? fee.slowSatPerByte
              : fee.standardSatPerByte,
          estimatedSettlementSeconds:
              fee.slowEstimatedSeconds ?? fee.standardEstimatedSeconds,
        ),
    };
  }

  static String tierLabel(NetworkFeeTier tier, String languageCode) {
    return switch ((tier, languageCode)) {
      (NetworkFeeTier.fast, 'en') => 'Fast',
      (NetworkFeeTier.fast, 'es') => 'Rápido',
      (NetworkFeeTier.fast, _) => 'Rápido',
      (NetworkFeeTier.standard, 'en') => 'Normal',
      (NetworkFeeTier.standard, 'es') => 'Normal',
      (NetworkFeeTier.standard, _) => 'Normal',
      (NetworkFeeTier.slow, 'en') => 'Economy',
      (NetworkFeeTier.slow, 'es') => 'Económico',
      (NetworkFeeTier.slow, _) => 'Econômico',
    };
  }

  static String formatEta(int? seconds, String languageCode) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) {
      return switch (languageCode) {
        'en' => '~$minutes min',
        'es' => '~$minutes min',
        _ => '~$minutes min',
      };
    }
    final hours = (minutes / 60).ceil();
    return switch (languageCode) {
      'en' => '~$hours h',
      'es' => '~$hours h',
      _ => '~$hours h',
    };
  }
}
