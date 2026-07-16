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

  // On-chain (orange family — in soft peach, out deeper amber)
  static const surfaceOnchainIn = Color(0xFFFFD9A8);
  static const borderOnchainIn = Color(0xFFE8A04A);
  static const surfaceOnchainOut = Color(0xFFFFB86B);
  static const borderOnchainOut = Color(0xFFD9883A);

  // Lightning (gold / chartreuse — in soft gold, out brighter)
  static const surfaceLightningIn = Color(0xFFF7E9A8);
  static const borderLightningIn = Color(0xFFD4BC4A);
  static const surfaceLightningOut = Color(0xFFE8F5A0);
  static const borderLightningOut = Color(0xFFB8C94A);

  // Cold (ice / steel blue)
  static const surfaceColdIn = Color(0xFFD9ECF7);
  static const borderColdIn = Color(0xFF7EB6D4);
  static const surfaceColdOut = Color(0xFFC5D8E8);
  static const borderColdOut = Color(0xFF6A93B0);

  // Payment link (violet)
  static const surfaceLinkIn = Color(0xFFE8DFF5);
  static const borderLinkIn = Color(0xFFA78BDB);
  static const surfaceLinkOut = Color(0xFFDCC8F0);
  static const borderLinkOut = Color(0xFF9470C8);

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

  /// Icon by taxonomy — direction + rail, not a single group icon for all internal.
  static IconData iconFor(TransactionAxes axes) {
    final life = axes.lifecycle;
    if (life == TxLifecycle.cancelled) return KeroseneIcons.cancel;
    if (life == TxLifecycle.failed ||
        life == TxLifecycle.unconfirmedExpired) {
      return KeroseneIcons.warning;
    }
    if (axes.product == TxProduct.fee) return KeroseneIcons.fee;
    if (axes.product == TxProduct.swap) return KeroseneIcons.swap;

    return switch (axes.rail) {
      TxRail.internal => axes.direction == TxDirection.incoming
          ? KeroseneIcons.down
          : KeroseneIcons.up,
      TxRail.onchain => KeroseneIcons.onchain,
      TxRail.lightning => KeroseneIcons.lightning,
      TxRail.cold => KeroseneIcons.coldWallet,
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
