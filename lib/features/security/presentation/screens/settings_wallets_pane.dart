import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_wallet_support.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart'
    deferred as bitcoin_accounts;

import 'settings_route_helpers.dart';
import 'settings_section_components.dart';

class SettingsWalletsPane extends ConsumerWidget {
  const SettingsWalletsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.tr;
    final accountsAsync = ref.watch(bitcoinAccountsProvider);
    final sync = ref.watch(bitcoinAccountsSyncProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.settingsWalletsTitle,
          style: AppTypography.newsreader(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          tr.settingsWalletsSubtitle,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (accountsAsync.hasValue &&
            (accountsAsync.hasError || sync.hasError)) ...[
          Text(tr.settingsWalletsSyncFailed, style: AppTypography.bodySmall),
          TextButton(
              onPressed: () =>
                  ref.read(bitcoinAccountsControllerProvider).refresh(),
              child: Text(tr.tryAgain)),
        ],
        if (accountsAsync.hasValue &&
            (accountsAsync.isLoading || sync.isLoading))
          const LinearProgressIndicator(),
        accountsAsync.when(
          skipError: true,
          data: (accounts) {
            final active = accounts
                .where((a) => a.id.trim().isNotEmpty && a.status != 'ARCHIVED')
                .toList(growable: false);
            if (active.isEmpty) {
              return SettingsSection(
                title: tr.settingsWalletsSection,
                children: [
                  SettingsSectionRow(
                    icon: KeroseneIcons.wallet,
                    title: tr.settingsWalletsEmptyTitle,
                    subtitle: tr.settingsWalletsEmptySubtitle,
                    onTap: () => pushSettingsDeferred(
                      context,
                      bitcoin_accounts.loadLibrary,
                      (_) => bitcoin_accounts.BitcoinAccountsScreen(),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: tr.settingsWalletsYoursSection,
                  children: [
                    for (final account in active)
                      _WalletAdminRow(
                          key: ValueKey(account.id), account: account),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () => pushSettingsDeferred(
                    context,
                    bitcoin_accounts.loadLibrary,
                    (_) => bitcoin_accounts.BitcoinAccountsScreen(),
                  ),
                  icon: const KeroseneIcon(KeroseneIcons.next, size: 16),
                  label: Text(tr.settingsWalletsOpenFull),
                ),
              ],
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54)),
            ),
          ),
          error: (_, __) => SettingsSection(
            title: tr.settingsWalletsSection,
            children: [
              SettingsSectionRow(
                icon: KeroseneIcons.warning,
                title: tr.settingsWalletsLoadErrorTitle,
                subtitle: tr.settingsWalletsLoadErrorSubtitle,
                onTap: () =>
                    ref.read(bitcoinAccountsControllerProvider).refresh(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletAdminRow extends ConsumerStatefulWidget {
  final BitcoinAccount account;

  const _WalletAdminRow({super.key, required this.account});

  @override
  ConsumerState<_WalletAdminRow> createState() => _WalletAdminRowState();
}

class _WalletAdminRowState extends ConsumerState<_WalletAdminRow> {
  bool _busy = false;
  bool _menuOpen = false;

  BitcoinAccount get account => widget.account;

  String get _label {
    final label = account.label.trim();
    if (label.isNotEmpty) return label;
    return context.tr.bitcoinAccountsUnnamedAccount;
  }

  String get _kindSubtitle {
    final tr = context.tr;
    if (account.isWatchOnly) return tr.settingsWalletsWatchOnly;
    if (account.isCustodialOnchain) return tr.settingsWalletsCustodialOnchain;
    return tr.settingsWalletsInternal;
  }

  Future<void> _rename() async {
    if (_busy) return;
    final scope = ref.read(sessionStorageScopeProvider);
    final next = await askWalletName(context, account);
    if (next == null ||
        !mounted ||
        scope != ref.read(sessionStorageScopeProvider)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed =
          await ref.read(bitcoinAccountsControllerProvider).renameWallet(
                accountId: account.id,
                label: next,
              );
      if (!mounted || scope != ref.read(sessionStorageScopeProvider)) return;
      AppNotice.showSuccess(
        context,
        title: context.tr.settingsWalletsRenameOk,
        message: confirmed.label,
      );
    } catch (_) {
      if (!mounted || scope != ref.read(sessionStorageScopeProvider)) return;
      AppNotice.showError(
        context,
        title: context.tr.settingsWalletsRenameFailTitle,
        message: context.tr.settingsWalletsRenameFailMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    if (_busy) return;
    final scope = ref.read(sessionStorageScopeProvider);
    final ok = await confirmWalletArchive(context, account);
    if (!ok || !mounted || scope != ref.read(sessionStorageScopeProvider)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed =
          await ref.read(bitcoinAccountsControllerProvider).archiveWallet(
                accountId: account.id,
              );
      if (!mounted || scope != ref.read(sessionStorageScopeProvider)) return;
      AppNotice.showSuccess(
        context,
        title: confirmed.isWatchOnly
            ? context.tr.settingsWalletsArchiveOkWatch
            : context.tr.settingsWalletsArchiveOk,
        message: confirmed.label,
      );
    } catch (_) {
      if (!mounted || scope != ref.read(sessionStorageScopeProvider)) return;
      AppNotice.showError(
        context,
        title: context.tr.settingsWalletsArchiveFailTitle,
        message: context.tr.settingsWalletsArchiveFailMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return SettingsSectionRow(
      icon: KeroseneIcons.wallet,
      title: _label,
      subtitle: _busy
          ? tr.settingsWalletsProcessing
          : '$_kindSubtitle · ${walletStatusLabel(context, account)}',
      onTap: _busy || _menuOpen
          ? null
          : () async {
              setState(() => _menuOpen = true);
              final scope = ref.read(sessionStorageScopeProvider);
              try {
                HapticFeedback.selectionClick();
                final action = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  builder: (sheetContext) {
                    final sheetTr = sheetContext.tr;
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const KeroseneIcon(KeroseneIcons.edit),
                            title: Text(sheetTr.settingsWalletsRename),
                            onTap: () => Navigator.pop(sheetContext, 'rename'),
                          ),
                          ListTile(
                            enabled: walletCanArchive(account),
                            leading: const KeroseneIcon(KeroseneIcons.trash),
                            title: Text(
                              account.isWatchOnly
                                  ? sheetTr.settingsWalletsArchiveWatch
                                  : sheetTr.settingsWalletsArchive,
                            ),
                            onTap: walletCanArchive(account)
                                ? () => Navigator.pop(sheetContext, 'archive')
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                );
                if (!mounted ||
                    scope != ref.read(sessionStorageScopeProvider)) {
                  return;
                }
                if (action == 'rename') {
                  await _rename();
                } else if (action == 'archive') {
                  await _archive();
                }
              } finally {
                if (mounted) setState(() => _menuOpen = false);
              }
            },
    );
  }
}
