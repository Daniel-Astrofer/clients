import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/internal_account_creation_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import '../theme/financial_hub_tokens.dart';

/// Modal bottom sheet for wallet management (Rename, Status check, Lock/Archive, Public Material, Cold Wallet).
class WalletManageBottomSheet extends ConsumerStatefulWidget {
  final BitcoinAccount account;

  const WalletManageBottomSheet({
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
      builder: (_) => WalletManageBottomSheet(account: account),
    );
  }

  @override
  ConsumerState<WalletManageBottomSheet> createState() =>
      _WalletManageBottomSheetState();
}

class _WalletManageBottomSheetState
    extends ConsumerState<WalletManageBottomSheet> {
  String? _busyAction;
  String? _expandedKey;

  bool get _isLocked => walletIsLocked(widget.account);

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() => _expandedKey = _expandedKey == key ? null : key);
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: FinancialHubTokens.caption(),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      AppNotice.showSuccess(context,
                          title: 'Copiado', message: value);
                    }
                  : null,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: FinancialHubTokens.numberText(
                  fontSize: 13,
                  color: copyable
                      ? FinancialHubTokens.accentGold
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountName = widget.account.label.trim().isEmpty
        ? 'Carteira sem nome'
        : widget.account.label.trim();
    final statusText = friendlyStatus(context, widget.account.status);
    final hasPublicMaterial = bitcoinAccountHasPublicMaterial(widget.account);

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
              'Gerenciar Conta',
              style: FinancialHubTokens.titleH1(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Configurações e dados reativos à custódia.',
              style: FinancialHubTokens.body(fontSize: 13),
            ),
            SizedBox(height: 20),

            // Rename Wallet Tile
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nome da Carteira',
                          style: FinancialHubTokens.caption(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accountName,
                          style: FinancialHubTokens.numberText(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busyAction == 'rename'
                        ? null
                        : () => _renameWallet(context),
                    icon: _busyAction == 'rename'
                        ? CupertinoActivityIndicator()
                        : Icon(KeroseneIcons.edit, color: Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Advanced IDs Section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailRow('ID da Conta', widget.account.id,
                      copyable: true),
                  if ((widget.account.cardId ?? '').trim().isNotEmpty)
                    _buildDetailRow('Card ID', widget.account.cardId!,
                        copyable: true),
                  if ((widget.account.coldWalletId ?? '').trim().isNotEmpty)
                    _buildDetailRow(
                        'Cold Wallet ID', widget.account.coldWalletId!,
                        copyable: true),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Account Status Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Situação da Conta',
                    style: FinancialHubTokens.caption(),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isLocked
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: FinancialHubTokens.numberText(
                        color:
                            _isLocked ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Lock / Archive Switch Row
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.isWatchOnly
                              ? 'Arquivar acompanhamento'
                              : 'Bloquear carteira',
                          style: FinancialHubTokens.numberText(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLocked
                              ? 'A carteira já está bloqueada para uso.'
                              : 'Ative para bloquear esta carteira.',
                          style: FinancialHubTokens.caption(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_busyAction == 'archive')
                    const CupertinoActivityIndicator(radius: 12)
                  else
                    Switch.adaptive(
                      value: _isLocked,
                      activeTrackColor: FinancialHubTokens.accentGold,
                      onChanged:
                          _isLocked ? null : (_) => _archiveWallet(context),
                    ),
                ],
              ),
            ),

            if (hasPublicMaterial) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material Público',
                      style: FinancialHubTokens.numberText(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        'Fingerprint',
                        bitcoinAccountDisplayValue(
                            widget.account.xpubFingerprint),
                        copyable: true),
                    _buildDetailRow(
                        'Derivation',
                        bitcoinAccountDisplayValue(
                            widget.account.derivationPath),
                        copyable: true),
                    _buildDetailRow('Script policy',
                        bitcoinAccountDisplayValue(widget.account.scriptPolicy),
                        copyable: true),
                  ],
                ),
              ),
            ],

            if (widget.account.isWatchOnly) ...[
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ColdWalletBackendOptions(
                    account: widget.account,
                    expandedKey: _expandedKey,
                    onToggle: _toggle,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _renameWallet(BuildContext context) async {
    final nextLabel = await askWalletName(context, widget.account);
    if (nextLabel == null || !mounted) return;

    setState(() => _busyAction = 'rename');
    try {
      await ref.read(bitcoinAccountsProvider.notifier).renameWallet(
            accountId: widget.account.id,
            label: nextLabel,
          );
      if (!mounted) return;
      AppNotice.showSuccess(
        context,
        title: 'Nome Atualizado',
        message: nextLabel,
      );
    } catch (_) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: 'Erro ao Atualizar',
        message: 'Não foi possível atualizar o nome da conta.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _archiveWallet(BuildContext context) async {
    final confirmed = await confirmWalletArchive(context, widget.account);
    if (!confirmed || !mounted) return;

    setState(() => _busyAction = 'archive');
    try {
      await ref.read(bitcoinAccountsProvider.notifier).archiveWallet(
            accountId: widget.account.id,
          );
      if (!mounted) return;
      AppNotice.showSuccess(
        context,
        title: 'Carteira Atualizada',
        message: 'A carteira foi bloqueada com sucesso.',
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: 'Erro',
        message: 'Falha ao alterar estado da carteira.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }
}
