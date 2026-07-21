import 'package:flutter/widgets.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/movement/data/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

/// Picks sat/vB, network fee BTC, and ETA seconds from a [FeeEstimate] by tier.
class FeeTierSelection {
  final double networkFeeBtc;
  final double feeRateSatPerByte;
  final int? estimatedSettlementSeconds;
  final int feeTargetBlocks;

  const FeeTierSelection({
    required this.networkFeeBtc,
    required this.feeRateSatPerByte,
    this.estimatedSettlementSeconds,
    this.feeTargetBlocks = 3,
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
          feeTargetBlocks: fee.fastTargetBlocks > 0 ? fee.fastTargetBlocks : 2,
        ),
      NetworkFeeTier.standard => FeeTierSelection(
          networkFeeBtc: fee.estimatedStandardBtc,
          feeRateSatPerByte: fee.standardSatPerByte,
          estimatedSettlementSeconds: fee.standardEstimatedSeconds,
          feeTargetBlocks:
              fee.standardTargetBlocks > 0 ? fee.standardTargetBlocks : 3,
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
          feeTargetBlocks: fee.slowTargetBlocks > 0 ? fee.slowTargetBlocks : 6,
        ),
    };
  }

  static String tierLabel(NetworkFeeTier tier, AppLocalizations l10n) {
    return switch (tier) {
      NetworkFeeTier.fast => l10n.feeTierFast,
      NetworkFeeTier.standard => l10n.feeTierStandard,
      NetworkFeeTier.slow => l10n.feeTierSlow,
    };
  }

  /// Prefer [tierLabelForContext] from widgets.
  @Deprecated('Pass AppLocalizations via tierLabel')
  static String tierLabelLegacy(NetworkFeeTier tier, String languageCode) {
    // Fallback without ARB (tests / pure helpers).
    return switch ((tier, languageCode)) {
      (NetworkFeeTier.fast, 'en') => 'Fast',
      (NetworkFeeTier.fast, 'es') => 'Rápido',
      (NetworkFeeTier.fast, _) => 'Rápido',
      (NetworkFeeTier.standard, _) => 'Normal',
      (NetworkFeeTier.slow, 'en') => 'Economy',
      (NetworkFeeTier.slow, 'es') => 'Económico',
      (NetworkFeeTier.slow, _) => 'Econômico',
    };
  }

  static String tierLabelForContext(BuildContext context, NetworkFeeTier tier) {
    return tierLabel(tier, context.tr);
  }

  static String formatEta(
    int? seconds,
    AppLocalizations l10n, {
    bool testnetLike = false,
  }) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds / 60).ceil();
    final base = minutes < 60
        ? l10n.feeEtaMinutes(minutes)
        : l10n.feeEtaHours((minutes / 60).ceil());
    if (!testnetLike) return base;
    // Testnet/signet/regtest: block production is irregular — never sell as SLA.
    final lang = l10n.localeName.toLowerCase();
    if (lang.startsWith('en')) {
      return '$base · testnet timing varies';
    }
    if (lang.startsWith('es')) {
      return '$base · en testnet el tiempo varía';
    }
    return '$base · no testnet o tempo varia';
  }

  static String formatEtaForContext(
    BuildContext context,
    int? seconds, {
    bool testnetLike = false,
  }) {
    return formatEta(seconds, context.tr, testnetLike: testnetLike);
  }

  @Deprecated('Pass AppLocalizations via formatEta')
  static String formatEtaLegacy(int? seconds, String languageCode) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '~$minutes min';
    final hours = (minutes / 60).ceil();
    return '~$hours h';
  }
}
