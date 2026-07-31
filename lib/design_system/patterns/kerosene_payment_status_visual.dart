import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Canonical payment status visual — icon + label + optional message.
///
/// Used for processing, success, pending, and failure states in payment flows.
/// Never decorative — always tied to real operation state.
///
/// Usage:
/// ```dart
/// KerosenePaymentStatusVisual(
///   status: KerosenePaymentStatus.success,
///   amount: '0.001 BTC',
///   message: 'Enviado para Maria',
/// )
/// ```
class KerosenePaymentStatusVisual extends StatelessWidget {
  final KerosenePaymentStatus status;
  final String? amount;
  final String? message;
  final String? detailActionLabel;
  final VoidCallback? onDetailAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const KerosenePaymentStatusVisual({
    super.key,
    required this.status,
    this.amount,
    this.message,
    this.detailActionLabel,
    this.onDetailAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status icon
        Icon(status.icon, size: 48, color: status.color, semanticLabel: status.semanticLabel),
        SizedBox(height: AppSpacing.base),

        // Amount
        if (amount != null)
          Text(amount!, style: AppTypography.playfairDisplay(fontSize: 32, color: palette.textPrimary, fontWeight: AppTypography.w590)),
        SizedBox(height: AppSpacing.sm),

        // Status label
        Text(status.label, style: AppTypography.inter(fontSize: 15, color: palette.textPrimary, fontWeight: AppTypography.w510)),
        if (message != null) ...[
          SizedBox(height: AppSpacing.xs),
          Text(message!, style: AppTypography.inter(fontSize: 13, color: palette.textSecondary), textAlign: TextAlign.center),
        ],

        // Actions
        if (onDetailAction != null || onSecondaryAction != null) ...[
          SizedBox(height: AppSpacing.module),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (onSecondaryAction != null)
              TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel ?? 'Fechar')),
            if (onSecondaryAction != null && onDetailAction != null) SizedBox(width: AppSpacing.base),
            if (onDetailAction != null)
              TextButton(onPressed: onDetailAction, child: Text(detailActionLabel ?? 'Ver detalhes')),
          ]),
        ],
      ],
    );
  }
}

enum KerosenePaymentStatus {
  submitting,
  pending,
  success,
  failed;

  IconData get icon => switch (this) {
        KerosenePaymentStatus.submitting => Icons.sync,
        KerosenePaymentStatus.pending => Icons.schedule,
        KerosenePaymentStatus.success => Icons.check_circle,
        KerosenePaymentStatus.failed => Icons.error,
      };

  Color get color => switch (this) {
        KerosenePaymentStatus.submitting => KeroseneBrandTokens.textPrimary,
        KerosenePaymentStatus.pending => KeroseneBrandTokens.warning,
        KerosenePaymentStatus.success => KeroseneBrandTokens.success,
        KerosenePaymentStatus.failed => KeroseneBrandTokens.error,
      };

  String get label => switch (this) {
        KerosenePaymentStatus.submitting => 'Enviando...',
        KerosenePaymentStatus.pending => 'Aguardando confirmacao',
        KerosenePaymentStatus.success => 'Enviado com sucesso',
        KerosenePaymentStatus.failed => 'Falha ao enviar',
      };

  String get semanticLabel => switch (this) {
        KerosenePaymentStatus.submitting => 'Processando pagamento',
        KerosenePaymentStatus.pending => 'Pagamento pendente',
        KerosenePaymentStatus.success => 'Pagamento confirmado',
        KerosenePaymentStatus.failed => 'Pagamento falhou',
      };
}
