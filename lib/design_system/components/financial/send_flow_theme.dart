import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Design tokens for financial send/receive wizards ([ThemeExtension]).
///
/// Rules encoded here (no magic values in feature widgets):
/// - Thumb-zone CTA dock + min touch 48
/// - Modular spacing 4 / 8 / 16 / 24 / 32 / 48
/// - Pill primary CTA (radius 999), input 14, card 24
/// - Tabular / mono financial type for amounts
class SendFlowTheme extends ThemeExtension<SendFlowTheme> {
  const SendFlowTheme({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.feedbackError,
    required this.feedbackSuccess,
    required this.feedbackWarning,
    required this.ctaForeground,
    required this.ctaBackground,
    required this.ctaDisabledBackground,
    required this.ctaDisabledForeground,
    required this.inputFocusRing,
    required this.cardShadow,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceSection,
    required this.minTouch,
    required this.ctaHeight,
    required this.radiusPill,
    required this.radiusInput,
    required this.radiusCard,
    required this.radiusPanel,
    required this.pagePadding,
    required this.thumbDockPadding,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color feedbackError;
  final Color feedbackSuccess;
  final Color feedbackWarning;
  final Color ctaForeground;
  final Color ctaBackground;
  final Color ctaDisabledBackground;
  final Color ctaDisabledForeground;
  final Color inputFocusRing;
  final List<BoxShadow> cardShadow;

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceSection;
  final double minTouch;
  final double ctaHeight;
  final double radiusPill;
  final double radiusInput;
  final double radiusCard;
  final double radiusPanel;
  final EdgeInsets pagePadding;
  final EdgeInsets thumbDockPadding;

  /// Dark send/receive flow defaults — aligns surfaceHigh with home card chrome.
  static SendFlowTheme dark() {
    return SendFlowTheme(
      background: KeroseneBrandTheme.dark.background,
      surface: KeroseneBrandTheme.dark.surface,
      surfaceHigh: HomeSurfaceTheme.dark.card,
      surfaceRaised: const Color(0xFF1A1D1F),
      border: HomeSurfaceTheme.dark.panelBorder,
      borderStrong: const Color(0xFF353B41),
      textPrimary: KeroseneBrandTheme.dark.textPrimary,
      textSecondary: KeroseneBrandTheme.dark.textSecondary,
      textMuted: KeroseneBrandTheme.dark.textMuted,
      accent: KeroseneBrandTokens.keroseneGold,
      feedbackError: KeroseneBrandTokens.error,
      feedbackSuccess: KeroseneBrandTokens.success,
      feedbackWarning: KeroseneBrandTokens.warning,
      ctaBackground: KeroseneBrandTheme.dark.textPrimary,
      ctaForeground: KeroseneBrandTheme.dark.background,
      ctaDisabledBackground:
          KeroseneBrandTheme.dark.surfaceHigh.withValues(alpha: 0.64),
      ctaDisabledForeground: KeroseneBrandTheme.dark.textMuted,
      inputFocusRing:
          KeroseneBrandTheme.dark.textPrimary.withValues(alpha: 0.28),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      spaceXs: AppSpacing.xs,
      spaceSm: AppSpacing.sm,
      spaceMd: AppSpacing.base,
      spaceLg: AppSpacing.xl2,
      spaceXl: AppSpacing.module,
      spaceSection: AppSpacing.section,
      minTouch: AppSpacing.minTouch,
      ctaHeight: AppSpacing.xxxl,
      radiusPill: 999,
      radiusInput: 14,
      radiusCard: 24,
      radiusPanel: 28,
      pagePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
      thumbDockPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.sm,
        AppSpacing.xl2,
        AppSpacing.xl2,
      ),
    );
  }

  /// Light send/receive flow — inverse of dark chrome; accents unchanged.
  static SendFlowTheme light() {
    final brand = KeroseneBrandTheme.light;
    return SendFlowTheme(
      background: brand.background,
      surface: brand.surface,
      surfaceHigh: HomeSurfaceTheme.light.card,
      surfaceRaised: HomeSurfaceTheme.light.card,
      border: HomeSurfaceTheme.light.panelBorder,
      borderStrong: const Color(0xFFC5C8C3),
      textPrimary: brand.textPrimary,
      textSecondary: brand.textSecondary,
      textMuted: brand.textMuted,
      accent: KeroseneBrandTokens.keroseneGold,
      feedbackError: KeroseneBrandTokens.error,
      feedbackSuccess: KeroseneBrandTokens.success,
      feedbackWarning: KeroseneBrandTokens.warning,
      ctaBackground: brand.textPrimary,
      ctaForeground: brand.textInverse,
      ctaDisabledBackground: brand.surfaceHigh.withValues(alpha: 0.64),
      ctaDisabledForeground: brand.textMuted,
      inputFocusRing: brand.textPrimary.withValues(alpha: 0.22),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
      spaceXs: AppSpacing.xs,
      spaceSm: AppSpacing.sm,
      spaceMd: AppSpacing.base,
      spaceLg: AppSpacing.xl2,
      spaceXl: AppSpacing.module,
      spaceSection: AppSpacing.section,
      minTouch: AppSpacing.minTouch,
      ctaHeight: AppSpacing.xxxl,
      radiusPill: 999,
      radiusInput: 14,
      radiusCard: 24,
      radiusPanel: 28,
      pagePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
      thumbDockPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.sm,
        AppSpacing.xl2,
        AppSpacing.xl2,
      ),
    );
  }

  static SendFlowTheme forVariant(Brightness brightness) {
    return brightness == Brightness.light ? light() : dark();
  }

  static SendFlowTheme of(BuildContext context) {
    return Theme.of(context).extension<SendFlowTheme>() ??
        forVariant(Theme.of(context).brightness);
  }

  BorderRadius get pillBorderRadius => BorderRadius.circular(radiusPill);
  BorderRadius get inputBorderRadius => BorderRadius.circular(radiusInput);
  BorderRadius get cardBorderRadius => BorderRadius.circular(radiusCard);
  BorderRadius get panelBorderRadius => BorderRadius.circular(radiusPanel);

  /// Hero amount (quantia / revisão).
  TextStyle amountHero({Color? color}) => AppTypography.financial(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.2,
        color: color ?? textPrimary,
      );

  /// Secondary monetary line (fiat reference, fee rows).
  TextStyle amountBody({Color? color, bool emphasize = false}) =>
      AppTypography.financial(
        fontSize: emphasize ? 16 : 14,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
        color: color ?? textPrimary,
      );

  TextStyle titleCard({Color? color}) => AppTypography.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.22,
        letterSpacing: -0.2,
        color: color ?? textPrimary,
      );

  TextStyle bodyReading({Color? color}) => AppTypography.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0,
        color: color ?? textSecondary,
      );

  TextStyle ctaLabel({Color? color}) => AppTypography.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.2,
        color: color ?? ctaForeground,
      );

  @override
  SendFlowTheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? feedbackError,
    Color? feedbackSuccess,
    Color? feedbackWarning,
    Color? ctaForeground,
    Color? ctaBackground,
    Color? ctaDisabledBackground,
    Color? ctaDisabledForeground,
    Color? inputFocusRing,
    List<BoxShadow>? cardShadow,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceSection,
    double? minTouch,
    double? ctaHeight,
    double? radiusPill,
    double? radiusInput,
    double? radiusCard,
    double? radiusPanel,
    EdgeInsets? pagePadding,
    EdgeInsets? thumbDockPadding,
  }) {
    return SendFlowTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      feedbackError: feedbackError ?? this.feedbackError,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
      feedbackWarning: feedbackWarning ?? this.feedbackWarning,
      ctaForeground: ctaForeground ?? this.ctaForeground,
      ctaBackground: ctaBackground ?? this.ctaBackground,
      ctaDisabledBackground:
          ctaDisabledBackground ?? this.ctaDisabledBackground,
      ctaDisabledForeground:
          ctaDisabledForeground ?? this.ctaDisabledForeground,
      inputFocusRing: inputFocusRing ?? this.inputFocusRing,
      cardShadow: cardShadow ?? this.cardShadow,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceSection: spaceSection ?? this.spaceSection,
      minTouch: minTouch ?? this.minTouch,
      ctaHeight: ctaHeight ?? this.ctaHeight,
      radiusPill: radiusPill ?? this.radiusPill,
      radiusInput: radiusInput ?? this.radiusInput,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPanel: radiusPanel ?? this.radiusPanel,
      pagePadding: pagePadding ?? this.pagePadding,
      thumbDockPadding: thumbDockPadding ?? this.thumbDockPadding,
    );
  }

  @override
  SendFlowTheme lerp(ThemeExtension<SendFlowTheme>? other, double t) {
    if (other is! SendFlowTheme) return this;
    return t < 0.5 ? this : other;
  }
}

/// Compatibility alias — SendFlowTheme is the canonical movement flow theme
/// for send, receive, and transfer wizards.
typedef MovementFlowTheme = SendFlowTheme;
