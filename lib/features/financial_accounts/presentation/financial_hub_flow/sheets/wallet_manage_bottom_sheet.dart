import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_wallet_support.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import '../theme/financial_hub_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Modal bottom sheet for wallet management (Rename, Status check, Lock/Archive, Public Material, Cold Wallet).
class WalletManageBottomSheet extends ConsumerStatefulWidget {
  final BitcoinAccount account;

  const WalletManageBottomSheet({super.key, required this.account});

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
  late final String? _openedScope;
  @override
  void initState() {
    super.initState();
    _openedScope = ref.read(sessionStorageScopeProvider);
  }

  bool get _sameActor =>
      mounted && ref.read(sessionStorageScopeProvider) == _openedScope;

  BitcoinAccount get _account =>
      ref
          .read(bitcoinAccountsProvider)
          .value
          ?.where((a) => a.id == widget.account.id)
          .firstOrNull ??
      widget.account;

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
            child: Text(label, style: FinancialHubTokens.caption()),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      AppNotice.showSuccess(
                        context,
                        title: 'Copiado',
                        message: value,
                      );
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
    final scope = ref.watch(sessionStorageScopeProvider);
    if (scope != _openedScope) {
      return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(context.tr.walletSessionChanged),
        TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.tr.close)),
      ]));
    }
    ref.watch(bitcoinAccountsProvider);
    final accountName = _account.label.trim().isEmpty
        ? 'Carteira sem nome'
        : _account.label.trim();
    final statusText = walletStatusLabel(context, _account);
    final hasPublicMaterial = bitcoinAccountHasPublicMaterial(_account);

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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Title in Playfair Display
            Text(
              context.tr.walletManageAccountTitle,
              style: FinancialHubTokens.titleH1(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr.walletManageAccountBody,
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
                          context.tr.walletManageWalletName,
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
                    onPressed: _busyAction != null
                        ? null
                        : () => _renameWallet(context),
                    icon: _busyAction != null
                        ? CupertinoActivityIndicator()
                        : KeroseneIcon(
                            KeroseneIcons.edit,
                            color: Theme.of(context).colorScheme.onSurface,
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
                  _buildDetailRow(
                    context.tr.walletManageIdentifier,
                    _account.id,
                    copyable: true,
                  ),
                  if ((_account.cardId ?? '').trim().isNotEmpty &&
                      _account.cardId != _account.id)
                    _buildDetailRow(
                      context.tr.walletManageCardIdentifier,
                      _account.cardId!,
                      copyable: true,
                    ),
                  if ((_account.coldWalletId ?? '').trim().isNotEmpty &&
                      _account.coldWalletId != _account.id)
                    _buildDetailRow(
                      context.tr.walletManageExternalIdentifier,
                      _account.coldWalletId!,
                      copyable: true,
                    ),
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
                    context.tr.walletManageAccountStatus,
                    style: FinancialHubTokens.caption(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: KeroseneBrandTokens.textPrimary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KeroseneIcon(
                            _account.isActive
                                ? KeroseneIcons.check
                                : KeroseneIcons.archive,
                            size: 14,
                            color: KeroseneBrandTokens.textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: FinancialHubTokens.numberText(
                            color: KeroseneBrandTokens.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                          _account.isWatchOnly
                              ? context.tr.settingsWalletsArchiveWatch
                              : context.tr.settingsWalletsArchive,
                          style: FinancialHubTokens.numberText(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr.walletArchiveReview,
                          style: FinancialHubTokens.caption(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_busyAction == 'archive')
                    const CupertinoActivityIndicator(radius: 12)
                  else
                    TextButton(
                      onPressed:
                          !walletCanArchive(_account) || _busyAction != null
                              ? null
                              : () => _archiveWallet(context),
                      child: Text(
                        context.tr.walletArchiveAction,
                      ),
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
                      context.tr.walletManagePublicMaterial,
                      style: FinancialHubTokens.numberText(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Fingerprint',
                      bitcoinAccountDisplayValue(
                        _account.xpubFingerprint,
                      ),
                      copyable: true,
                    ),
                    _buildDetailRow(
                      'Derivation',
                      bitcoinAccountDisplayValue(_account.derivationPath),
                      copyable: true,
                    ),
                    _buildDetailRow(
                      'Script policy',
                      bitcoinAccountDisplayValue(_account.scriptPolicy),
                      copyable: true,
                    ),
                  ],
                ),
              ),
            ],

            if (_account.isWatchOnly) ...[
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ColdWalletBackendOptions(
                    account: _account,
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
    if (_busyAction != null || !_sameActor) return;
    final nextLabel = await askWalletName(context, _account);
    if (nextLabel == null || !context.mounted || !_sameActor) return;

    setState(() => _busyAction = 'rename');
    try {
      final confirmed = await ref
          .read(bitcoinAccountsControllerProvider)
          .renameWallet(accountId: _account.id, label: nextLabel);
      if (!context.mounted || !_sameActor) return;
      AppNotice.showSuccess(
        context,
        title: context.tr.settingsWalletsRenameOk,
        message: confirmed.label,
      );
    } catch (_) {
      if (!context.mounted || !_sameActor) return;
      AppNotice.showError(
        context,
        title: context.tr.settingsWalletsRenameFailTitle,
        message: context.tr.settingsWalletsRenameFailMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _archiveWallet(BuildContext context) async {
    if (_busyAction != null || !_sameActor) return;
    final confirmed = await confirmWalletArchive(context, _account);
    if (!confirmed || !context.mounted || !_sameActor) return;

    setState(() => _busyAction = 'archive');
    try {
      await ref
          .read(bitcoinAccountsControllerProvider)
          .archiveWallet(accountId: _account.id);
      if (!context.mounted || !_sameActor) return;
      AppNotice.showSuccess(
        context,
        title: context.tr.settingsWalletsArchiveOk,
        message: _account.label,
      );
      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted || !_sameActor) return;
      AppNotice.showError(
        context,
        title: context.tr.settingsWalletsArchiveFailTitle,
        message: context.tr.settingsWalletsArchiveFailMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }
}
