import 'package:flutter/material.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/widgets/transaction_palette.dart';

/// Expanded home-card surfaces — beyond white / orange / yellow only.
///
/// Each [TxVisualVariant] maps to a distinct paper fill + border + icon well.
abstract final class TransactionVisualTokens {
  // ── Expanded surfaces ────────────────────────────────────────────────────
  // Internal (slate / cool grey — in slightly cooler, out slightly warmer)
  static const surfaceInternalIn = Color(0xFFE8EEF5); // cool slate blue
  static const borderInternalIn = Color(0xFFB7C5D6);
  static const surfaceInternalOut = Color(0xFFF0EDE8); // warm stone
  static const borderInternalOut = Color(0xFFD2CBC2);

  // On-chain — quiet warm paper (glyph carries the rail identity).
  static const surfaceOnchainIn = Color(0xFFF6F1EA);
  static const borderOnchainIn = Color(0xFFD8D0C6);
  static const surfaceOnchainOut = Color(0xFFF3EDE5);
  static const borderOnchainOut = Color(0xFFD2C9BD);

  // Lightning — quiet cool-neutral paper.
  static const surfaceLightningIn = Color(0xFFF3F2EE);
  static const borderLightningIn = Color(0xFFD5D2C9);
  static const surfaceLightningOut = Color(0xFFF1F0EB);
  static const borderLightningOut = Color(0xFFD0CDC4);

  // Cold — soft steel, low chroma.
  static const surfaceColdIn = Color(0xFFEEF2F5);
  static const borderColdIn = Color(0xFFC5CED6);
  static const surfaceColdOut = Color(0xFFE9EEF2);
  static const borderColdOut = Color(0xFFBEC8D0);

  // Payment link — soft violet-grey, not candy.
  static const surfaceLinkIn = Color(0xFFF1EEF4);
  static const borderLinkIn = Color(0xFFD0C9D8);
  static const surfaceLinkOut = Color(0xFFEFEBF3);
  static const borderLinkOut = Color(0xFFCBC3D4);

  // Fee / swap / lifecycle
  static const surfaceFee = Color(0xFFE4E4E7);
  static const borderFee = Color(0xFFA1A1AA);
  static const surfaceSwap = Color(0xFFD4F1EC); // teal
  static const borderSwap = Color(0xFF5BB8A8);
  static const surfaceFailed = Color(0xFFF8D4D4); // rose
  static const borderFailed = Color(0xFFD98080);
  static const surfaceCancelled = Color(0xFFE5E5E5);
  static const borderCancelled = Color(0xFFB0B0B0);
  static const surfaceReconciling = Color(0xFFE0DFF7); // indigo
  static const borderReconciling = Color(0xFF8B87C9);
  static const surfacePending = Color(0xFFF5E6D3);
  static const borderPending = Color(0xFFD2B48C);

  static Color backgroundFor(TxVisualVariant variant) {
    return switch (variant) {
      TxVisualVariant.internalIn => surfaceInternalIn,
      TxVisualVariant.internalOut => surfaceInternalOut,
      TxVisualVariant.onchainIn => surfaceOnchainIn,
      TxVisualVariant.onchainOut => surfaceOnchainOut,
      TxVisualVariant.lightningIn => surfaceLightningIn,
      TxVisualVariant.lightningOut => surfaceLightningOut,
      TxVisualVariant.coldIn => surfaceColdIn,
      TxVisualVariant.coldOut => surfaceColdOut,
      TxVisualVariant.paymentLinkIn => surfaceLinkIn,
      TxVisualVariant.paymentLinkOut => surfaceLinkOut,
      TxVisualVariant.fee => surfaceFee,
      TxVisualVariant.swap => surfaceSwap,
      TxVisualVariant.failed => surfaceFailed,
      TxVisualVariant.cancelled => surfaceCancelled,
      TxVisualVariant.reconciling => surfaceReconciling,
      TxVisualVariant.pendingNeutral => surfacePending,
    };
  }

  static Color borderFor(TxVisualVariant variant) {
    return switch (variant) {
      TxVisualVariant.internalIn => borderInternalIn,
      TxVisualVariant.internalOut => borderInternalOut,
      TxVisualVariant.onchainIn => borderOnchainIn,
      TxVisualVariant.onchainOut => borderOnchainOut,
      TxVisualVariant.lightningIn => borderLightningIn,
      TxVisualVariant.lightningOut => borderLightningOut,
      TxVisualVariant.coldIn => borderColdIn,
      TxVisualVariant.coldOut => borderColdOut,
      TxVisualVariant.paymentLinkIn => borderLinkIn,
      TxVisualVariant.paymentLinkOut => borderLinkOut,
      TxVisualVariant.fee => borderFee,
      TxVisualVariant.swap => borderSwap,
      TxVisualVariant.failed => borderFailed,
      TxVisualVariant.cancelled => borderCancelled,
      TxVisualVariant.reconciling => borderReconciling,
      TxVisualVariant.pendingNeutral => borderPending,
    };
  }

  /// Primary (rail) icon only — never direction-alone, never lifecycle steal.
  ///
  /// Prefer [ActivityGlyph] for list/detail; this remains for legacy single-icon call sites.
  static IconData iconFor(TransactionAxes axes) {
    if (axes.product == TxProduct.fee) return KeroseneIcons.fee;
    if (axes.product == TxProduct.swap) return KeroseneIcons.swap;
    // Lifecycle (cancelled/failed) must not replace the rail — status is external.
    return switch (axes.rail) {
      TxRail.internal => KeroseneIcons.railInternal,
      TxRail.onchain => KeroseneIcons.railOnchain,
      TxRail.lightning => KeroseneIcons.railLightning,
      TxRail.cold => KeroseneIcons.railCold,
    };
  }

  /// Direction badge icon, or null when neutral (fee/swap).
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

  /// Map legacy 3-surface enum when only rail is known.
  static TransactionCardSurface legacySurfaceFor(TxRail rail) {
    return switch (rail) {
      TxRail.internal => TransactionCardSurface.internal,
      TxRail.lightning => TransactionCardSurface.lightning,
      TxRail.onchain || TxRail.cold => TransactionCardSurface.onchain,
    };
  }
}
