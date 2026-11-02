import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_advanced_sections.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';

bool canCreateInternalKeroseneAccount(List<BitcoinAccount> accounts) {
  return !accounts.any(
    (account) =>
        account.isActive && account.isInternal && !account.isCustodialOnchain,
  );
}

bool canCreateCustodialOnchainAccount(List<BitcoinAccount> accounts) {
  return !accounts.any(
    (account) => account.isActive && account.isCustodialOnchain,
  );
}

bool canCreateKeroseneWalletAccount(List<BitcoinAccount> accounts) {
  return canCreateInternalKeroseneAccount(accounts) ||
      canCreateCustodialOnchainAccount(accounts);
}

bool canCreateColdWalletAccount(List<BitcoinAccount> accounts) {
  final activeColdWallets = accounts
      .where((account) => account.isActive && account.isWatchOnly)
      .length;
  return activeColdWallets < maxActiveColdWallets;
}

bool walletIsLocked(BitcoinAccount account) {
  return switch (account.status.trim().toUpperCase()) {
    'DISABLED' || 'BLOCKED' || 'FROZEN' || 'ARCHIVED' => true,
    _ => false,
  };
}

String walletStatusLabel(BuildContext context, BitcoinAccount account) =>
    switch (account.status.trim().toUpperCase()) {
      'ACTIVE' => context.tr.walletStateActive,
      'PENDING' => context.tr.bitcoinAccountsStatusPending,
      'READY' => context.tr.bitcoinAccountsStatusReady,
      'DISABLED' => context.tr.bitcoinAccountsStatusDisabled,
      'ARCHIVED' => context.tr.walletStateArchived,
      'CREATING' => context.tr.walletStateCreating,
      'ROTATING_ADDRESS' => context.tr.walletStateRotating,
      'KEYGEN_FAILED' => context.tr.walletStateFailed,
      'QUORUM_BLOCKED' => context.tr.walletStateQuorum,
      'FROZEN' || 'BLOCKED' || 'SUSPENDED' => context.tr.walletStateFrozen,
      _ => context.tr.walletStateUnknown,
    };

bool walletCanArchive(BitcoinAccount account) => const [
      'ACTIVE',
      'FROZEN',
      'KEYGEN_FAILED',
      'QUORUM_BLOCKED'
    ].contains(account.status.trim().toUpperCase());

class InlineCopyButton extends StatelessWidget {
  final String value;
  final String semanticLabel;
  final Color? inkColor;

  const InlineCopyButton({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.inkColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);
    final ink = inkColor ?? colors.text;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: value.trim().isEmpty
              ? null
              : () => copyText(
                    context,
                    value,
                    title: context.tr.btcAccountsCopied,
                    message: context.tr.btcAccountsCopiedClipboard,
                  ),
          child: SizedBox(
            width: 38,
            height: 38,
            child: KeroseneIcon(KeroseneIcons.copy, color: ink, size: 18),
          ),
        ),
      ),
    );
  }
}

class ColdWalletBackendOptions extends ConsumerWidget {
  final BitcoinAccount account;
  final String? expandedKey;
  final ValueChanged<String> onToggle;

  const ColdWalletBackendOptions({
    super.key,
    required this.account,
    required this.expandedKey,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coldWalletId = coldWalletIdForAccount(account);
    final utxosAsync = ref.watch(bitcoinColdWalletUtxosProvider(coldWalletId));
    final psbtsAsync = ref.watch(bitcoinColdWalletPsbtsProvider(coldWalletId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.go('/send-money');
              },
              icon: KeroseneIcon(KeroseneIcons.send, size: 18),
              label: Text(
                context.tr.bitcoinAdvancedNewPsbtAction,
                style: TextStyle(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        _WalletExpansionItem(
          title: context.tr.btcAccountsUtxos,
          expanded: expandedKey == 'utxos',
          onTap: () => onToggle('utxos'),
          child: utxosAsync.when(
            loading: () => const _InlineLoadingState(),
            error: (_, __) => MiniEmptyState(
              text: context.tr.bitcoinAdvancedUtxosUnavailableMessage,
            ),
            data: (utxos) => UtxoPreviewList(utxos: utxos),
          ),
        ),
        _WalletExpansionItem(
          title: context.tr.btcAccountsPsbt,
          expanded: expandedKey == 'psbts',
          onTap: () => onToggle('psbts'),
          child: psbtsAsync.when(
            loading: () => const _InlineLoadingState(),
            error: (_, __) => MiniEmptyState(
              text: context.tr.bitcoinAdvancedPsbtsUnavailableMessage,
            ),
            data: (workflows) => PsbtPreviewList(
              workflows: workflows,
              onSubmitSigned: (_) {},
              onCopyUnsigned: (workflow) => copyText(
                context,
                workflow.unsignedPsbt,
                title: context.tr.bitcoinAdvancedPsbtCopiedTitle,
                message: context.tr.bitcoinAdvancedSignExternallyMessage,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletExpansionItem extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _WalletExpansionItem({
    required this.title,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: KeroseneIcon(
              expanded ? KeroseneIcons.expandLess : KeroseneIcons.expandMore,
            ),
            onTap: onTap,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _InlineLoadingState extends StatelessWidget {
  const _InlineLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
