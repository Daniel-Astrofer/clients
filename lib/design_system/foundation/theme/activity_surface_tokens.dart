import 'package:flutter/material.dart';

/// Paper fill + border tokens for activity / statement transaction cards.
///
/// Domain mapping (`TxVisualVariant` → these colors) stays in the movement
/// feature; this file is the visual source of truth.
abstract final class ActivitySurfaceTokens {
  // Internal (slate / cool grey — in slightly cooler, out slightly warmer)
  static const surfaceInternalIn = Color(0xFFE8EEF5);
  static const borderInternalIn = Color(0xFFB7C5D6);
  static const surfaceInternalOut = Color(0xFFF0EDE8);
  static const borderInternalOut = Color(0xFFD2CBC2);

  // On-chain — quiet warm paper
  static const surfaceOnchainIn = Color(0xFFF6F1EA);
  static const borderOnchainIn = Color(0xFFD8D0C6);
  static const surfaceOnchainOut = Color(0xFFF3EDE5);
  static const borderOnchainOut = Color(0xFFD2C9BD);

  // Lightning — quiet cool-neutral paper
  static const surfaceLightningIn = Color(0xFFF3F2EE);
  static const borderLightningIn = Color(0xFFD5D2C9);
  static const surfaceLightningOut = Color(0xFFF1F0EB);
  static const borderLightningOut = Color(0xFFD0CDC4);

  // Cold — soft steel
  static const surfaceColdIn = Color(0xFFEEF2F5);
  static const borderColdIn = Color(0xFFC5CED6);
  static const surfaceColdOut = Color(0xFFE9EEF2);
  static const borderColdOut = Color(0xFFBEC8D0);

  // Payment link — soft violet-grey
  static const surfaceLinkIn = Color(0xFFF1EEF4);
  static const borderLinkIn = Color(0xFFD0C9D8);
  static const surfaceLinkOut = Color(0xFFEFEBF3);
  static const borderLinkOut = Color(0xFFCBC3D4);

  // Fee / swap / lifecycle
  static const surfaceFee = Color(0xFFE4E4E7);
  static const borderFee = Color(0xFFA1A1AA);
  static const surfaceSwap = Color(0xFFD4F1EC);
  static const borderSwap = Color(0xFF5BB8A8);
  static const surfaceFailed = Color(0xFFF8D4D4);
  static const borderFailed = Color(0xFFD98080);
  static const surfaceCancelled = Color(0xFFE5E5E5);
  static const borderCancelled = Color(0xFFB0B0B0);
  static const surfaceReconciling = Color(0xFFE0DFF7);
  static const borderReconciling = Color(0xFF8B87C9);
  static const surfacePending = Color(0xFFF5E6D3);
  static const borderPending = Color(0xFFD2B48C);
}
