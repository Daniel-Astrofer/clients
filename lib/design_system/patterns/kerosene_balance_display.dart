import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Canonical balance display — Playfair Display 48px w590 hero amount.
class KeroseneBalanceDisplay extends StatelessWidget {
  final String amount;
  final String currency;
  final String? walletName;
  final String? custodyLabel;
  final bool isSyncing;
  final bool isHidden;
  final VoidCallback? onWalletTap;

  const KeroseneBalanceDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.walletName,
    this.custodyLabel,
    this.isSyncing = false,
    this.isHidden = false,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (walletName != null)
          GestureDetector(
            onTap: onWalletTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(walletName!, style: AppTypography.inter(fontSize: 13, color: palette.textSecondary, fontWeight: AppTypography.w510)),
                if (custodyLabel != null) ...[
                  SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.ashBorder, width: 1)),
                    child: Text(custodyLabel!, style: AppTypography.inter(fontSize: 11, color: palette.textDisabled, fontWeight: AppTypography.w510)),
                  ),
                ],
                if (onWalletTap != null) ...[
                  SizedBox(width: AppSpacing.xs),
                  Icon(Icons.arrow_drop_down, size: 16, color: palette.textDisabled),
                ],
              ],
            ),
          ),
        SizedBox(height: walletName != null ? AppSpacing.sm : 0),
        Semantics(
          label: isHidden ? 'Saldo oculto' : 'Saldo: $currency $amount',
          child: isHidden
              ? Text('••••••', style: AppTypography.playfairDisplay(fontSize: 48, color: palette.textPrimary, fontWeight: AppTypography.w590))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(currency, style: AppTypography.playfairDisplay(fontSize: 24, color: palette.textSecondary, fontWeight: AppTypography.w510)),
                    SizedBox(width: AppSpacing.xs),
                    Text(amount, style: AppTypography.playfairDisplay(fontSize: 48, color: palette.textPrimary, fontWeight: AppTypography.w590)),
                  ],
                ),
        ),
        if (isSyncing) ...[
          SizedBox(height: AppSpacing.xs),
          Text('Sincronizando...', style: AppTypography.inter(fontSize: 12, color: palette.textDisabled)),
        ],
      ],
    );
  }
}
