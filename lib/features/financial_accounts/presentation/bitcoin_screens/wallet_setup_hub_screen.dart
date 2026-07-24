import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'cold_wallet_creation_screen.dart';
import 'cold_wallet_success_screen.dart';
import 'seed_word_entry_screen.dart';

/// Entry hub for cold / vault setup. Create and import share [RegisterColdWalletUseCase].
class WalletSetupHubScreen extends ConsumerWidget {
  const WalletSetupHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkLabel = coldWalletNetworkLabel(expectedBitcoinNetwork);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 12),
              Text(
                'Novo cofre',
                style: AppTypography.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Rede do app: $networkLabel · path ${appColdWalletDerivationPath}',
                style: AppTypography.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    _HubCard(
                      title: context.tr.walletSetupCreateOnDevice,
                      subtitle: context.tr.walletSetupGenerateBip39,
                      icon: PhosphorIcons.key(PhosphorIconsStyle.regular),
                      enabled: true,
                      onTap: () => _createOnDevice(context),
                    ),
                    _HubCard(
                      title: context.tr.walletSetupImportSeed,
                      subtitle: context.tr.walletSetupImportSeedHint,
                      icon: PhosphorIcons.scroll(PhosphorIconsStyle.regular),
                      enabled: true,
                      onTap: () => _importSeed(context, ref),
                    ),
                    _HubCard(
                      title: context.tr.walletSetupWatchOnly,
                      subtitle: context.tr.walletSetupXpubSoon,
                      icon: PhosphorIcons.eye(PhosphorIconsStyle.regular),
                      enabled: false,
                      onTap: () {},
                    ),
                    _HubCard(
                      title: context.tr.walletSetupMultisig,
                      subtitle: context.tr.walletSetupSoon,
                      icon: PhosphorIcons.vault(PhosphorIconsStyle.regular),
                      enabled: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createOnDevice(BuildContext context) async {
    HapticFeedback.selectionClick();
    final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
      MaterialPageRoute(
        builder: (_) => const ColdWalletCreationScreen(),
      ),
    );
    if (!context.mounted || outcome == null) return;
    await _finishFromOutcome(context, outcome);
  }

  Future<void> _importSeed(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final importResult = await Navigator.of(context).push<SeedImportResult>(
      MaterialPageRoute(
        builder: (_) => const SeedWordEntryScreen(),
      ),
    );
    if (importResult == null || importResult.mnemonic.trim().isEmpty) {
      return;
    }
    if (!context.mounted) return;

    final label = await _askImportLabel(context) ?? 'Carteira importada';
    if (!context.mounted) return;

    AppNotice.show(
      context,
      type: AppNoticeType.info,
      title: context.tr.walletSetupRegistering,
      message: context.tr.walletSetupDerivingKeys,
    );

    try {
      final useCase = RegisterColdWalletUseCase(
        importColdWallet:
            ref.read(bitcoinAccountsProvider.notifier).importColdWallet,
      );
      // Do not pass app BIP84 path — Electrum seeds need m/0' (auto-detected).
      final result = await useCase.registerFromMnemonic(
        label: label,
        mnemonic: importResult.mnemonic,
        passphrase: importResult.passphrase,
        storeSeed: true,
        allowInvalidChecksum: importResult.allowInvalidChecksum,
      );
      if (!context.mounted) return;
      final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
        MaterialPageRoute(
          builder: (_) => ColdWalletSuccessScreen(
            result: result,
            walletLabel: label,
          ),
        ),
      );
      if (!context.mounted || outcome == null) return;
      await _finishFromOutcome(context, outcome);
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('[cold-import] failed before/during API: $e\n$st');
        return true;
      }());
      if (!context.mounted) return;
      AppNotice.showError(
        context,
        title: context.tr.walletSetupImportFail,
        message: coldWalletRegisterErrorMessage(e),
      );
    }
  }

  /// Close hub and optionally open unified send for the new cold wallet.
  Future<void> _finishFromOutcome(
    BuildContext context,
    ColdWalletFlowOutcome outcome,
  ) async {
    if (outcome.openSend && outcome.seedStored) {
      // Replace hub with send so back from send returns to accounts, not setup.
      context.go('/send-money');
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _askImportLabel(BuildContext context) async {
    final controller = TextEditingController(text: 'Carteira importada');
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            context.tr.coldCreateWalletName,
            style: AppTypography.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.inter(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: context.tr.walletSetupNameExample,
              hintStyle:
                  AppTypography.inter(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(context.tr.walletSetupContinue),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (label == null || label.isEmpty) return null;
    return label;
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
    final fg = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    return Material(
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
              Icon(icon, color: fg, size: 28),
              const Spacer(),
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
                  color: enabled ? Theme.of(context).colorScheme.onSurfaceVariant : fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
