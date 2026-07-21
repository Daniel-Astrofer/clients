import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Styling tokens for the Financial Hub flow.
/// Uses Playfair Display for H1/Titles and Plus Jakarta Sans for body, labels, and numbers.
class FinancialHubTokens {
  const FinancialHubTokens._();

  // Typography - Titles (Playfair Display)
  static TextStyle titleH1({
    Color color = AppColors.hexFFFFFFFF,
    double fontSize = 28.0,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.playfairDisplay(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle titleH2({
    Color color = AppColors.hexFFFFFFFF,
    double fontSize = 22.0,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.playfairDisplay(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // Typography - Body, Labels and Numbers (Plus Jakarta Sans)
  static TextStyle body({
    Color color = AppColors.hexFFA1A1A1,
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.4,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle balanceAmount({
    Color color = AppColors.hexFFFFFFFF,
    double fontSize = 36.0,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.8,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle numberText({
    Color color = AppColors.hexFFFFFFFF,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle caption({
    Color color = AppColors.hexFFA1A1A1,
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0.1,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle buttonLabel({
    Color color = AppColors.hexFFFFFFFF,
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.plusJakartaSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  // Colors
  static const Color background = AppColors.hexFF000000;
  static const Color surface = AppColors.hexFF121212;
  static const Color surfaceElevated = AppColors.hexFF1E1E1E;
  static const Color border = Color(0x1FFFFFFF);
  static const Color textPrimary = AppColors.hexFFFFFFFF;
  static const Color textMuted = AppColors.hexFFA1A1A1;
  static const Color accentGold = KeroseneBrandTokens.brand;
  static const Color circularButtonBg = Color(0xFF1E1E2C);
  static const Color circularButtonIcon = AppColors.hexFFFFFFFF;
}
