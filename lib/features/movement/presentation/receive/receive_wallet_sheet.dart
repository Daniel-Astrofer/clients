import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/components/financial/wallet_expand_chip.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_title_bar.dart';

Color get _receiveWalletOptionBg =>
    SendFlowTheme.forVariant(
      ThemeTokenBridge.isLight ? Brightness.light : Brightness.dark,
    ).surfaceHigh;

/// Wallet picker panel for the receive flow (legacy sheet path).
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

  static IconData iconFor(Wallet wallet) => walletExpandChipIcon(wallet);

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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
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
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: _receiveWalletOptionBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Icon(
                  ReceiveWalletPickerPanel.iconFor(wallet),
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custody,
                      style: AppTypography.h3.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (name.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
