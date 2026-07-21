import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Shared chrome metrics for the receive flow — keeps H1 aligned step to step.
abstract final class ReceiveFlowLayout {
  /// H1 overlay row sits at this fraction of the viewport height (from top).
  static const double titleViewportFraction = 0.25;

  static const double titleTextTopPadding = 10;

  static const double sheetTopBorderHeight = 1;
  static const double sheetBorderRadius = 28;
  static const double sheetBorderWidth = 1;

  static Color get sheetTopBorderColor =>
      KeroseneBrandTokens.textPrimary.withValues(alpha: 0.42);

  static Color get sheetBorderColor =>
      KeroseneBrandTokens.textPrimary.withValues(alpha: 0.55);

  static double titleOverlayTop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return padding.top + size.height * titleViewportFraction;
  }

  /// Wallet sheet header (compact, left-aligned) + handle block.
  static const double walletSheetHeaderHeight =
      sheetTopBorderHeight + 12 + 4 + 12 + 52 + 8 + 20 + 12 + 16;

  static const double walletTileHeight = 80;
  static const double walletTileGap = 10;

  static double walletSheetHeight(BuildContext context, int walletCount) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final listHeight = walletCount * walletTileHeight +
        (walletCount - 1).clamp(0, 999) * walletTileGap;
    return walletSheetHeaderHeight + listHeight + bottom;
  }

  static const double walletPickerTitleScale = 0.9;
  static const double walletPickerBodyScale = 0.9;
}
