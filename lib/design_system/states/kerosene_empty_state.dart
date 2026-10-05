import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';

/// Canonical empty state for Kerosene screens.
///
/// Follows the content-language.md pattern:
/// [What belongs here]
/// [Why it's empty]
/// [Action to fill it]
///
/// Usage:
/// ```dart
/// KeroseneEmptyState(
///   title: 'Nenhuma movimentacao',
///   message: 'Quando voce enviar ou receber, suas movimentacoes aparecem aqui.',
///   actionLabel: 'Fazer primeiro envio',
///   onAction: () => context.push('/send'),
/// )
/// ```
class KeroseneEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  const KeroseneEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.module,
          vertical: AppSpacing.section,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              illustration!,
              SizedBox(height: AppSpacing.module),
            ],
            Text(
              title,
              style: AppTypography.inter(
                fontSize: 15,
                color: palette.textPrimary,
                fontWeight: AppTypography.w510,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.inter(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
