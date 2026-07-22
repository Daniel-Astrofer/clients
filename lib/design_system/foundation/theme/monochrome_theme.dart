import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_typography.dart';
import 'theme_token_bridge.dart';

/// Dark monochrome map — freeze these hexes; light mode is additive only.
const Color monoBackgroundColorDark = Color(0xFF020202);
const Color monoSurfaceColorDark = Color(0xFF0D0D0D);
const Color monoSurfaceAltColorDark = Color(0xFF141414);
const Color monoSurfaceRaisedColorDark = Color(0xFF1A1A1A);
const Color monoBorderColorDark = Color(0xFF262626);
const Color monoBorderStrongColorDark = Color(0xFF383838);
const Color monoDividerColorDark = Color(0xFF1B1B1B);
const Color monoTextColorDark = Color(0xFFF1F1ED);
const Color monoMutedTextColorDark = Color(0xFFA0A09B);
const Color monoFaintTextColorDark = Color(0xFF6B6B66);

/// Theme-resolved aliases (dark when bridge unbound / dark mode).
Color get monoBackgroundColor => MonochromeColors.current.background;
Color get monoSurfaceColor => MonochromeColors.current.surface;
Color get monoSurfaceAltColor => MonochromeColors.current.surfaceAlt;
Color get monoSurfaceRaisedColor => MonochromeColors.current.surfaceRaised;
Color get monoBorderColor => MonochromeColors.current.border;
Color get monoBorderStrongColor => MonochromeColors.current.borderStrong;
Color get monoDividerColor => MonochromeColors.current.divider;
Color get monoTextColor => MonochromeColors.current.text;
Color get monoMutedTextColor => MonochromeColors.current.mutedText;
Color get monoFaintTextColor => MonochromeColors.current.faintText;

const BorderRadius monoRadius = BorderRadius.zero;

/// Theme-aware monochrome chrome (security sheets, activity, PIN).
class MonochromeColors extends ThemeExtension<MonochromeColors> {
  const MonochromeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.text,
    required this.mutedText,
    required this.faintText,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color text;
  final Color mutedText;
  final Color faintText;

  static const MonochromeColors dark = MonochromeColors(
    background: monoBackgroundColorDark,
    surface: monoSurfaceColorDark,
    surfaceAlt: monoSurfaceAltColorDark,
    surfaceRaised: monoSurfaceRaisedColorDark,
    border: monoBorderColorDark,
    borderStrong: monoBorderStrongColorDark,
    divider: monoDividerColorDark,
    text: monoTextColorDark,
    mutedText: monoMutedTextColorDark,
    faintText: monoFaintTextColorDark,
  );

  /// Inverse of dark: light paper + dark ink.
  static const MonochromeColors light = MonochromeColors(
    background: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F1EE),
    surfaceRaised: Color(0xFFE8E9E4),
    border: Color(0xFFD9DAD6),
    borderStrong: Color(0xFFC4C6C0),
    divider: Color(0xFFE2E4DE),
    text: Color(0xFF141517),
    mutedText: Color(0xFF62675F),
    faintText: Color(0xFF8B9087),
  );

  static MonochromeColors get current =>
      ThemeTokenBridge.isLight ? light : dark;

  static MonochromeColors of(BuildContext context) {
    return Theme.of(context).extension<MonochromeColors>() ?? current;
  }

  @override
  MonochromeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? text,
    Color? mutedText,
    Color? faintText,
  }) {
    return MonochromeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      faintText: faintText ?? this.faintText,
    );
  }

  @override
  MonochromeColors lerp(ThemeExtension<MonochromeColors>? other, double t) {
    if (other is! MonochromeColors) return this;
    return MonochromeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      faintText: Color.lerp(faintText, other.faintText, t)!,
    );
  }
}

BoxDecoration monochromePanelDecoration({
  Color? color,
  Color? borderColor,
  bool showShadow = true,
  BuildContext? context,
}) {
  final mono =
      context != null ? MonochromeColors.of(context) : MonochromeColors.current;
  return BoxDecoration(
    color: color ?? mono.surface,
    border: Border.all(color: borderColor ?? mono.border),
    boxShadow: showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: ThemeTokenBridge.isLight ? 0.08 : 0.28,
              ),
              blurRadius: 24,
              spreadRadius: -18,
              offset: const Offset(0, 14),
            ),
          ]
        : null,
  );
}

InputDecoration monochromeInputDecoration({
  required String label,
  String? hintText,
  String? counterText,
  Widget? suffixIcon,
  Widget? prefixIcon,
  BuildContext? context,
}) {
  final mono =
      context != null ? MonochromeColors.of(context) : MonochromeColors.current;
  final border = OutlineInputBorder(
    borderRadius: monoRadius,
    borderSide: BorderSide(color: mono.borderStrong),
  );

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    counterText: counterText,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: mono.surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    labelStyle: AppTypography.bodySmall.copyWith(color: mono.mutedText),
    hintStyle: AppTypography.bodySmall.copyWith(color: mono.faintText),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: monoRadius,
      borderSide: BorderSide(color: mono.text),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: monoRadius,
      borderSide: BorderSide(color: mono.text),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: monoRadius,
      borderSide: BorderSide(color: mono.text),
    ),
  );
}

ButtonStyle monochromeFilledButtonStyle({
  bool emphasis = true,
  bool destructive = false,
  double minHeight = 52,
  BuildContext? context,
}) {
  final mono =
      context != null ? MonochromeColors.of(context) : MonochromeColors.current;
  final background = destructive
      ? mono.surfaceAlt
      : emphasis
          ? mono.text
          : mono.surfaceAlt;
  final foreground = destructive
      ? mono.text
      : emphasis
          ? (ThemeTokenBridge.isLight ? Colors.white : Colors.black)
          : mono.text;
  final border = destructive || emphasis ? mono.borderStrong : mono.border;

  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    disabledBackgroundColor: mono.surfaceRaised,
    disabledForegroundColor: mono.mutedText,
    minimumSize: Size.fromHeight(minHeight),
    textStyle: AppTypography.buttonText.copyWith(
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
    ),
    shape: const RoundedRectangleBorder(borderRadius: monoRadius),
    side: BorderSide(color: border),
  );
}

ButtonStyle monochromeTextButtonStyle({BuildContext? context}) {
  final mono =
      context != null ? MonochromeColors.of(context) : MonochromeColors.current;
  return TextButton.styleFrom(
    foregroundColor: mono.mutedText,
    disabledForegroundColor: mono.faintText,
    textStyle: AppTypography.caption.copyWith(
      color: mono.mutedText,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
    ),
    shape: const RoundedRectangleBorder(borderRadius: monoRadius),
  );
}

ButtonStyle monochromeOutlinedButtonStyle({
  double minHeight = 48,
  Color? foregroundColor,
  BuildContext? context,
}) {
  final mono =
      context != null ? MonochromeColors.of(context) : MonochromeColors.current;
  return OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(minHeight),
    foregroundColor: foregroundColor ?? mono.text,
    disabledForegroundColor: mono.faintText,
    side: BorderSide(color: mono.borderStrong),
    backgroundColor: mono.surfaceAlt,
    shape: const RoundedRectangleBorder(borderRadius: monoRadius),
    textStyle: AppTypography.buttonText.copyWith(
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
    ),
  );
}
