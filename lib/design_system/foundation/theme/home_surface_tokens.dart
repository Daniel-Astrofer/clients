import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Home OLED surface tokens (single source of truth in the design system).
abstract final class HomeSurfaceTokens {
  static const Color background = AppColors.hexFF000000;
  static const Color card = AppColors.hexFF141517;
  static const Color panelTop = AppColors.hexFF1A1A1A;
  static const Color panelBottom = AppColors.hexFF121212;
  static const Color panelBorder = AppColors.hexFF2A2A2A;
  static const Color mutedText = AppColors.hexFFA3A3A3;
  static const Color amber = KeroseneBrandTokens.bitcoin;
  static const Color positive = AppColors.hexFF4ADE80;

  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withValues(alpha: 0.62);
  static final Color textMuted = Colors.white.withValues(alpha: 0.42);
  static final Color surfaceBorder = Colors.white.withValues(alpha: 0.08);
  static final Color surfaceDim = Colors.white.withValues(alpha: 0.06);
  static final Color overlayDim = Colors.black.withValues(alpha: 0.5);

  static const double radiusSmall = 8.0;
  static const double radiusCard = 18.0;
  static const double radiusPanel = 28.0;

  static const double densityScale = 1.0;

  static double size(double value) => value * densityScale;
  static double fontSize(double value) => value;

  static TextStyle get title => AppTypography.h3.copyWith(
        color: textPrimary,
        height: 1.1,
      );

  static TextStyle get body => AppTypography.bodyMedium.copyWith(
        color: textSecondary,
      );

  static TextStyle get label => AppTypography.label.copyWith(
        color: textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      );
}

// --- Compatibility aliases (prefer [HomeSurfaceTokens]) ---

const Color homeBackgroundColor = HomeSurfaceTokens.background;
const Color homeCardColor = HomeSurfaceTokens.card;
const Color homePanelTopColor = HomeSurfaceTokens.panelTop;
const Color homePanelBottomColor = HomeSurfaceTokens.panelBottom;
const Color homePanelBorderColor = HomeSurfaceTokens.panelBorder;
const Color homeMutedTextColor = HomeSurfaceTokens.mutedText;
const Color homeAmberColor = HomeSurfaceTokens.amber;
const Color homePositiveColor = HomeSurfaceTokens.positive;

const double homeDensityScale = HomeSurfaceTokens.densityScale;
double homeSize(double value) => HomeSurfaceTokens.size(value);
double homeFontSize(double value) => HomeSurfaceTokens.fontSize(value);

abstract class HomeColors {
  static const Color textPrimary = HomeSurfaceTokens.textPrimary;
  static Color get textSecondary => HomeSurfaceTokens.textSecondary;
  static Color get textMuted => HomeSurfaceTokens.textMuted;
  static Color get surfaceBorder => HomeSurfaceTokens.surfaceBorder;
  static Color get surfaceDim => HomeSurfaceTokens.surfaceDim;
  static Color get overlayDim => HomeSurfaceTokens.overlayDim;
}

abstract class HomeRadius {
  static const double small = HomeSurfaceTokens.radiusSmall;
  static const double card = HomeSurfaceTokens.radiusCard;
  static const double panel = HomeSurfaceTokens.radiusPanel;
}

abstract class HomeTypography {
  static TextStyle get title => HomeSurfaceTokens.title;
  static TextStyle get body => HomeSurfaceTokens.body;
  static TextStyle get label => HomeSurfaceTokens.label;
}
