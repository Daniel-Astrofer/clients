import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/monochrome_theme.dart';
import 'package:kerosene/design_system/icons.dart';
import '../providers/onboarding_progress_provider.dart';

class OnboardingStepsScreen extends ConsumerWidget {
  const OnboardingStepsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingProgressProvider);
    final isDone = progress.isAllCompleted;
    final completed = progress.completedSteps;

    return Scaffold(
      backgroundColor: AppColors.hexFF000000,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom top app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.maybePop(context);
                    },
                    icon: const Icon(KeroseneIcons.back, color: Colors.white, size: 22),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: context.responsive.appColumnConstraints,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr.onboardingJourneyTitle.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: monoMutedTextColor,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isDone
                              ? 'Excelente! Sua conta está 100% ativa.'
                              : 'Complete as etapas essenciais abaixo para habilitar todas as funções da plataforma.',
                          style: AppTypography.newsreader(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Mini progress info
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: completed / 3.0,
                                  minHeight: 5,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDone ? AppColors.hexFF4ADE80 : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '$completed de 3 concluídos',
                              style: TextStyle(
                                color: monoMutedTextColor,
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 38),
                        _buildStepItem(
                          context: context,
                          index: 1,
                          title: context.tr.onboardingCreateCustodialWallet,
                          description: 'Crie uma carteira Kerosene oficial para habilitar saldos.',
                          isCompleted: progress.hasCustodialWallet,
                          onTapAction: () {
                            Navigator.pop(context);
                            AppPrimaryNavigationBar.navigateTo(context, AppPrimaryDestination.card);
                          },
                        ),
                        _buildStepItem(
                          context: context,
                          index: 2,
                          title: context.tr.onboardingMakeDeposit,
                          description: 'Adicione saldo Bitcoin à sua carteira recém-criada.',
                          isCompleted: progress.hasDeposit,
                          enabled: progress.hasCustodialWallet,
                          onTapAction: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/receive');
                          },
                        ),
                        _buildStepItem(
                          context: context,
                          index: 3,
                          title: context.tr.onboardingInternalTransfer,
                          description: 'Faça uma transferência instantânea sem taxas dentro da rede.',
                          isCompleted: progress.hasInternalTransfer,
                          enabled: progress.hasDeposit,
                          onTapAction: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/send-money');
                          },
                        ),
                      ].animate(interval: 80.ms).fade(duration: 250.ms).slideY(begin: 0.04, end: 0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required BuildContext context,
    required int index,
    required String title,
    required String description,
    required bool isCompleted,
    bool enabled = true,
    required VoidCallback onTapAction,
  }) {
    final statusColor = isCompleted
        ? AppColors.hexFF4ADE80
        : enabled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.24);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.hexFF141517,
        border: Border.all(color: AppColors.hexFF222222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled && !isCompleted ? onTapAction : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: isCompleted ? 0 : 1.5,
                  ),
                  color: isCompleted ? AppColors.hexFF4ADE80 : Colors.transparent,
                ),
                child: isCompleted
                    ? const Icon(
                        KeroseneIcons.success,
                        size: 16,
                        color: Colors.black,
                      )
                    : Center(
                        child: Text(
                          '$index',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: enabled ? Colors.white.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.24),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled && !isCompleted) ...[
                const SizedBox(width: 8),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      KeroseneIcons.chevronRight,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ] else if (!enabled) ...[
                const SizedBox(width: 8),
                Icon(
                  KeroseneIcons.security,
                  color: Colors.white.withValues(alpha: 0.16),
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
