import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'monochrome_theme.dart';
import 'theme_token_bridge.dart';

/// Kerosene brand color tokens.
///
/// Dark hexes follow the Linear monochrome stack (5 levels of near-black).
/// Chrome colors resolve via [ThemeTokenBridge] / [KeroseneBrandTheme];
/// accents (gold, bitcoin, status) are shared.
class KeroseneBrandTokens {
  const KeroseneBrandTokens._();

  static Color get background => KeroseneBrandTheme.current.background;
  static Color get backgroundSoft => KeroseneBrandTheme.current.backgroundSoft;
  static Color get backgroundElevated =>
      KeroseneBrandTheme.current.backgroundElevated;

  static Color get surface => KeroseneBrandTheme.current.surface;
  static Color get surfaceHigh => KeroseneBrandTheme.current.surfaceHigh;
  static Color get surfaceElevated => KeroseneBrandTheme.current.surfaceElevated;
  static Color get surfaceMuted => KeroseneBrandTheme.current.surfaceMuted;

  static Color get border => KeroseneBrandTheme.current.border;
  static Color get borderStrong => KeroseneBrandTheme.current.borderStrong;
  static Color get borderSubtle => KeroseneBrandTheme.current.borderSubtle;

  static Color get textPrimary => KeroseneBrandTheme.current.textPrimary;
  static Color get textSecondary => KeroseneBrandTheme.current.textSecondary;
  static Color get textMuted => KeroseneBrandTheme.current.textMuted;
  static Color get textDisabled => KeroseneBrandTheme.current.textDisabled;
  static Color get textInverse => KeroseneBrandTheme.current.textInverse;

  static const Color brand = AppColors.hexFFD6A84F;
  static const Color bitcoin = AppColors.hexFFF59E0B;
  static const Color bitcoinOrange = bitcoin;
  static const Color amberDeep = AppColors.hexFF715128;

  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;
  static const Color info = AppColors.hexFF60A5FA;
  static const Color lightning = AppColors.hexFF7B61FF;

  static const Color railInternal = brand;
  static const Color railOnchain = bitcoinOrange;
  static const Color railLightning = lightning;
  static const Color railSettlement = success;
  static const Color railPending = warning;
  static const Color railFailed = error;

  static KeroseneBrandTheme resolve(BuildContext context) =>
      KeroseneBrandTheme.of(context);
}

/// Theme-aware brand chrome for movement / notifications / dialogs.
class KeroseneBrandTheme extends ThemeExtension<KeroseneBrandTheme> {
  const KeroseneBrandTheme({
    required this.background,
    required this.backgroundSoft,
    required this.backgroundElevated,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textInverse,
  });

  final Color background;
  final Color backgroundSoft;
  final Color backgroundElevated;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textInverse;

  Color get brand => KeroseneBrandTokens.brand;
  Color get bitcoin => KeroseneBrandTokens.bitcoin;
  Color get bitcoinOrange => KeroseneBrandTokens.bitcoinOrange;
  Color get success => KeroseneBrandTokens.success;
  Color get warning => KeroseneBrandTokens.warning;
  Color get error => KeroseneBrandTokens.error;
  Color get info => KeroseneBrandTokens.info;
  Color get lightning => KeroseneBrandTokens.lightning;
  Color get railInternal => KeroseneBrandTokens.railInternal;
  Color get railOnchain => KeroseneBrandTokens.railOnchain;
  Color get railLightning => KeroseneBrandTokens.railLightning;
  Color get railSettlement => KeroseneBrandTokens.railSettlement;
  Color get railPending => KeroseneBrandTokens.railPending;
  Color get railFailed => KeroseneBrandTokens.railFailed;

  /// Linear monochrome dark map — 5-level gray stack.
  static const KeroseneBrandTheme dark = KeroseneBrandTheme(
    background: AppColors.onyxCanvas,
    backgroundSoft: AppColors.carbonSurface,
    backgroundElevated: AppColors.graphiteSurface,
    surface: AppColors.carbonSurface,
    surfaceHigh: AppColors.carbonSurface,
    surfaceElevated: AppColors.graphiteSurface,
    surfaceMuted: AppColors.onyxCanvas,
    border: AppColors.smokeSurface,
    borderStrong: AppColors.ashBorder,
    borderSubtle: AppColors.smokeSurface,
    textPrimary: AppColors.snow,
    textSecondary: AppColors.mistText,
    textMuted: AppColors.fogText,
    textDisabled: AppColors.pewterText,
    textInverse: AppColors.onyxCanvas,
  );

  static const KeroseneBrandTheme light = KeroseneBrandTheme(
    background: Color(0xFFF7F7F5),
    backgroundSoft: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF0F1EE),
    surfaceElevated: Color(0xFFE8E9E4),
    surfaceMuted: Color(0xFFEDEDEA),
    border: Color(0xFFD9DAD6),
    borderStrong: Color(0xFFC4C6C0),
    borderSubtle: Color(0x1A181A17),
    textPrimary: Color(0xFF181A17),
    textSecondary: Color(0xFF62675F),
    textMuted: Color(0xFF8B9087),
    textDisabled: Color(0xFFA8ADA4),
    textInverse: Color(0xFFF7F7F5),
  );

  static KeroseneBrandTheme get current =>
      ThemeTokenBridge.isLight ? light : dark;

  static KeroseneBrandTheme of(BuildContext context) {
    return Theme.of(context).extension<KeroseneBrandTheme>() ?? current;
  }

  @override
  KeroseneBrandTheme copyWith({
    Color? background,
    Color? backgroundSoft,
    Color? backgroundElevated,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textInverse,
  }) {
    return KeroseneBrandTheme(
      background: background ?? this.background,
      backgroundSoft: backgroundSoft ?? this.backgroundSoft,
      backgroundElevated: backgroundElevated ?? this.backgroundElevated,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
    );
  }

  @override
  KeroseneBrandTheme lerp(ThemeExtension<KeroseneBrandTheme>? other, double t) {
    if (other is! KeroseneBrandTheme) return this;
    return KeroseneBrandTheme(
      background: Color.lerp(background, other.background, t)!,
      backgroundSoft: Color.lerp(backgroundSoft, other.backgroundSoft, t)!,
      backgroundElevated:
          Color.lerp(backgroundElevated, other.backgroundElevated, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
    );
  }
}

extension KeroseneThemeContext on BuildContext {
  KeroseneBrandTheme get brand => KeroseneBrandTheme.of(this);
  MonochromeColors get mono => MonochromeColors.of(this);
}
