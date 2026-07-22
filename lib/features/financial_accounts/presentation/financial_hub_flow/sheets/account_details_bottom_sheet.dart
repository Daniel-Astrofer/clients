import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import '../theme/financial_hub_tokens.dart';

/// Modal bottom sheet displaying public material, fingerprint, derivation, policy, and account IDs.
class AccountDetailsBottomSheet extends StatelessWidget {
  final BitcoinAccount account;

  const AccountDetailsBottomSheet({
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
      builder: (_) => AccountDetailsBottomSheet(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fingerprint = bitcoinAccountDisplayValue(account.xpubFingerprint);
    final derivation = bitcoinAccountDisplayValue(account.derivationPath);
    final scriptPolicy = bitcoinAccountDisplayValue(account.scriptPolicy);
    final accountId = account.id;
    final cardId = account.cardId ?? '';
    final coldWalletId = account.coldWalletId ?? '';

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
      child: SingleChildScrollView(
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
              'Detalhes Técnicos',
              style: FinancialHubTokens.titleH1(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Material público de derivação, chaves e identificadores.',
              style: FinancialHubTokens.body(fontSize: 13),
            ),
            const SizedBox(height: 20),

            _buildDetailRow(context, label: 'Fingerprint', value: fingerprint),
            const SizedBox(height: 10),
            _buildDetailRow(context, label: 'Derivação', value: derivation),
            const SizedBox(height: 10),
            _buildDetailRow(context,
                label: 'Script Policy', value: scriptPolicy),
            const SizedBox(height: 10),
            _buildDetailRow(context, label: 'ID da Conta', value: accountId),

            if (cardId.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(context, label: 'Card ID', value: cardId),
            ],

            if (coldWalletId.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(context,
                  label: 'Cold Wallet ID', value: coldWalletId),
            ],

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Text(
                'Fechar',
                style: FinancialHubTokens.buttonLabel(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final canCopy = value.trim().isNotEmpty && value != '—';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FinancialHubTokens.caption(),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: FinancialHubTokens.numberText(fontSize: 13),
                ),
              ],
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                AppNotice.showSuccess(
                  context,
                  title: 'Copiado',
                  message: '$label copiado para a área de transferência',
                );
              },
              icon: Icon(
                KeroseneIcons.copy,
                color: Theme.of(context).colorScheme.onSurface,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
