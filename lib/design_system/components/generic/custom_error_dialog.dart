import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

void showCustomErrorDialog(
  BuildContext context,
  String message, {
  String? title,
  VoidCallback? onRetry,
  VoidCallback? onGoBack,
}) {
  showDialog(
    context: context,
    animationStyle: AnimationStyle(
      duration: KeroseneMotion.duration(context, KeroseneMotion.short),
      reverseDuration: KeroseneMotion.duration(context, KeroseneMotion.short),
    ),
    builder: (context) => CustomErrorDialog(
      title: title ?? context.tr.genericActionFailureTitle,
      message: message,
      onRetry: onRetry,
      onGoBack: onGoBack,
    ),
  );
}

class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;

  const CustomErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasActions = onRetry != null || onGoBack != null;

    final actions = <Widget>[
      if (onGoBack != null)
        AppButton(
            label: context.tr.goBack,
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.pop(context);
              onGoBack!();
            }),
      if (onRetry != null)
        AppButton(
            label: context.tr.retry,
            expand: true,
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            }),
      if (!hasActions)
        AppButton(
            label: MaterialLocalizations.of(context).okButtonLabel,
            expand: true,
            onPressed: () => Navigator.pop(context)),
    ];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.card,
              border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.2)),
                ),
                child: KeroseneIcon(KeroseneIcons.error,
                    color: colorScheme.onSurface, size: 28),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: AppTypography.w590)),
              const SizedBox(height: AppSpacing.md),
              Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: AppSpacing.xl2),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.md),
                          actions[i],
                        ]
                      ]);
                }
                return Row(children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(child: actions[i]),
                  ]
                ]);
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
