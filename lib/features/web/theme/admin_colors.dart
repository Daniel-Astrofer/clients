import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Admin color aliases for the web dashboard.
///
/// Dark-first palette. Values delegate to [KeroseneBrandTheme.dark] and
/// [AppColors] tokens where possible. Admin-specific colors (sidebar, table,
/// chart) are defined here.
class AdminColors {
  AdminColors._();

  // --- Dark admin palette ---
  // Keep these aliases const: this file is used extensively from const Flutter
  // widgets. Getters delegated through KeroseneBrandTheme are not compile-time
  // constants, even though the dark theme itself is const.
  static const Color background = AppColors.onyxCanvas;
  static const Color backgroundElevated = AppColors.graphiteSurface;
  static const Color surface = AppColors.carbonSurface;
  static const Color surfaceElevated = AppColors.graphiteSurface;
  static const Color surfaceHover = AppColors.carbonSurface;

  static const Color borderSubtle = AppColors.smokeSurface;
  static const Color border = AppColors.smokeSurface;
  static const Color borderStrong = AppColors.ashBorder;

  static const Color textPrimary = AppColors.snow;
  static const Color textSecondary = AppColors.mistText;
  static const Color textTertiary = AppColors.fogText;
  static const Color textDisabled = AppColors.pewterText;

  // --- Admin-specific semantic accents ---
  static const Color accent = KeroseneBrandTokens.brand;
  static const Color info = KeroseneBrandTokens.info;
  static const Color positive = KeroseneBrandTokens.success;
  static const Color warning = KeroseneBrandTokens.warning;
  static const Color negative = KeroseneBrandTokens.error;

  static const Color positiveSubtle = positive;
  static const Color warningSubtle = warning;
  static const Color negativeSubtle = negative;
  static const Color infoSubtle = info;
  static const Color accentSubtle = accent;

  // --- Admin-only: sidebar, table, chart ---
  static const Color sidebarBg = backgroundElevated;
  static const Color sidebarHover = surface;
  static const Color sidebarActive = surfaceHover;
  static const Color sidebarText = textSecondary;
  static const Color sidebarTextActive = textPrimary;

  static const Color tableHeader = surface;
  static const Color tableRowHover = surfaceHover;
  static const Color tableRowAlt = backgroundElevated;

  static const Color chartLine = accent;
  static const Color chartArea = accent;
  static const Color chartGrid = borderSubtle;

  static Color withAlpha(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
