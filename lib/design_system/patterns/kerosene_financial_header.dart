import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// The canonical financial header — balance + wallet selector + sync indicator.
///
/// Composes [KeroseneBalanceDisplay] with a wallet selector row.
/// This is the top ~60% of the home screen's visual weight.
///
/// Usage:
/// ```dart
/// KeroseneFinancialHeader(
///   balance: '1.500,00',
///   currency: 'R\$',
///   walletName: 'Principal',
///   custodyLabel: 'Custodia Kerosene',
///   actions: Row(children: [sendButton, receiveButton]),
/// )
/// ```
class KeroseneFinancialHeader extends StatelessWidget {
  final String balance;
  final String currency;
  final String? walletName;
  final String? custodyLabel;
  final bool isSyncing;
  final bool isHidden;
  final Widget? actions;
  final Widget? marketInfo;
  final VoidCallback? onWalletTap;

  const KeroseneFinancialHeader({
    super.key,
    required this.balance,
    required this.currency,
    this.walletName,
    this.custodyLabel,
    this.isSyncing = false,
    this.isHidden = false,
    this.actions,
    this.marketInfo,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.module,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Balance hero
          // Use the canonical pattern
          _BalanceHero(
            balance: balance,
            currency: currency,
            isHidden: isHidden,
            palette: palette,
          ),

          // Wallet context
          if (walletName != null) ...[
            SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: onWalletTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    walletName!,
                    style: AppTypography.inter(
                      fontSize: 13,
                      color: palette.textSecondary,
                      fontWeight: AppTypography.w510,
                    ),
                  ),
                  if (custodyLabel != null) ...[
                    SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: palette.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        custodyLabel!,
                        style: AppTypography.inter(
                          fontSize: 11,
                          color: palette.textDisabled,
                          fontWeight: AppTypography.w510,
                        ),
                      ),
                    ),
                  ],
                  if (onWalletTap != null) ...[
                    SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: palette.textDisabled,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Sync indicator
          if (isSyncing) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              'Sincronizando...',
              style: AppTypography.inter(
                fontSize: 12,
                color: palette.textDisabled,
              ),
            ),
          ],

          // Market/communication stage
          if (marketInfo != null) ...[
            SizedBox(height: AppSpacing.base),
            marketInfo!,
          ],

          // Action cluster
          if (actions != null) ...[
            SizedBox(height: AppSpacing.lg),
            actions!,
          ],
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final String balance;
  final String currency;
  final bool isHidden;
  final KeroseneBrandTheme palette;

  const _BalanceHero({
    required this.balance,
    required this.currency,
    required this.isHidden,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isHidden ? 'Saldo oculto' : 'Saldo: $currency $balance',
      child: isHidden
          ? Text(
              '••••••',
              style: AppTypography.playfairDisplay(
                fontSize: 48,
                color: palette.textPrimary,
                fontWeight: AppTypography.w590,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency,
                  style: AppTypography.playfairDisplay(
                    fontSize: 24,
                    color: palette.textSecondary,
                    fontWeight: AppTypography.w510,
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  balance,
                  style: AppTypography.playfairDisplay(
                    fontSize: 48,
                    color: palette.textPrimary,
                    fontWeight: AppTypography.w590,
                  ),
                ),
              ],
            ),
    );
  }
}
