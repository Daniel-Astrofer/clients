import 'package:flutter/material.dart';
import 'package:kerosene/design_system/colors.dart';
import 'package:kerosene/design_system/typography.dart';


// --- Base Constants (Migrated from home_screen.dart) ---
const Color homeBackgroundColor = AppColors.hexFF000000;
const Color homeCardColor = AppColors.hexFF141517;
const Color homePanelTopColor = AppColors.hexFF1A1A1A;
const Color homePanelBottomColor = AppColors.hexFF121212;
const Color homePanelBorderColor = AppColors.hexFF2A2A2A;
const Color homeMutedTextColor = AppColors.hexFFA3A3A3;
const Color homeAmberColor = AppColors.hexFFF59E0B;
const Color homePositiveColor = AppColors.hexFF4ADE80;

const double homeDensityScale = 1.0;
double homeSize(double value) => value * homeDensityScale;
double homeFontSize(double value) => value;

// --- New Single Source of Truth Tokens ---

abstract class HomeColors {
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withValues(alpha: 0.62);
  static final Color textMuted = Colors.white.withValues(alpha: 0.42);
  static final Color surfaceBorder = Colors.white.withValues(alpha: 0.08);
  static final Color surfaceDim = Colors.white.withValues(alpha: 0.06);
  static final Color overlayDim = Colors.black.withValues(alpha: 0.5);
}

abstract class HomeRadius {
  static const double small = 8.0;
  static const double card = 18.0;
  static const double panel = 28.0;
}

abstract class HomeTypography {
  static TextStyle get title => AppTypography.h3.copyWith(
        color: HomeColors.textPrimary,
        height: 1.1,
      );
      
  static TextStyle get body => AppTypography.bodyMedium.copyWith(
        color: HomeColors.textSecondary,
      );
      
  static TextStyle get label => AppTypography.label.copyWith(
        color: HomeColors.textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      );
}
