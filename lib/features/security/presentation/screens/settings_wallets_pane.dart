import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
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
    final accountsAsync = ref.watch(bitcoinAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Carteiras',
          style: AppTypography.newsreader(
            color: KeroseneBrandTokens.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Renomeie ou arquive carteiras desta sessão. Ações usam a mesma API da tela de contas Bitcoin.',
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        accountsAsync.when(
          data: (accounts) {
            final active = accounts
                .where((a) => a.id.trim().isNotEmpty)
                .toList(growable: false);
            if (active.isEmpty) {
              return SettingsSection(
                title: 'Carteiras',
                children: [
                  SettingsSectionRow(
                    icon: KeroseneIcons.wallet,
                    title: 'Nenhuma carteira ativa',
                    subtitle: 'Abra Contas Bitcoin para criar ou importar.',
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
                  title: 'Suas carteiras',
                  children: [
                    for (final account in active)
                      _WalletAdminRow(account: account),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () => pushSettingsDeferred(
                    context,
                    bitcoin_accounts.loadLibrary,
                    (_) => bitcoin_accounts.BitcoinAccountsScreen(),
                  ),
                  icon: const Icon(KeroseneIcons.next, size: 16),
                  label: const Text('Abrir gestão completa de contas'),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
          error: (_, __) => SettingsSection(
            title: 'Carteiras',
            children: [
              SettingsSectionRow(
                icon: KeroseneIcons.warning,
                title: 'Não foi possível carregar',
                subtitle: 'Toque para abrir a gestão completa.',
                onTap: () => pushSettingsDeferred(
                  context,
                  bitcoin_accounts.loadLibrary,
                  (_) => bitcoin_accounts.BitcoinAccountsScreen(),
                ),
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

  const _WalletAdminRow({required this.account});

  @override
  ConsumerState<_WalletAdminRow> createState() => _WalletAdminRowState();
}

class _WalletAdminRowState extends ConsumerState<_WalletAdminRow> {
  bool _busy = false;

  BitcoinAccount get account => widget.account;

  String get _label {
    final label = account.label.trim();
    if (label.isNotEmpty) return label;
    return context.tr.bitcoinAccountsUnnamedAccount;
  }

  String get _kindSubtitle {
    if (account.isWatchOnly) return 'Watch-only / cold';
    if (account.isCustodialOnchain) return 'Custodial on-chain';
    return 'Conta assegurada (interna)';
  }

  Future<void> _rename() async {
    if (_busy) return;
    final next = await askWalletName(context, account);
    if (next == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(bitcoinAccountsProvider.notifier).renameWallet(
            accountId: account.id,
            label: next,
          );
      if (!mounted) return;
      AppNotice.showSuccess(
        context,
        title: 'Nome atualizado',
        message: next,
      );
    } catch (_) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: 'Nome não atualizado',
        message: 'Revise o nome e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    if (_busy) return;
    final ok = await confirmWalletArchive(context, account);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(bitcoinAccountsProvider.notifier).archiveWallet(
            accountId: account.id,
          );
      if (!mounted) return;
      AppNotice.showSuccess(
        context,
        title: account.isWatchOnly
            ? 'Acompanhamento arquivado'
            : 'Carteira arquivada',
        message: _label,
      );
    } catch (_) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: 'Não foi possível arquivar',
        message: 'Tente novamente em instantes.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionRow(
      icon: KeroseneIcons.wallet,
      title: _label,
      subtitle: _busy ? 'Processando…' : _kindSubtitle,
      onTap: _busy
          ? null
          : () async {
              HapticFeedback.selectionClick();
              final action = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: KeroseneBrandTokens.surfaceMuted,
                builder: (sheetContext) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(KeroseneIcons.edit),
                          title: const Text('Trocar nome'),
                          onTap: () => Navigator.pop(sheetContext, 'rename'),
                        ),
                        ListTile(
                          leading: const Icon(KeroseneIcons.trash),
                          title: Text(
                            account.isWatchOnly
                                ? 'Arquivar acompanhamento'
                                : 'Arquivar / bloquear carteira',
                          ),
                          onTap: () => Navigator.pop(sheetContext, 'archive'),
                        ),
                        ListTile(
                          leading: const Icon(KeroseneIcons.close),
                          title: Text(context.tr.cancel),
                          onTap: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (action == 'rename') await _rename();
              if (action == 'archive') await _archive();
            },
    );
  }
}
