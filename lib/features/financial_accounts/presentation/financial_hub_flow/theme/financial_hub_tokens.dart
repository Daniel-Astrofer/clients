import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Styling tokens for the Financial Hub flow.
///
/// Typography delegates to [AppTypography] (Playfair Display for titles,
/// Plus Jakarta Sans for body/numbers/descriptions). Color values come from
/// [KeroseneBrandTokens].
class FinancialHubTokens {
  const FinancialHubTokens._();

  // Typography - Titles (Playfair Display)
  static TextStyle titleH1({
    Color? color,
    double fontSize = 28.0,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = -0.5,
  }) {
    return AppTypography.playfairDisplay(
      color: color ?? textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle titleH2({
    Color? color,
    double fontSize = 22.0,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.3,
  }) {
    return AppTypography.playfairDisplay(
      color: color ?? textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // Typography - Body, Labels and Numbers (Plus Jakarta Sans)
  static TextStyle body({
    Color? color,
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.4,
  }) {
    return AppTypography.inter(
      color: color ?? textMuted,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle balanceAmount({
    Color? color,
    double fontSize = 36.0,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.8,
  }) {
    return AppTypography.inter(
      color: color ?? textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle numberText({
    Color? color,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.2,
  }) {
    return AppTypography.inter(
      color: color ?? textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle caption({
    Color? color,
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.1,
  }) {
    return AppTypography.inter(
      color: color ?? textMuted,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle buttonLabel({
    Color? color,
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return AppTypography.inter(
      color: color ?? textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  // Colors — resolve via brand chrome (ThemeTokenBridge).
  static Color get background => KeroseneBrandTokens.background;
  static Color get surface => KeroseneBrandTokens.surface;
  static Color get surfaceElevated => KeroseneBrandTokens.surfaceElevated;
  static Color get border => KeroseneBrandTokens.borderSubtle;
  static Color get textPrimary => KeroseneBrandTokens.textPrimary;
  static Color get textMuted => KeroseneBrandTokens.textMuted;
  static Color get accentGold => KeroseneBrandTokens.brand;
  /// Dark island for circular actions (icons stay light on this fill).
  static const Color circularButtonBg = Color(0xFF1E1E2C);
  static const Color circularButtonIcon = AppColors.hexFFFFFFFF;
}
