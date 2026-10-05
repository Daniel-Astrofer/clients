import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/patterns/kerosene_financial_surface.dart';

/// The canonical payment review summary — amount, source, recipient, fee, total.
///
/// Follows the send-review-screen contract:
/// - Amount: Playfair Display 32px w590
/// - Recipient/source: 15px w400
/// - Fee: 13px tertiary color
/// - Total: 15px w590
///
/// Usage:
/// ```dart
/// KerosenePaymentReview(
///   amount: '0.001',
///   currency: 'BTC',
///   recipient: 'bc1q...xyz',
///   sourceWallet: 'Principal',
///   fee: '0.000001 BTC',
///   total: '0.001001 BTC',
///   onConfirm: () => authorize(),
///   onEditAmount: () => goBack(),
/// )
/// ```
class KerosenePaymentReview extends StatelessWidget {
  final String amount;
  final String currency;
  final String recipient;
  final String sourceWallet;
  final String? fee;
  final String? total;
  final String confirmLabel;
  final bool isConfirmEnabled;
  final bool isFeeRecalculating;
  final String? warningMessage;
  final VoidCallback? onConfirm;
  final VoidCallback? onEditAmount;
  final VoidCallback? onEditRecipient;

  const KerosenePaymentReview({
    super.key,
    required this.amount,
    required this.currency,
    required this.recipient,
    required this.sourceWallet,
    this.fee,
    this.total,
    this.confirmLabel = 'Enviar',
    this.isConfirmEnabled = true,
    this.isFeeRecalculating = false,
    this.warningMessage,
    this.onConfirm,
    this.onEditAmount,
    this.onEditRecipient,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);
    final label = total != null ? '$confirmLabel $total' : confirmLabel;

    return Padding(
      padding: EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning banner
          if (warningMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              margin: EdgeInsets.only(bottom: AppSpacing.base),
              decoration: BoxDecoration(
                color: KeroseneBrandTokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: KeroseneBrandTokens.warning.withValues(alpha: 0.3)),
              ),
              child: Text(warningMessage!,
                  style: AppTypography.inter(
                      fontSize: 13, color: KeroseneBrandTokens.warning)),
            ),

          // Amount hero
          Semantics(label: 'Enviar $currency $amount'),
          Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(currency,
                    style: AppTypography.playfairDisplay(
                        fontSize: 18,
                        color: palette.textSecondary,
                        fontWeight: AppTypography.w510)),
                SizedBox(width: AppSpacing.xs),
                Text(amount,
                    style: AppTypography.playfairDisplay(
                        fontSize: 32,
                        color: palette.textPrimary,
                        fontWeight: AppTypography.w590)),
              ]),

          SizedBox(height: AppSpacing.module),

          // Details surface
          KeroseneFinancialSurface(
            elevation: KeroseneSurfaceElevation.one,
            padding: EdgeInsets.all(AppSpacing.base),
            child: Column(
              children: [
                _ReviewRow(
                    label: 'Para',
                    value: recipient,
                    onEdit: onEditRecipient,
                    palette: palette),
                SizedBox(height: AppSpacing.sm),
                _ReviewRow(label: 'De', value: sourceWallet, palette: palette),
                if (fee != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  if (isFeeRecalculating)
                    _ReviewRow(
                        label: 'Taxa',
                        value: 'Recalculando...',
                        palette: palette,
                        isLoading: true)
                  else
                    _ReviewRow(label: 'Taxa', value: fee!, palette: palette),
                ],
                if (total != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  Divider(color: AppColors.smokeSurface, height: 1),
                  SizedBox(height: AppSpacing.sm),
                  _ReviewRow(
                      label: 'Total',
                      value: total!,
                      palette: palette,
                      isBold: true),
                ],
              ],
            ),
          ),

          SizedBox(height: AppSpacing.module),

          // Confirm button
          AppButton(
            label: label,
            onPressed: isConfirmEnabled ? onConfirm : null,
            variant: AppButtonVariant.primary,
          ),

          if (onEditAmount != null) ...[
            SizedBox(height: AppSpacing.sm),
            AppButton(
                label: 'Editar valor',
                onPressed: onEditAmount,
                variant: AppButtonVariant.ghost),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final KeroseneBrandTheme palette;
  final bool isBold;
  final bool isLoading;

  const _ReviewRow(
      {required this.label,
      required this.value,
      this.onEdit,
      required this.palette,
      this.isBold = false,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style:
                AppTypography.inter(fontSize: 13, color: palette.textDisabled)),
        Spacer(),
        if (isLoading)
          SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(palette.textDisabled)))
        else
          Flexible(
              child: Text(value,
                  style: AppTypography.inter(
                      fontSize: 13,
                      color:
                          isBold ? palette.textPrimary : palette.textSecondary,
                      fontWeight:
                          isBold ? AppTypography.w590 : AppTypography.w400),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis)),
        if (onEdit != null) ...[
          SizedBox(width: AppSpacing.sm),
          GestureDetector(
              onTap: onEdit,
              child: Icon(KeroseneIcons.edit,
                  size: 14, color: palette.textDisabled)),
        ],
      ],
    );
  }
}
