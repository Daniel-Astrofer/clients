import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';

/// Canonical error state for Kerosene screens.
///
/// Follows the content-language.md error format:
/// [What happened]
/// [Why it happened]
/// [What to do]
///
/// This is PERSISTENT — it does not auto-dismiss. The user must act.
/// Never use SnackBar for operation failures; use this widget inline.
///
/// Usage:
/// ```dart
/// KeroseneErrorState(
///   title: 'Saldo insuficiente',
///   message: 'Voce tem R\$ 100,00 disponiveis. O envio requer R\$ 150,00.',
///   primaryAction: ErrorAction(label: 'Depositar', onPressed: () => ...),
///   secondaryAction: ErrorAction(label: 'Alterar valor', onPressed: () => ...),
/// )
/// ```
class KeroseneErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? errorCode;
  final ErrorAction? primaryAction;
  final ErrorAction? secondaryAction;
  final bool showIcon;

  const KeroseneErrorState({
    super.key,
    required this.title,
    this.message,
    this.errorCode,
    this.primaryAction,
    this.secondaryAction,
    this.showIcon = true,
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
            if (showIcon) ...[
              Icon(
                KeroseneIcons.error,
                size: 32,
                color: KeroseneBrandTokens.error,
                semanticLabel: 'Erro',
              ),
              SizedBox(height: AppSpacing.base),
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
            if (errorCode != null) ...[
              SizedBox(height: AppSpacing.xs),
              Text(
                'Codigo: ${errorCode!}',
                style: AppTypography.inter(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
            ],
            if (primaryAction != null || secondaryAction != null) ...[
              SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (secondaryAction != null)
                    AppButton(
                      label: secondaryAction!.label,
                      onPressed: secondaryAction!.onPressed,
                      variant: AppButtonVariant.ghost,
                    ),
                  if (secondaryAction != null && primaryAction != null)
                    SizedBox(width: AppSpacing.base),
                  if (primaryAction != null)
                    AppButton(
                      label: primaryAction!.label,
                      onPressed: primaryAction!.onPressed,
                      variant: AppButtonVariant.outlined,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An action button in an error state.
class ErrorAction {
  final String label;
  final VoidCallback onPressed;

  const ErrorAction({required this.label, required this.onPressed});
}
