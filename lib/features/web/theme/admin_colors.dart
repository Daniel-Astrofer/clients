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

  // --- Delegates to KeroseneBrandTheme.dark ---
  static Color get background => KeroseneBrandTheme.dark.background;
  static Color get backgroundElevated => KeroseneBrandTheme.dark.backgroundSoft;
  static Color get surface => KeroseneBrandTheme.dark.surface;
  static Color get surfaceElevated => KeroseneBrandTheme.dark.surfaceElevated;
  static Color get surfaceHover => KeroseneBrandTheme.dark.surfaceHigh;

  static Color get borderSubtle => KeroseneBrandTheme.dark.borderSubtle;
  static Color get border => KeroseneBrandTheme.dark.border;
  static Color get borderStrong => KeroseneBrandTheme.dark.borderStrong;

  static Color get textPrimary => KeroseneBrandTheme.dark.textPrimary;
  static Color get textSecondary => KeroseneBrandTheme.dark.textSecondary;
  static Color get textTertiary => KeroseneBrandTheme.dark.textMuted;
  static Color get textDisabled => KeroseneBrandTheme.dark.textDisabled;

  // --- Admin-specific semantic accents ---
  static Color get accent => KeroseneBrandTokens.brand;
  static Color get info => KeroseneBrandTokens.info;
  static Color get positive => KeroseneBrandTokens.success;
  static Color get warning => KeroseneBrandTokens.warning;
  static Color get negative => KeroseneBrandTokens.error;

  static Color get positiveSubtle => positive;
  static Color get warningSubtle => warning;
  static Color get negativeSubtle => negative;
  static Color get infoSubtle => info;
  static Color get accentSubtle => accent;

  // --- Admin-only: sidebar, table, chart ---
  static Color get sidebarBg => backgroundElevated;
  static Color get sidebarHover => surface;
  static Color get sidebarActive => surfaceHover;
  static Color get sidebarText => textSecondary;
  static Color get sidebarTextActive => textPrimary;

  static Color get tableHeader => surface;
  static Color get tableRowHover => surfaceHover;
  static Color get tableRowAlt => backgroundElevated;

  static Color get chartLine => accent;
  static Color get chartArea => accent;
  static Color get chartGrid => borderSubtle;

  static Color withAlpha(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
