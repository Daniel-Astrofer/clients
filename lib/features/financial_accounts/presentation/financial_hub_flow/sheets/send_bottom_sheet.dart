import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';
import '../theme/financial_hub_tokens.dart';

/// Modal bottom sheet displaying options to send funds from the selected account.
class SendBottomSheet extends StatelessWidget {
  final BitcoinAccount account;

  const SendBottomSheet({
    super.key,
    required this.account,
  });

  static Future<void> show(
    BuildContext context, {
    required BitcoinAccount account,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendBottomSheet(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceLabel = formatSats(bitcoinAccountVisibleBalance(account));

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Title in Playfair Display
          Text(
            'Enviar Recurso',
            style: FinancialHubTokens.titleH1(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecione o tipo de envio para movimentar seus fundos.',
            style: FinancialHubTokens.body(fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Available balance summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo disponível',
                  style: FinancialHubTokens.caption(),
                ),
                Text(
                  balanceLabel,
                  style: FinancialHubTokens.numberText(
                    color: FinancialHubTokens.accentGold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send Action Tile: On-Chain / Lightning
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FinancialHubTokens.circularButtonBg,
                shape: BoxShape.circle,
              ),
              child: Icon(KeroseneIcons.up, color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            title: Text(
              'Enviar para Endereço / Invoice',
              style: FinancialHubTokens.numberText(fontSize: 14),
            ),
            subtitle: Text(
              'Transferir sats para qualquer carteira externa ou invoice',
              style: FinancialHubTokens.caption(),
            ),
            trailing: Icon(KeroseneIcons.chevronRight, color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/send');
            },
          ),
          const SizedBox(height: 12),

          // Cancel Action
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Text(
              'Cancelar',
              style: FinancialHubTokens.buttonLabel(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
