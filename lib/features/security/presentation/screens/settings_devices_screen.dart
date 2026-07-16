import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'security_settings_components.dart';
import 'settings_modern_components.dart';
import 'settings_navigation.dart';

/// Authorized passkey/device-key inventory — real data, no placeholders.
class SettingsDevicesScreen extends ConsumerStatefulWidget {
  const SettingsDevicesScreen({super.key});

  @override
  ConsumerState<SettingsDevicesScreen> createState() =>
      _SettingsDevicesScreenState();
}

class _SettingsDevicesScreenState extends ConsumerState<SettingsDevicesScreen> {
  bool? _needsLegacyMigration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeLegacyMigration());
  }

  Future<void> _probeLegacyMigration() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      if (mounted) setState(() => _needsLegacyMigration = false);
      return;
    }
    final username = auth.user.username;
    final hasDeviceKey =
        await DeviceKeyService.instance.hasRegisteredDeviceKey(username);
    final hasShaped =
        await PasskeyService.instance.hasRegisteredPasskey(username: username);
    if (!mounted) return;
    setState(() => _needsLegacyMigration = hasShaped && !hasDeviceKey);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(accountSecurityProfileProvider);
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: KeroseneBrandTokens.surfaceMuted,
          onRefresh: () async {
            ref.invalidate(accountSecurityProfileProvider);
            await ref.read(accountSecurityProfileProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                            context.tr.settingsDevicesTitle,
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
                            'Chaves do dispositivo vinculadas à sua conta. Use este aparelho para assinar transferências. Bloqueie ou revogue acessos que não reconhece.',
                            style: AppTypography.inter(
                              color: KeroseneBrandTokens.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.55,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          if (_needsLegacyMigration == true) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: KeroseneBrandTokens.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: KeroseneBrandTokens.textSecondary
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Atualize a chave deste aparelho',
                                    style: AppTypography.inter(
                                      color: KeroseneBrandTokens.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Detectamos uma chave legada neste install. '
                                    'Transferências e login biométrico agora usam a '
                                    'Chave do dispositivo. Toque abaixo para configurar.',
                                    style: AppTypography.inter(
                                      color: KeroseneBrandTokens.textSecondary,
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          profileAsync.when(
                            data: (profile) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PasskeyInventoryCard(
                                  inventory: profile.passkeys,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                FilledButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.selectionClick();
                                    final result = await ref
                                        .read(authControllerProvider.notifier)
                                        .registerPasskey();
                                    ref.invalidate(
                                      accountSecurityProfileProvider,
                                    );
                                    await _probeLegacyMigration();
                                    if (!context.mounted) return;
                                    if (result.isSuccess) {
                                      AppNotice.showInfo(
                                        context,
                                        title: context.tr.settingsDevicesPasskeyRegistered,
                                        message:
                                            'Chave do dispositivo vinculada. A lista foi atualizada.',
                                      );
                                    } else if (result.isDeviceConflict) {
                                      AppNotice.showInfo(
                                        context,
                                        title: context.tr.settingsDevicesInUse,
                                        message:
                                            'Confirme a desvinculação em Configurações → Biometria se precisar reatribuir.',
                                      );
                                    } else if (result.isFailure) {
                                      AppNotice.showError(
                                        context,
                                        title: context.tr.settingsDevicesRegisterFail,
                                        message: ErrorTranslator.translate(
                                          context.tr,
                                          result.message,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(KeroseneIcons.biometric),
                                  label: Text(
                                    context.tr.settingsDevicesRegisterPasskey,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                ),
                              ],
                            ),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    context.tr.settingsDevicesLoadError,
                                    style: AppTypography.inter(
                                      color: KeroseneBrandTokens.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    ErrorTranslator.translate(
                                      context.tr,
                                      error.toString(),
                                    ),
                                    style: AppTypography.inter(
                                      color: KeroseneBrandTokens.textMuted,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextButton(
                                    onPressed: () => ref.invalidate(
                                      accountSecurityProfileProvider,
                                    ),
                                    child: Text(context.tr.settingsDevicesRetry),
                                  ),
                                ],
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
      ),
    );
  }
}
