import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

import 'admin_colors.dart';

/// Kerosene Enterprise — Typography Scale.
/// Delegates to [AppTypography] for font families and base styles.
/// Admin-specific styles (mono, metric, table) are defined here.
class AdminTypography {
  AdminTypography._();

  static const String fontFamily = AppTypography.bodyFontFamily;
  static const String titleFontFamily = AppTypography.displayFontFamily;
  static const String monoFontFamily = AppTypography.monoFontFamily;

  // --- Playfair Display titles ---
  static final TextStyle displayLarge = AppTypography.playfairDisplay(
    fontSize: 48,
    color: AdminColors.textPrimary,
    height: 1.1,
  );

  static final TextStyle displayMedium = AppTypography.playfairDisplay(
    fontSize: 36,
    color: AdminColors.textPrimary,
    height: 1.15,
  );

  static final TextStyle h1 = AppTypography.playfairDisplay(
    fontSize: 28,
    color: AdminColors.textPrimary,
    height: 1.2,
  );

  static final TextStyle h2 = AppTypography.playfairDisplay(
    fontSize: 22,
    color: AdminColors.textPrimary,
    height: 1.25,
  );

  static final TextStyle h3 = AppTypography.playfairDisplay(
    fontSize: 18,
    color: AdminColors.textPrimary,
    height: 1.3,
  );

  static final TextStyle h4 = AppTypography.playfairDisplay(
    fontSize: 15,
    color: AdminColors.textPrimary,
    height: 1.35,
  );

  // --- Plus Jakarta Sans body ---
  static final TextStyle bodyLarge = AppTypography.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
    height: 1.5,
  );

  static final TextStyle bodyMedium = AppTypography.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AdminColors.textSecondary,
    height: 1.5,
  );

  static final TextStyle bodySmall = AppTypography.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AdminColors.textTertiary,
    height: 1.4,
  );

  static final TextStyle label = AppTypography.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AdminColors.textTertiary,
    height: 1.3,
  );

  static final TextStyle caption = AppTypography.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AdminColors.textTertiary,
    height: 1.3,
  );

  // --- JetBrains Mono (admin metrics) ---
  static final TextStyle metric = AppTypography.financial(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
    color: AdminColors.textPrimary,
  );

  static final TextStyle metricSmall = AppTypography.financial(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: AdminColors.textPrimary,
  );

  static final TextStyle mono = AppTypography.mono.copyWith(
    color: AdminColors.textSecondary,
  );

  // --- Buttons ---
  static final TextStyle button = AppTypography.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  );

  static final TextStyle buttonSmall = AppTypography.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AdminColors.textSecondary,
  );

  // --- Table ---
  static final TextStyle tableHeader = AppTypography.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AdminColors.textTertiary,
    height: 1.3,
  );

  static final TextStyle tableCell = AppTypography.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AdminColors.textPrimary,
    height: 1.4,
  );

  static final TextStyle tableCellMono = AppTypography.financial(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AdminColors.textPrimary,
  );
}
