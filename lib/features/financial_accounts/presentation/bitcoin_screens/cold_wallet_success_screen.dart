import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';

/// Post-create/import success with CTAs into unified send (or done).
///
/// Pops a [ColdWalletFlowOutcome] so the hub can close itself and open send
/// without leaving a stale setup stack under the wizard.
///
/// If the local seed vault failed ([RegisterColdWalletResult.seedStored] is
/// false without a deliberate public-only import), this is a warning success.
/// A deliberate public-only import explains monitoring without implying a vault failure.
class ColdWalletSuccessScreen extends StatelessWidget {
  final RegisterColdWalletResult result;
  final String walletLabel;

  const ColdWalletSuccessScreen({
    super.key,
    required this.result,
    required this.walletLabel,
  });

  void _finish(BuildContext context,
      {required bool openSend, bool openReceive = false}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      ColdWalletFlowOutcome(
        registration: result,
        openSend: openSend && result.seedStored,
        openReceive: openReceive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seedOk = result.seedStored;
    final title = seedOk
        ? context.tr.coldWalletReadyTitle
        : context.tr.coldWalletObserveTitle;
    final seedNote = result.publicOnly
        ? context.tr.walletPublicOnlyBody
        : seedOk
            ? context.tr.coldWalletSeedStoredBody
            : context.tr.coldWalletSeedMissingBody;
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final icon = result.publicOnly
        ? KeroseneIcons.visibility
        : seedOk
            ? KeroseneIcons.success
            : KeroseneIcons.warning;

    return PopScope<ColdWalletFlowOutcome>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(context, openSend: false);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                KeroseneIcon(icon, size: 56, color: iconColor),
                SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.playfairDisplay(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 1.14,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  walletLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (!seedOk && !result.publicOnly) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KeroseneBrandTokens.textPrimary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: KeroseneBrandTokens.textPrimary.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      context.tr.coldWalletSuccessWarning,
                      textAlign: TextAlign.center,
                      style: AppTypography.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                Text(
                  seedNote,
                  textAlign: TextAlign.center,
                  style: AppTypography.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () =>
                      _finish(context, openSend: false, openReceive: true),
                  icon: const KeroseneIcon(KeroseneIcons.receive, size: 18),
                  label: Text(context.tr.receive),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 12),
                if (seedOk) ...[
                  FilledButton.icon(
                    onPressed: () => _finish(context, openSend: true),
                    icon: const KeroseneIcon(KeroseneIcons.send, size: 18),
                    label: Text(
                      context.tr.sendAction,
                      style: AppTypography.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: () => _finish(context, openSend: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    minimumSize: Size.fromHeight(52),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    seedOk
                        ? context.tr.done
                        : context.tr.coldWalletObserveAction,
                    style: AppTypography.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
