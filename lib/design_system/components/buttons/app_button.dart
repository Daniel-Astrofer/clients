import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

/// Canonical action button for Kerosene surfaces.
///
/// Uses design tokens: pill radius, min touch 48, [AppTypography.buttonText].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final Widget? icon;

  /// When true, stretches to parent width (dialogs / forms).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;

    final child = AnimatedSwitcher(
      duration: KeroseneMotion.fast,
      child: loading
          ? const CupertinoActivityIndicator(
              key: ValueKey('loading'),
              radius: 9,
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label),
              ],
            ),
    );

    final Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.minTouch),
            shape: const StadiumBorder(),
            textStyle: AppTypography.buttonText.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.minTouch),
            shape: const StadiumBorder(),
            textStyle: AppTypography.buttonText.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        );
      case AppButtonVariant.ghost:
        button = TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.minTouch),
            textStyle: AppTypography.buttonText.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        );
      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size.fromHeight(AppSpacing.minTouch),
            shape: const StadiumBorder(),
            textStyle: AppTypography.buttonText.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        );
    }

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
