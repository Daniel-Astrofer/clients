import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/app/security/payment_security_guards.dart';

import 'cold_wallet_creation_screen.dart';
import 'cold_wallet_success_screen.dart';
import 'seed_word_entry_screen.dart';
import 'watch_only_import_screen.dart';

/// Entry hub for cold / vault setup. Create and import share [RegisterColdWalletUseCase].
class WalletSetupHubScreen extends ConsumerStatefulWidget {
  const WalletSetupHubScreen({super.key});

  @override
  ConsumerState<WalletSetupHubScreen> createState() =>
      _WalletSetupHubScreenState();
}

class _WalletSetupHubScreenState extends ConsumerState<WalletSetupHubScreen> {
  bool _busy = false;
  bool _registering = false;
  bool _importFailed = false;
  SeedImportResult? _importDraft;
  String? _importLabel;

  @override
  void dispose() {
    _importDraft = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkLabel = coldWalletNetworkLabel(expectedBitcoinNetwork);

    final cards = [
      _HubCard(
          title: context.tr.walletSetupCreateOnDevice,
          subtitle: context.tr.walletSetupGenerateBip39,
          icon: KeroseneIcons.key,
          enabled: !_busy,
          onTap: () => _createOnDevice()),
      _HubCard(
          title: context.tr.walletSetupImportSeed,
          subtitle: context.tr.walletSetupImportSeedHint,
          icon: KeroseneIcons.document,
          enabled: !_busy,
          onTap: () => _importSeed()),
      _HubCard(
          title: context.tr.walletSetupWatchOnly,
          subtitle: context.tr.walletPublicImportHint,
          icon: KeroseneIcons.visibility,
          enabled: !_busy,
          onTap: _importPublic),
      _HubCard(
          title: context.tr.walletSetupMultisig,
          subtitle: context.tr.walletSetupSoon,
          icon: KeroseneIcons.coldWallet,
          enabled: false,
          onTap: () {}),
    ];
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: KeroseneIcon(KeroseneIcons.arrowBack,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _busy ? null : () => Navigator.of(context).pop())),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.tr.walletSetupNewVault,
                            style: AppTypography.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(context.tr.walletSetupNetwork(networkLabel),
                            style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        if (_registering) ...[
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 12),
                          Text(context.tr.walletSetupRegistering,
                              style: AppTypography.bodyMedium),
                          const SizedBox(height: 16),
                        ],
                        if (_importFailed) ...[
                          Text(context.tr.walletImportRetryBody,
                              style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context).colorScheme.error)),
                          TextButton(
                              onPressed: _busy ? null : () => _importSeed(),
                              child: Text(context.tr.walletImportResume)),
                          const SizedBox(height: 16),
                        ],
                        LayoutBuilder(builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 560 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 21;
                          if (!twoColumns) {
                            return Column(children: [
                              for (final card in cards)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: SizedBox(
                                        width: double.infinity, child: card))
                            ]);
                          }
                          return Column(children: [
                            for (var index = 0;
                                index < cards.length;
                                index += 2)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 168),
                                                child: cards[index])),
                                        const SizedBox(width: 16),
                                        Expanded(
                                            child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 168),
                                                child: cards[index + 1]))
                                      ]))
                          ]);
                        }),
                      ]))),
        ));
  }

  Future<void> _createOnDevice() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
          MaterialPageRoute(builder: (_) => const ColdWalletCreationScreen()));
      if (!mounted || outcome == null) return;
      await _finishFromOutcome(outcome);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPublic() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
          MaterialPageRoute(builder: (_) => const WatchOnlyImportScreen()));
      if (mounted && outcome != null) await _finishFromOutcome(outcome);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSeed() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _importFailed = false;
    });
    HapticFeedback.selectionClick();
    try {
      if (_importDraft == null) {
        final draft = await Navigator.of(context).push<SeedImportResult>(
            MaterialPageRoute(builder: (_) => const SeedWordEntryScreen()));
        if (!mounted || draft == null || draft.mnemonic.isEmpty) return;
        _importDraft = draft;
      }
      if (_importLabel == null) {
        final label = await _askImportLabel(context);
        if (!mounted) return;
        if (label == null) {
          _importDraft = null;
          return;
        }
        _importLabel = label;
      }
      final draft = _importDraft!;
      final label = _importLabel!;
      setState(() => _registering = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final useCase = RegisterColdWalletUseCase(
          importColdWallet:
              ref.read(bitcoinAccountsControllerProvider).importColdWallet);
      final result = await useCase.registerFromMnemonic(
          label: label,
          mnemonic: draft.mnemonic,
          passphrase: draft.passphrase,
          storeSeed: true,
          allowInvalidChecksum: draft.allowInvalidChecksum);
      _importDraft = null;
      _importLabel = null;
      if (!mounted) return;
      setState(() => _registering = false);
      final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
          MaterialPageRoute(
              builder: (_) =>
                  ColdWalletSuccessScreen(result: result, walletLabel: label)));
      if (!mounted || outcome == null) return;
      await _finishFromOutcome(outcome);
    } catch (_) {
      if (mounted) setState(() => _importFailed = true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _registering = false;
        });
      }
    }
  }

  /// Close hub and optionally open unified send for the new cold wallet.
  Future<void> _finishFromOutcome(
    ColdWalletFlowOutcome outcome,
  ) async {
    if (outcome.openReceive) {
      context.go(
          Uri(path: '/receive', queryParameters: {'walletId': outcome.walletId})
              .toString());
      return;
    }
    if (outcome.openSend && outcome.seedStored) {
      // Replace hub with send so back from send returns to accounts, not setup.
      context.go(Uri(
          path: '/send-money',
          queryParameters: {'walletId': outcome.walletId}).toString());
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _askImportLabel(BuildContext context) => showDialog<String>(
      context: context,
      builder: (_) => _WalletImportLabelDialog(
          initialValue: context.tr.walletImportedDefaultName));
}

class _WalletImportLabelDialog extends StatefulWidget {
  const _WalletImportLabelDialog({required this.initialValue});
  final String initialValue;
  @override
  State<_WalletImportLabelDialog> createState() =>
      _WalletImportLabelDialogState();
}

class _WalletImportLabelDialogState extends State<_WalletImportLabelDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(context.tr.coldCreateWalletName,
            style: AppTypography.inter(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700)),
        content: TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration:
                InputDecoration(hintText: context.tr.walletSetupNameExample)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr.cancel)),
          TextButton(
              onPressed: _controller.text.trim().isEmpty ? null : _save,
              child: Text(context.tr.walletSetupContinue))
        ],
      );
  void _save() {
    final label = _controller.text.trim();
    if (label.isNotEmpty) Navigator.of(context).pop(label);
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Semantics(
        button: true,
        enabled: enabled,
        child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: enabled ? onTap : null,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeroseneIcon(icon, color: fg, size: 28),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: AppTypography.inter(
                          color: fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )));
  }
}
