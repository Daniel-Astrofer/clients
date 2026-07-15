import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';

/// Post-create/import success with CTAs into unified send (or done).
///
/// Pops a [ColdWalletFlowOutcome] so the hub can close itself and open send
/// without leaving a stale setup stack under the wizard.
class ColdWalletSuccessScreen extends StatelessWidget {
  final RegisterColdWalletResult result;
  final String walletLabel;

  const ColdWalletSuccessScreen({
    super.key,
    required this.result,
    required this.walletLabel,
  });

  void _finish(BuildContext context, {required bool openSend}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      ColdWalletFlowOutcome(
        registration: result,
        openSend: openSend && result.seedStored,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seedNote = result.seedStored
        ? 'A semente ficou só neste aparelho. A Kerosene só observa saldo on-chain.'
        : 'Modo observação: sem semente neste aparelho — você não pode gastar por aqui.';

    return Scaffold(
      backgroundColor: KeroseneBrandTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                KeroseneIcons.success,
                size: 56,
                color: KeroseneBrandTokens.success,
              ),
              const SizedBox(height: 20),
              Text(
                'Carteira fria pronta',
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                walletLabel,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                seedNote,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              if (result.seedStored) ...[
                FilledButton.icon(
                  onPressed: () => _finish(context, openSend: true),
                  icon: const Icon(KeroseneIcons.send, size: 18),
                  label: Text(
                    'Enviar',
                    style: AppTypography.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: KeroseneBrandTokens.textPrimary,
                    foregroundColor: KeroseneBrandTokens.background,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () => _finish(context, openSend: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KeroseneBrandTokens.textPrimary,
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: KeroseneBrandTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  result.seedStored ? 'Concluir' : 'Concluir (somente observar)',
                  style: AppTypography.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
