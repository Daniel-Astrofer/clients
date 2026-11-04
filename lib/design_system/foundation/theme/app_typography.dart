import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Kerosene Typography System.
///
/// This is the only mobile-app layer allowed to call GoogleFonts directly.
/// Feature code must consume these tokens or Theme.of(context).textTheme.
///
/// Brand direction (Linear-inspired):
/// - Display / hero / H1: Moderat Mono, weight 400.
/// - UI / section hierarchy / descriptions: Aeonik Pro, weight 300–400.
/// - Numbers, editable transaction amounts and Home balance: Aeonik Pro weight 500 with tabular figures.
/// - Hashes and technical IDs: JetBrains Mono.
///
/// Lighter signature weights for a crisp, refined rhythm.
/// Negative letter-spacing tightens rhythm at every size.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Aeonik Pro';
  static const String bodyFontFamily = fontFamily;
  static const String displayFontFamily = 'Aeonik Pro';
  static const String titleFontFamily = displayFontFamily;
  static const String monoFontFamily = 'Moderat Mono';
  static const String numericFontFamily = fontFamily;
  static const String financialFontFamily = monoFontFamily;

  // Temporary aliases retained while older widgets migrate names.
  // New code should prefer displayFontFamily or financialFontFamily.
  static const String serifFontFamily = displayFontFamily;
  static const String sansHebrewFontFamily = financialFontFamily;

  // ─── Variable Typography Weights (Harmonically Distributed) ──
  // Follows standard human-centered design scales (Apple HIG, Material 3, Linear):
  // - w300: Light (delicate accents, subtle watermarks)
  // - w400: Regular (standard reading body, descriptions, lists, forms)
  // - w500: Medium (interactive controls, chips, navigation, card headers)
  // - w510: Medium (Linear signature - section titles, sub-hero titles)
  // - w590: SemiBold (Linear signature - H1, prominent headings, key amounts)
  // - w700: Bold (hero display, key financial callouts)
  static const FontWeight w300 = FontWeight.w300;
  static const FontWeight w400 = FontWeight.w400;
  static const FontWeight w500 = FontWeight.w500;
  static const FontWeight w510 = FontWeight.w500;
  static const FontWeight w590 = FontWeight.w600;
  static const FontWeight w700 = FontWeight.w700;

  static TextTheme aeonikProTextTheme(TextTheme textTheme) {
    return textTheme.apply(fontFamily: 'Aeonik Pro');
  }

  static TextTheme moderatMonoTextTheme(TextTheme textTheme) {
    return textTheme.apply(fontFamily: 'Moderat Mono');
  }

  static TextTheme plusJakartaSansTextTheme(TextTheme textTheme) {
    return aeonikProTextTheme(textTheme);
  }

  // ─────────────────────────────────────────────────────────────
  // Display / hero / H1
  // Usage: main screens, onboarding, hero, large calls, page titles.
  // Aeonik Pro, weight 600–700.
  // Letter spacing scales with size for optical perfection.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle display = playfairDisplay(
    fontSize: 40,
    fontWeight: w590,
    height: 1.08,
    letterSpacing: -0.9,
  );

  static final TextStyle displayLarge = playfairDisplay(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.04,
    letterSpacing: -1.2,
  );

  static final TextStyle displayWeb = playfairDisplay(
    fontSize: 64,
    fontWeight: FontWeight.w700,
    height: 1.04,
    letterSpacing: -1.5,
  );

  static final TextStyle displayWebLarge = playfairDisplay(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    height: 1.02,
    letterSpacing: -1.8,
  );

  // Compatibility aliases.
  static final TextStyle h1 = playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.18,
    letterSpacing: -0.6,
  );
  static final TextStyle h1Web = displayWeb;

  // ─────────────────────────────────────────────────────────────
  // H2 — heading
  // Usage: section titles.
  // Aeonik Pro, weight 600, 28px.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle h2 = inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static final TextStyle h2Small = inter(
    fontSize: 24,
    fontWeight: w510,
    height: 1.2,
    letterSpacing: -0.288,
  );

  static final TextStyle h2Web = inter(
    fontSize: 40,
    fontWeight: w510,
    height: 1.12,
    letterSpacing: -0.52,
  );

  static final TextStyle h2WebLarge = inter(
    fontSize: 44,
    fontWeight: w510,
    height: 1.12,
    letterSpacing: -0.572,
  );

  // ─────────────────────────────────────────────────────────────
  // H3 — heading-sm
  // Usage: cards, blocks and subtitles.
  // Plus Jakarta Sans, weight 510, 20–24px.
  // Letter spacing: -0.012em * 24 = -0.288px.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle h3 = inter(
    fontSize: 24,
    fontWeight: w510,
    height: 1.18,
    letterSpacing: -0.288,
  );

  static final TextStyle h3Small = inter(
    fontSize: 20,
    fontWeight: w510,
    height: 1.18,
    letterSpacing: -0.24,
  );

  static final TextStyle h3Large = inter(
    fontSize: 22,
    fontWeight: w510,
    height: 1.18,
    letterSpacing: -0.264,
  );

  // ─────────────────────────────────────────────────────────────
  // Description / body
  // Usage: descriptions, long text, explanations.
  // Plus Jakarta Sans, weight 400, 15–17px, line height 1.5–1.6.
  // Letter spacing: -0.010em = -0.15px at 15px.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle bodyLarge = inter(
    fontSize: 17,
    fontWeight: w400,
    height: 1.55,
    letterSpacing: -0.17,
  );

  static final TextStyle bodyMedium = inter(
    fontSize: 15,
    fontWeight: w400,
    height: 1.5,
    letterSpacing: -0.15,
  );

  static final TextStyle bodySmall = inter(
    fontSize: 13,
    fontWeight: w400,
    height: 1.45,
    letterSpacing: -0.13,
  );

  static final TextStyle description = inter(
    fontSize: 16,
    fontWeight: w400,
    height: 1.55,
    letterSpacing: -0.16,
  );

  static final TextStyle descriptionStrong = inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: -0.16,
  );

  // ─────────────────────────────────────────────────────────────
  // Caption / metadata
  // Usage: dates, labels, secondary status.
  // Plus Jakarta Sans, weight 400, 12–13px, line height 1.6.
  // Letter spacing: -0.01em = -0.12px at 12px.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle caption = inter(
    fontSize: 12,
    fontWeight: w400,
    height: 1.6,
    letterSpacing: -0.12,
  );

  static final TextStyle captionLarge = inter(
    fontSize: 13,
    fontWeight: w400,
    height: 1.6,
    letterSpacing: -0.13,
  );

  static final TextStyle label = inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.1,
  );

  static final TextStyle buttonText = inter(
    fontSize: 14,
    fontWeight: w510,
    height: 1.15,
    letterSpacing: -0.14,
  );

  // ─────────────────────────────────────────────────────────────
  // Financial values
  // Usage: balances, transaction amounts, fees, BTC/sats breakdowns.
  // Plus Jakarta Sans weight 590, 3px tracking, tabular figures.
  // ─────────────────────────────────────────────────────────────

  static final TextStyle number = inter(
    fontSize: 18,
    fontWeight: w590,
    letterSpacing: 3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle amount = inter(
    fontSize: 32,
    fontWeight: w590,
    height: 1.08,
    letterSpacing: 3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle amountLarge = inter(
    fontSize: 40,
    fontWeight: w590,
    height: 1.05,
    letterSpacing: 3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle amountSmall = inter(
    fontSize: 16,
    fontWeight: w590,
    height: 1.12,
    letterSpacing: 3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle mono = financial(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static TextStyle amountInput({
    required bool isBtc,
    Color? color,
  }) {
    return inter(
      fontSize: isBtc ? 48 : 56,
      fontWeight: w590,
      color: color ?? AppColors.textPrimary,
      height: 1.02,
      letterSpacing: 3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle homeBalance({
    Color? color,
  }) {
    return inter(
      fontSize: 48,
      fontWeight: w500,
      color: color ?? AppColors.textPrimary,
      height: 1.02,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle financial({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return ibmPlexMono(
      textStyle: textStyle,
      color: color ?? textStyle?.color,
      fontSize: fontSize ?? textStyle?.fontSize,
      fontWeight: fontWeight ?? textStyle?.fontWeight ?? FontWeight.w500,
      height: height ?? textStyle?.height ?? 1.08,
      letterSpacing: letterSpacing ?? textStyle?.letterSpacing ?? 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle technicalMono({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return financial(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Aeonik Pro — primary UI font (body, labels, buttons, numbers).
  static TextStyle aeonikPro({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final base = textStyle ?? const TextStyle();
    return base.copyWith(
      fontFamily: fontFamily,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Moderat Mono — technical monospace, hashes, invoices and badges.
  static TextStyle moderatMono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final base = textStyle ?? const TextStyle();
    return base.copyWith(
      fontFamily: 'Moderat Mono',
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle plusJakartaSans({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) =>
      inter(
        textStyle: textStyle,
        color: color,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        textBaseline: textBaseline,
        height: height,
        locale: locale,
        foreground: foreground,
        background: background,
        shadows: shadows,
        fontFeatures: fontFeatures,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        decorationThickness: decorationThickness,
      );

  /// Alias: [aeonikPro] — named `inter` for legacy compatibility.
  static TextStyle inter({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return aeonikPro(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Alias: [aeonikPro] — named `playfairDisplay` for legacy compatibility.
  /// Renders primary display / hero / H1 in Aeonik Pro.
  static TextStyle playfairDisplay({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return aeonikPro(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Alias: [aeonikPro] — Aeonik Pro covers display/hero.
  static TextStyle newsreader({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return aeonikPro(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle ibmPlexMono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return moderatMono(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}
