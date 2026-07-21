import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/activity_surface_tokens.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_palette.dart';

/// Domain mapping from [TxVisualVariant] → [ActivitySurfaceTokens].
///
/// Color values live in the design system; this file owns taxonomy → paint.
abstract final class TransactionVisualTokens {
  static Color backgroundFor(TxVisualVariant variant) {
    return switch (variant) {
      TxVisualVariant.internalIn => ActivitySurfaceTokens.surfaceInternalIn,
      TxVisualVariant.internalOut => ActivitySurfaceTokens.surfaceInternalOut,
      TxVisualVariant.onchainIn => ActivitySurfaceTokens.surfaceOnchainIn,
      TxVisualVariant.onchainOut => ActivitySurfaceTokens.surfaceOnchainOut,
      TxVisualVariant.lightningIn => ActivitySurfaceTokens.surfaceLightningIn,
      TxVisualVariant.lightningOut => ActivitySurfaceTokens.surfaceLightningOut,
      TxVisualVariant.coldIn => ActivitySurfaceTokens.surfaceColdIn,
      TxVisualVariant.coldOut => ActivitySurfaceTokens.surfaceColdOut,
      TxVisualVariant.paymentLinkIn => ActivitySurfaceTokens.surfaceLinkIn,
      TxVisualVariant.paymentLinkOut => ActivitySurfaceTokens.surfaceLinkOut,
      TxVisualVariant.fee => ActivitySurfaceTokens.surfaceFee,
      TxVisualVariant.swap => ActivitySurfaceTokens.surfaceSwap,
      TxVisualVariant.failed => ActivitySurfaceTokens.surfaceFailed,
      TxVisualVariant.cancelled => ActivitySurfaceTokens.surfaceCancelled,
      TxVisualVariant.reconciling => ActivitySurfaceTokens.surfaceReconciling,
      TxVisualVariant.pendingNeutral => ActivitySurfaceTokens.surfacePending,
    };
  }

  static Color borderFor(TxVisualVariant variant) {
    return switch (variant) {
      TxVisualVariant.internalIn => ActivitySurfaceTokens.borderInternalIn,
      TxVisualVariant.internalOut => ActivitySurfaceTokens.borderInternalOut,
      TxVisualVariant.onchainIn => ActivitySurfaceTokens.borderOnchainIn,
      TxVisualVariant.onchainOut => ActivitySurfaceTokens.borderOnchainOut,
      TxVisualVariant.lightningIn => ActivitySurfaceTokens.borderLightningIn,
      TxVisualVariant.lightningOut => ActivitySurfaceTokens.borderLightningOut,
      TxVisualVariant.coldIn => ActivitySurfaceTokens.borderColdIn,
      TxVisualVariant.coldOut => ActivitySurfaceTokens.borderColdOut,
      TxVisualVariant.paymentLinkIn => ActivitySurfaceTokens.borderLinkIn,
      TxVisualVariant.paymentLinkOut => ActivitySurfaceTokens.borderLinkOut,
      TxVisualVariant.fee => ActivitySurfaceTokens.borderFee,
      TxVisualVariant.swap => ActivitySurfaceTokens.borderSwap,
      TxVisualVariant.failed => ActivitySurfaceTokens.borderFailed,
      TxVisualVariant.cancelled => ActivitySurfaceTokens.borderCancelled,
      TxVisualVariant.reconciling => ActivitySurfaceTokens.borderReconciling,
      TxVisualVariant.pendingNeutral => ActivitySurfaceTokens.borderPending,
    };
  }

  /// Primary (rail) icon only — never direction-alone, never lifecycle steal.
  static IconData iconFor(TransactionAxes axes) {
    if (axes.product == TxProduct.fee) return KeroseneIcons.fee;
    if (axes.product == TxProduct.swap) return KeroseneIcons.swap;
    return switch (axes.rail) {
      TxRail.internal => KeroseneIcons.railInternal,
      TxRail.onchain => KeroseneIcons.railOnchain,
      TxRail.lightning => KeroseneIcons.railLightning,
      TxRail.cold => KeroseneIcons.railCold,
    };
  }

  static IconData? directionIconFor(TransactionAxes axes) {
    if (axes.product == TxProduct.fee || axes.product == TxProduct.swap) {
      return null;
    }
    return switch (axes.direction) {
      TxDirection.incoming => KeroseneIcons.dirIn,
      TxDirection.outgoing => KeroseneIcons.dirOut,
      TxDirection.neutral => null,
    };
  }

  static TransactionCardSurface legacySurfaceFor(TxRail rail) {
    return switch (rail) {
      TxRail.internal => TransactionCardSurface.internal,
      TxRail.lightning => TransactionCardSurface.lightning,
      TxRail.onchain || TxRail.cold => TransactionCardSurface.onchain,
    };
  }
}
