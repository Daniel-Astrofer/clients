import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'settings_backup_codes_screen.dart';
import 'settings_modern_components.dart';
import 'settings_navigation.dart';
import 'settings_route_helpers.dart';
import 'settings_section_components.dart';

/// Recovery hub — real links only (backup codes, emergency recovery, mode status).
class SettingsRecoveryHubScreen extends ConsumerWidget {
  const SettingsRecoveryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(accountSecurityProfileProvider);
    final securityAsync = ref.watch(securityStatusProvider);
    final backupAsync = ref.watch(backupCodesStatusProvider);
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl2,
                AppSpacing.md,
                AppSpacing.xl2,
                viewPadding.bottom + AppSpacing.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: context.responsive.appColumnConstraints,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsHeader(
                          onClose: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).maybePop();
                          },
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          context.tr.settingsRecoveryHubTitle,
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
                          context.tr.settingsRecoveryHubSubtitle,
                          style: AppTypography.inter(
                            color: KeroseneBrandTokens.textSecondary,
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        profileAsync.when(
                          data: (profile) {
                            final modeLabel = switch (profile.mode) {
                              AccountSecurityMode.standard => 'Padrão',
                              AccountSecurityMode.shamir => 'Shamir / shares',
                              AccountSecurityMode.multisig2fa => 'Multisig 2FA',
                              AccountSecurityMode.passkey => 'Passkey',
                            };
                            final totpOn =
                                securityAsync.asData?.value.totpEnabled == true;
                            final remaining =
                                backupAsync.asData?.value.remainingCodes;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SettingsSection(
                                  title: context.tr.sendReviewStatus,
                                  children: [
                                    SettingsSectionRow(
                                      icon: KeroseneIcons.security,
                                      title: context
                                          .tr.settingsRecoverySecurityMode,
                                      subtitle: modeLabel,
                                      onTap: null,
                                    ),
                                    SettingsSectionRow(
                                      icon: KeroseneIcons.verified,
                                      title: 'TOTP',
                                      subtitle: totpOn
                                          ? 'Ativo — backup codes disponíveis'
                                          : 'Inativo — ative 2FA para códigos de backup',
                                      onTap: null,
                                    ),
                                    if (remaining != null)
                                      SettingsSectionRow(
                                        icon: KeroseneIcons.download,
                                        title: context
                                            .tr.settingsRecoveryCodesRemaining,
                                        subtitle:
                                            '$remaining código(s) de backup',
                                        onTap: null,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                SettingsSection(
                                  title: 'Ações',
                                  children: [
                                    SettingsSectionRow(
                                      icon: KeroseneIcons.download,
                                      title: context.tr.settingsBackupTitle,
                                      subtitle: totpOn
                                          ? 'Ver status e regenerar códigos'
                                          : 'Requer 2FA — abra para configurar',
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        pushSettingsPage(
                                          context,
                                          const SettingsBackupCodesScreen(),
                                        );
                                      },
                                    ),
                                    SettingsSectionRow(
                                      icon: KeroseneIcons.inbox,
                                      title:
                                          context.tr.settingsRecoveryEmergency,
                                      subtitle: context
                                          .tr.settingsRecoveryEmergencyBody,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const EmergencyRecoveryScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    if (profile.requiresPassphrase)
                                      SettingsSectionRow(
                                        icon: KeroseneIcons.lock,
                                        title: 'Frase / shares',
                                        subtitle: profile.requiresShamirShares
                                            ? 'Conta exige shares SLIP39 para recuperação'
                                            : 'Conta exige passphrase nos fluxos sensíveis',
                                        onTap: null,
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          error: (error, _) => SettingsGlassPanel(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              ErrorTranslator.translate(
                                context.tr,
                                error.toString(),
                              ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
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
}
