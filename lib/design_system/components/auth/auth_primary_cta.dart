import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// Canonical auth-flow primary action.
///
/// Supports filled and outlined styles used on login / signup / entry screens.
/// Prefer this (or [AppButton]) over one-off [FilledButton] chrome in auth.
class AuthPrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final bool expand;
  final bool haptic;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final Widget? icon;
  final TextStyle? textStyle;

  const AuthPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.expand = true,
    this.haptic = true,
    this.height = 54,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.icon,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null || isLoading;

    final Color bg;
    final Color fg;
    final Color side;

    if (outlined) {
      bg = backgroundColor ??
          scheme.onSurface.withValues(alpha: disabled ? 0.02 : 0.03);
      fg = foregroundColor ??
          (disabled
              ? scheme.onSurface.withValues(alpha: 0.42)
              : scheme.onSurface);
      side = borderColor ??
          scheme.onSurface.withValues(alpha: disabled ? 0.06 : 0.16);
    } else {
      bg = backgroundColor ??
          (disabled
              ? scheme.onSurface.withValues(alpha: 0.42)
              : scheme.onSurface);
      fg = foregroundColor ?? scheme.surface;
      side = Colors.transparent;
    }

    final button = SizedBox(
      height: height < AppSpacing.minTouch ? AppSpacing.minTouch : height,
      child: FilledButton(
        onPressed: disabled
            ? null
            : () {
                if (haptic) HapticFeedback.selectionClick();
                onPressed?.call();
              },
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          foregroundColor: fg,
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          minimumSize: Size(
            expand ? double.infinity : 0,
            height < AppSpacing.minTouch ? AppSpacing.minTouch : height,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: side),
          ),
          textStyle: (textStyle ?? AppTypography.buttonText).copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
        child: isLoading
            ? CupertinoActivityIndicator(radius: 9, color: fg)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    IconTheme(
                      data: IconThemeData(color: fg, size: 18),
                      child: icon!,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
