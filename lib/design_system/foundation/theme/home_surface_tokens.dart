import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';

/// Home surface tokens.
///
/// Dark OLED hexes stay frozen. Prefer [HomeSurfaceTheme] / getters for UI.
abstract final class HomeSurfaceTokens {
  static Color get background => HomeSurfaceTheme.current.background;
  static Color get card => HomeSurfaceTheme.current.card;
  static Color get panelTop => HomeSurfaceTheme.current.panelTop;
  static Color get panelBottom => HomeSurfaceTheme.current.panelBottom;
  static Color get panelBorder => HomeSurfaceTheme.current.panelBorder;
  static Color get mutedText => HomeSurfaceTheme.current.mutedText;
  static const Color amber = KeroseneBrandTokens.bitcoin;
  static const Color positive = AppColors.hexFF4ADE80;

  static Color get textPrimary => HomeSurfaceTheme.current.textPrimary;
  static Color get textSecondary => HomeSurfaceTheme.current.textSecondary;
  static Color get textMuted => HomeSurfaceTheme.current.textMuted;
  static Color get surfaceBorder => HomeSurfaceTheme.current.surfaceBorder;
  static Color get surfaceDim => HomeSurfaceTheme.current.surfaceDim;
  static Color get overlayDim => HomeSurfaceTheme.current.overlayDim;

  static const double radiusSmall = 8.0;
  static const double radiusCard = 18.0;
  static const double radiusPanel = 28.0;

  static const double densityScale = 1.0;

  static double size(double value) => value * densityScale;
  static double fontSize(double value) => value;

  static TextStyle get title => HomeSurfaceTheme.current.title;
  static TextStyle get body => HomeSurfaceTheme.current.body;
  static TextStyle get label => HomeSurfaceTheme.current.label;

  static HomeSurfaceTheme resolve(BuildContext context) =>
      HomeSurfaceTheme.of(context);
}

/// Theme-aware home surface (inverse of OLED dark).
class HomeSurfaceTheme extends ThemeExtension<HomeSurfaceTheme> {
  const HomeSurfaceTheme({
    required this.background,
    required this.card,
    required this.panelTop,
    required this.panelBottom,
    required this.panelBorder,
    required this.mutedText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.surfaceBorder,
    required this.surfaceDim,
    required this.overlayDim,
  });

  final Color background;
  final Color card;
  final Color panelTop;
  final Color panelBottom;
  final Color panelBorder;
  final Color mutedText;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color surfaceBorder;
  final Color surfaceDim;
  final Color overlayDim;

  Color get amber => HomeSurfaceTokens.amber;
  Color get positive => HomeSurfaceTokens.positive;

  static final HomeSurfaceTheme dark = HomeSurfaceTheme(
    background: AppColors.hexFF000000,
    card: AppColors.hexFF141517,
    panelTop: AppColors.hexFF1A1A1A,
    panelBottom: AppColors.hexFF121212,
    panelBorder: AppColors.hexFF2A2A2A,
    mutedText: AppColors.hexFFA3A3A3,
    textPrimary: Colors.white,
    textSecondary: Colors.white.withValues(alpha: 0.62),
    textMuted: Colors.white.withValues(alpha: 0.42),
    surfaceBorder: Colors.white.withValues(alpha: 0.08),
    surfaceDim: Colors.white.withValues(alpha: 0.06),
    overlayDim: Colors.black.withValues(alpha: 0.5),
  );

  static final HomeSurfaceTheme light = HomeSurfaceTheme(
    background: const Color(0xFFF7F7F5),
    card: const Color(0xFFFFFFFF),
    panelTop: const Color(0xFFFFFFFF),
    panelBottom: const Color(0xFFF0F1EE),
    panelBorder: const Color(0xFFD9DAD6),
    mutedText: const Color(0xFF8B9087),
    textPrimary: const Color(0xFF181A17),
    textSecondary: const Color(0xFF62675F),
    textMuted: const Color(0xFF8B9087),
    surfaceBorder: const Color(0x1A181A17),
    surfaceDim: const Color(0x0F181A17),
    overlayDim: Colors.black.withValues(alpha: 0.28),
  );

  static HomeSurfaceTheme get current =>
      ThemeTokenBridge.isLight ? light : dark;

  static HomeSurfaceTheme of(BuildContext context) {
    return Theme.of(context).extension<HomeSurfaceTheme>() ?? current;
  }

  TextStyle get title => AppTypography.h3.copyWith(
        color: textPrimary,
        height: 1.1,
      );

  TextStyle get body => AppTypography.bodyMedium.copyWith(
        color: textSecondary,
      );

  TextStyle get label => AppTypography.label.copyWith(
        color: textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      );

  @override
  HomeSurfaceTheme copyWith({
    Color? background,
    Color? card,
    Color? panelTop,
    Color? panelBottom,
    Color? panelBorder,
    Color? mutedText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? surfaceBorder,
    Color? surfaceDim,
    Color? overlayDim,
  }) {
    return HomeSurfaceTheme(
      background: background ?? this.background,
      card: card ?? this.card,
      panelTop: panelTop ?? this.panelTop,
      panelBottom: panelBottom ?? this.panelBottom,
      panelBorder: panelBorder ?? this.panelBorder,
      mutedText: mutedText ?? this.mutedText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      overlayDim: overlayDim ?? this.overlayDim,
    );
  }

  @override
  HomeSurfaceTheme lerp(ThemeExtension<HomeSurfaceTheme>? other, double t) {
    if (other is! HomeSurfaceTheme) return this;
    return HomeSurfaceTheme(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      panelTop: Color.lerp(panelTop, other.panelTop, t)!,
      panelBottom: Color.lerp(panelBottom, other.panelBottom, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      overlayDim: Color.lerp(overlayDim, other.overlayDim, t)!,
    );
  }
}

// --- Compatibility aliases ---

Color get homeBackgroundColor => HomeSurfaceTokens.background;
Color get homeCardColor => HomeSurfaceTokens.card;
Color get homePanelTopColor => HomeSurfaceTokens.panelTop;
Color get homePanelBottomColor => HomeSurfaceTokens.panelBottom;
Color get homePanelBorderColor => HomeSurfaceTokens.panelBorder;
Color get homeMutedTextColor => HomeSurfaceTokens.mutedText;
const Color homeAmberColor = HomeSurfaceTokens.amber;
const Color homePositiveColor = HomeSurfaceTokens.positive;

const double homeDensityScale = HomeSurfaceTokens.densityScale;
double homeSize(double value) => HomeSurfaceTokens.size(value);
double homeFontSize(double value) => HomeSurfaceTokens.fontSize(value);

abstract class HomeColors {
  static Color get textPrimary => HomeSurfaceTokens.textPrimary;
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

extension HomeSurfaceThemeContext on BuildContext {
  HomeSurfaceTheme get homeSurface => HomeSurfaceTheme.of(this);
}
