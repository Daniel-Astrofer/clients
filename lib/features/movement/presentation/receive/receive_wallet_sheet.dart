import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_title_bar.dart';

const Color _receiveWalletOptionBg = Color(0xFF1A1A1A);

/// Wallet picker panel for the receive flow.
class ReceiveWalletPickerPanel extends StatelessWidget {
  final List<Wallet> wallets;
  final Wallet? selectedWallet;
  final ValueChanged<Wallet> onWalletSelected;
  final bool showHandle;
  final bool shrinkWrap;

  const ReceiveWalletPickerPanel({
    super.key,
    required this.wallets,
    required this.selectedWallet,
    required this.onWalletSelected,
    this.showHandle = true,
    this.shrinkWrap = false,
  });

  static IconData iconFor(Wallet wallet) {
    if (wallet.isColdWallet) return KeroseneIcons.coldWallet;
    if (wallet.isCustodialOnchain) return KeroseneIcons.shield;
    return KeroseneIcons.user;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final list = ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: wallets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        final selected = selectedWallet?.id == wallet.id;
        return _ReceiveWalletOptionTile(
          wallet: wallet,
          selected: selected,
          onTap: () {
            HapticFeedback.selectionClick();
            onWalletSelected(wallet);
          },
        );
      },
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KeroseneBrandTokens.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            const ReceiveFlowSheetTopBorder(),
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: KeroseneBrandTokens.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            if (showHandle) const SizedBox(height: 12),
            ReceiveFlowTitleBar(
              title: ReceiveMoneyCopy.pickWalletTitle(context),
              subtitle: ReceiveMoneyCopy.pickWalletSubtitle(context),
              compact: true,
              alignLeft: true,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
              child: list,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveWalletOptionTile extends StatelessWidget {
  final Wallet wallet;
  final bool selected;
  final VoidCallback onTap;

  const _ReceiveWalletOptionTile({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final custody = ReceiveMoneyCopy.walletCustodyLabel(context, wallet);
    final name = wallet.name.trim();

    return Material(
      color: _receiveWalletOptionBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: _receiveWalletOptionBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: KeroseneBrandTokens.textPrimary,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: KeroseneBrandTokens.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KeroseneBrandTokens.border),
                ),
                child: Icon(
                  ReceiveWalletPickerPanel.iconFor(wallet),
                  color: KeroseneBrandTokens.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custody,
                      style: AppTypography.h3.copyWith(
                        color: KeroseneBrandTokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionLarge.copyWith(
                          color: KeroseneBrandTokens.textMuted,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                KeroseneIcons.chevronRight,
                color: KeroseneBrandTokens.textMuted.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
