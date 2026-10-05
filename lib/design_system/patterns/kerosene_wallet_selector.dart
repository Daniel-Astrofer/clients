import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Canonical wallet selector — a list of wallets with balances and custody types.
///
/// Used in wallet switching flows and as source selector in send flow.
///
/// Usage:
/// ```dart
/// KeroseneWalletSelector(
///   wallets: [
///     KeroseneWalletOption(name: 'Principal', balance: '1.500,00', custody: 'Custodia', isSelected: true),
///     KeroseneWalletOption(name: 'Cold Vault', balance: '0.500 BTC', custody: 'Fria', isSelected: false),
///   ],
///   onSelect: (wallet) => switchWallet(wallet),
/// )
/// ```
class KeroseneWalletSelector extends StatelessWidget {
  final List<KeroseneWalletOption> wallets;
  final ValueChanged<KeroseneWalletOption>? onSelect;
  final VoidCallback? onCreateWallet;

  const KeroseneWalletSelector({
    super.key,
    required this.wallets,
    this.onSelect,
    this.onCreateWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...wallets.map(
          (wallet) =>
              _WalletRow(option: wallet, onTap: () => onSelect?.call(wallet)),
        ),
        if (onCreateWallet != null) ...[
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onCreateWallet,
            child: Text('+ ${context.tr.createWalletAction}'),
          ),
        ],
      ],
    );
  }
}

class KeroseneWalletOption {
  final String name;
  final String balance;
  final String custody;
  final bool isSelected;

  const KeroseneWalletOption({
    required this.name,
    required this.balance,
    required this.custody,
    this.isSelected = false,
  });
}

class _WalletRow extends StatelessWidget {
  final KeroseneWalletOption option;
  final VoidCallback? onTap;

  const _WalletRow({required this.option, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: option.isSelected
                ? AppColors.graphiteSurface
                : AppColors.carbonSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: option.isSelected
                  ? palette.border
                  : AppColors.smokeSurface,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: AppTypography.inter(
                        fontSize: 15,
                        color: palette.textPrimary,
                        fontWeight: AppTypography.w510,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      option.custody,
                      style: AppTypography.inter(
                        fontSize: 12,
                        color: palette.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    option.balance,
                    style: AppTypography.inter(
                      fontSize: 15,
                      color: palette.textPrimary,
                      fontWeight: AppTypography.w590,
                    ),
                  ),
                  if (option.isSelected)
                    Text(
                      context.tr.walletSelected,
                      style: AppTypography.inter(
                        fontSize: 11,
                        color: KeroseneBrandTokens.brand,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
