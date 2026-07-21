import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Design tokens for financial send / transfer wizards ([ThemeExtension]).
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
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
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
    required this.pagePadding,
    required this.thumbDockPadding,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
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
  final EdgeInsets pagePadding;
  final EdgeInsets thumbDockPadding;

  /// Dark send-flow defaults (current product surface).
  static SendFlowTheme dark() {
    return SendFlowTheme(
      background: KeroseneBrandTokens.background,
      surface: KeroseneBrandTokens.surface,
      surfaceHigh: KeroseneBrandTokens.surfaceHigh,
      border: KeroseneBrandTokens.border,
      textPrimary: KeroseneBrandTokens.textPrimary,
      textSecondary: KeroseneBrandTokens.textSecondary,
      textMuted: KeroseneBrandTokens.textMuted,
      feedbackError: KeroseneBrandTokens.error,
      feedbackSuccess: KeroseneBrandTokens.success,
      feedbackWarning: KeroseneBrandTokens.warning,
      ctaBackground: KeroseneBrandTokens.textPrimary,
      ctaForeground: KeroseneBrandTokens.background,
      ctaDisabledBackground:
          KeroseneBrandTokens.surfaceHigh.withValues(alpha: 0.64),
      ctaDisabledForeground: KeroseneBrandTokens.textMuted,
      inputFocusRing: KeroseneBrandTokens.textPrimary.withValues(alpha: 0.28),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      spaceXs: AppSpacing.xs, // 4
      spaceSm: AppSpacing.sm, // 8
      spaceMd: AppSpacing.base, // 16
      spaceLg: AppSpacing.xl2, // 24
      spaceXl: AppSpacing.module, // 32
      spaceSection: AppSpacing.section, // 48
      minTouch: AppSpacing.minTouch,
      ctaHeight: AppSpacing.xxxl,
      radiusPill: 999,
      radiusInput: 14,
      radiusCard: 24,
      pagePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
      thumbDockPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.sm,
        AppSpacing.xl2,
        AppSpacing.xl2,
      ),
    );
  }

  static SendFlowTheme of(BuildContext context) {
    return Theme.of(context).extension<SendFlowTheme>() ?? SendFlowTheme.dark();
  }

  BorderRadius get pillBorderRadius => BorderRadius.circular(radiusPill);
  BorderRadius get inputBorderRadius => BorderRadius.circular(radiusInput);
  BorderRadius get cardBorderRadius => BorderRadius.circular(radiusCard);

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
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
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
    EdgeInsets? pagePadding,
    EdgeInsets? thumbDockPadding,
  }) {
    return SendFlowTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
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
