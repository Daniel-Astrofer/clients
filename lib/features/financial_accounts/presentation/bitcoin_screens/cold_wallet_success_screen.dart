import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// false), this is a **warning** success: watch-only only — user must restore
/// the seed before spending.
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
    final seedOk = result.seedStored;
    final title = seedOk ? 'Carteira fria pronta' : 'Cold wallet só observação';
    final seedNote = seedOk
        ? 'A semente ficou só neste aparelho. A Kerosene só observa saldo on-chain.'
        : 'A semente NÃO foi salva neste aparelho. Você vê o saldo, mas não pode gastar daqui até restaurar a seed.';
    final iconColor =
        seedOk ? KeroseneBrandTokens.success : KeroseneBrandTokens.warning;
    final icon = seedOk ? KeroseneIcons.success : KeroseneIcons.warning;

    return Scaffold(
      backgroundColor: KeroseneBrandTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(icon, size: 56, color: iconColor),
              const SizedBox(height: 20),
              Text(
                title,
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
              if (!seedOk) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KeroseneBrandTokens.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          KeroseneBrandTokens.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Importante: sem a seed neste aparelho, o envio cold não funciona. Guarde a frase e restaure-a antes de tentar gastar.',
                    textAlign: TextAlign.center,
                    style: AppTypography.inter(
                      color: KeroseneBrandTokens.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              if (seedOk) ...[
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
                  seedOk ? 'Concluir' : 'Entendi — só observar por agora',
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
