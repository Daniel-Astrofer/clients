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

  // --- radii ---
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusCard = 18.0;
  static const double radiusPanel = 28.0;

  static const double densityScale = 1.0;

  static double size(double value) => value * densityScale;
  static double fontSize(double value) => value;

  // --- type scale (canonical for all home sections) ---
  static double get sectionTitleSize => fontSize(22);
  static double get cardTitleSize => fontSize(18);
  static double get bodySize => fontSize(14);
  static double get captionSize => fontSize(12);
  static double get smallLabelSize => fontSize(10);

  static TextStyle get title => HomeSurfaceTheme.current.title;
  static TextStyle get body => HomeSurfaceTheme.current.body;
  static TextStyle get label => HomeSurfaceTheme.current.label;

  static HomeSurfaceTheme resolve(BuildContext context) =>
      HomeSurfaceTheme.of(context);
}

/// Centralized motion tokens for the home screen.
///
/// Every entrance / reveal / stagger animation must use these constants so the
/// home screen shares a single motion language.
abstract final class HomeMotion {
  /// Default entrance duration for sections cascading in.
  static const Duration entrance = Duration(milliseconds: 600);

  /// Stagger delay between sibling items (rows, cards, chips).
  static const Duration stagger = Duration(milliseconds: 50);

  /// Default reveal curve (soft settle — less abrupt than easeOutCubic).
  static const Curve curve = Curves.easeOutQuart;

  /// Curve for panel / chart reveals (draw-on effect).
  static const Curve revealCurve = Curves.easeInOutCubic;

  /// Short transition (cross-fade, chip toggle).
  static const Duration short = Duration(milliseconds: 280);

  /// Medium transition (card swap, view change).
  static const Duration medium = Duration(milliseconds: 480);

  /// Long reveal (initial load cascade).
  static const Duration long = Duration(milliseconds: 800);

  /// Fixed aurora band height as fraction of screen height.
  ///
  /// The band ends around the middle of the balance hero. The balance
  /// itself remains in the scroll view; only this background is pinned.
  static const double auroraBandFraction = 0.42;

  /// Veil gradient stops (covers ~0 → 1 from aurora bottom toward feed).
  static const List<double> veilStops = [0.0, 0.22, 0.48, 0.74, 1.0];

  /// Veil height as fraction of screen height.
  static const double veilHeightFraction = 0.14;
}

/// Theme-adaptive accent palette for ledger balance views.
///
/// Avoids hard-coded hex that clash with light mode.
abstract final class HomeBalanceAccents {
  static Color total(bool isLight) =>
      isLight ? const Color(0xFF1A1A1A) : Colors.white;

  static Color platform(bool isLight) =>
      isLight ? const Color(0xFF0055FF) : Colors.white;

  static Color onChain(bool isLight) =>
      isLight ? const Color(0xFFE67E00) : const Color(0xFFFF9500);

  static Color cold(bool isLight) =>
      isLight ? const Color(0xFF0284C7) : const Color(0xFF7DD3FC);
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
  static const double medium = HomeSurfaceTokens.radiusMedium;
  static const double card = HomeSurfaceTokens.radiusCard;
  static const double panel = HomeSurfaceTokens.radiusPanel;
}

abstract class HomeTypography {
  // --- existing size tokens (numeric only, for compat) ---
  static double get sectionTitleSize => HomeSurfaceTokens.sectionTitleSize;
  static double get cardTitleSize => HomeSurfaceTokens.cardTitleSize;
  static double get bodySize => HomeSurfaceTokens.bodySize;
  static double get captionSize => HomeSurfaceTokens.captionSize;
  static double get smallLabelSize => HomeSurfaceTokens.smallLabelSize;

  // --- existing opaque text styles (color-aware via HomeSurfaceTheme) ---
  static TextStyle get title => HomeSurfaceTokens.title;
  static TextStyle get body => HomeSurfaceTokens.body;
  static TextStyle get label => HomeSurfaceTokens.label;

  // ============================================================
  // SEMANTIC TEXT STYLES
  //
  // Every screen references these instead of composing inline.
  // To change Playfair weight globally, edit the w200 here.
  // To resize all section titles, edit sectionTitleSize above.
  // ============================================================

  // -- Playfair Display (serif) --

  /// Section header: "Atividades recentes", "Distribuição de fundos", etc.
  static TextStyle sectionHeader({Color? color}) =>
      AppTypography.newsreader(
        color: color,
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w200,
        height: 1.15,
        letterSpacing: 0,
      );

  /// Card title: education cards, setup notices.
  static TextStyle cardHeader({Color? color}) =>
      AppTypography.newsreader(
        color: color,
        fontSize: cardTitleSize,
        fontWeight: FontWeight.w200,
        height: 1.1,
        letterSpacing: 0,
      );

  /// Large hero title: onboarding, welcome, statement.
  static TextStyle heroTitle({Color? color, double fontSize = 32}) =>
      AppTypography.newsreader(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w200,
        height: 1.12,
        letterSpacing: 0,
      );

  // -- Plus Jakarta Sans (body / labels) --

  /// Date / group headers: "Hoje", "Ontem", section labels like "TOTAL".
  static TextStyle dateHeader({Color? color}) =>
      AppTypography.label.copyWith(
        color: color,
        fontSize: captionSize,
        letterSpacing: 1.0,
      );

  /// Filter / status chip label.
  static TextStyle filterChip({Color? color}) =>
      AppTypography.label.copyWith(
        color: color,
        fontSize: captionSize,
        fontWeight: FontWeight.w300,
        letterSpacing: 0,
      );

  /// Body text: descriptions, empty states.
  static TextStyle bodyText({Color? color}) =>
      AppTypography.bodyMedium.copyWith(
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      );

  /// Small caption / meta text.
  static TextStyle caption({Color? color}) =>
      AppTypography.bodySmall.copyWith(
        color: color,
        fontSize: captionSize,
        letterSpacing: 0,
        height: 1.4,
      );

  // -- Amounts (Plus Jakarta Sans + tabular) --

  /// Balance hero (BTC total).
  static TextStyle balanceHero({Color? color}) =>
      AppTypography.homeBalance(color: color);

  /// Transaction amount row.
  static TextStyle transactionAmount({Color? color}) =>
      AppTypography.homeBalance(color: color).copyWith(
        fontSize: bodySize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      );

  /// Converted fiat reference below balance hero.
  static TextStyle convertedAmount({Color? color}) =>
      AppTypography.bodyMedium.copyWith(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w300,
        letterSpacing: 0,
      );

  // -- Buttons --

  /// Primary / action button label (matches AppTypography.buttonText).
  static TextStyle buttonLabel({Color? color}) =>
      AppTypography.buttonText.copyWith(color: color);
}

extension HomeSurfaceThemeContext on BuildContext {
  HomeSurfaceTheme get homeSurface => HomeSurfaceTheme.of(this);
}
