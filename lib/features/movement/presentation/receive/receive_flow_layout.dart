import 'package:flutter/material.dart';

/// Shared chrome metrics for the receive flow — keeps H1 + body rhythm
/// aligned from hub → network → NFC → gateway.
abstract final class ReceiveFlowLayout {
  /// Space above the H1 as a fraction of the available viewport height.
  static const double titleLeadFraction = 0.10;

  static const double titleTextTopPadding = 10;

  /// Gap between the title block and the centered body.
  static const double titleToContentGap = 28;

  static const double pageHorizontal = 24;
  static const double pageBottom = 24;

  /// Vertical gap between selectable option cards / tiles.
  static const double optionGap = 12;

  static const double sheetTopBorderHeight = 1;
  static const double sheetBorderRadius = 28;
  static double sheetBorderWidth = 1;

  static Color sheetTopBorderColorOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);

  static Color sheetBorderColorOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

  /// Optical lead above the title. Clamped so short phones stay compact and
  /// tall phones don't pin the H1 to the status bar.
  static double titleTopLead(double viewportHeight) {
    return (viewportHeight * titleLeadFraction).clamp(20.0, 72.0);
  }

  /// Prefer [MediaQuery.padding] (SafeArea-aware) over viewPadding so nested
  /// SafeAreas never double-count the status bar.
  static double statusTopPad(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Legacy overlay helper — kept for any remaining Positioned callers.
  static double titleOverlayTop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return statusTopPad(context) + titleTopLead(size.height);
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
