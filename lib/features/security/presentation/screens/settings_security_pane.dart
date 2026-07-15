import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'security_app_pin_sheet.dart';
import 'security_totp_screen.dart' deferred as security_totp;
import 'settings_backup_codes_screen.dart';
import 'settings_devices_screen.dart';
import 'settings_formatters.dart';
import 'settings_modern_components.dart';
import 'settings_recovery_hub_screen.dart';
import 'settings_route_helpers.dart';
import 'settings_section_components.dart';

class _SettingsSecurityPaneCopy {
  const _SettingsSecurityPaneCopy._();

  static const title = 'Seguran\u00e7a';
  static const description =
      'Proteja sua conta com autentica\u00e7\u00e3o, acesso local e controles de recupera\u00e7\u00e3o.';
}

class SettingsSecurityPane extends ConsumerWidget {
  const SettingsSecurityPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(accountSecurityProfileProvider);

    Future<void> registerPasskey({bool confirmUnlinkDevice = false}) async {
      final result =
          await ref.read(authControllerProvider.notifier).registerPasskey(
                confirmUnlinkDevice: confirmUnlinkDevice,
              );
      if (!context.mounted) return;

      if (result.isDeviceConflict) {
        final l10n = context.tr;
        final data = result.data is Map
            ? Map<String, dynamic>.from(result.data as Map)
            : const <String, dynamic>{};
        final previous = (data['previousUsernameMasked'] ??
                data['previous_username_masked'] ??
                '***')
            .toString();
        final guidanceRaw = data['guidance']?.toString().trim();
        final guidance = (guidanceRaw == null || guidanceRaw.isEmpty)
            ? l10n.authDeviceUnlinkDefaultGuidance
            : guidanceRaw;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.authDeviceUnlinkTitle),
            content: Text(l10n.authDeviceUnlinkBody(previous, guidance)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.authDeviceUnlinkCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.authDeviceUnlinkConfirmLink,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await registerPasskey(confirmUnlinkDevice: true);
        }
        return;
      }

      if (result.isSuccess) {
        ref.invalidate(accountSecurityProfileProvider);
        if (context.mounted) {
          AppNotice.showInfo(
            context,
            title: 'Passkey cadastrada',
            message:
                'Este dispositivo foi vinculado à sua conta. Biometria liberada para login e confirmações.',
          );
        }
        return;
      }

      if (context.mounted) {
        AppNotice.showError(
          context,
          title: 'Não foi possível cadastrar a passkey',
          message: ErrorTranslator.translate(context.tr, result.message),
        );
      }
    }

    Future<void> openAppPinSheet(AppPinStatus status) async {
      final refreshed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AppPinManagementSheet(
          initialStatus: status,
          mode:
              status.enabled ? AppPinSheetMode.change : AppPinSheetMode.enable,
        ),
      );

      if (refreshed == true) {
        ref.invalidate(accountSecurityProfileProvider);
        ref.invalidate(appPinStatusProvider);
      }
    }

    void openTotpSecurity() {
      pushSettingsDeferred(
        context,
        security_totp.loadLibrary,
        (_) => security_totp.SecurityTotpScreen(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _SettingsSecurityPaneCopy.title,
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
          _SettingsSecurityPaneCopy.description,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        profileAsync.when(
          data: (profile) => _SecurityAdvancedContent(
            profile: profile,
            onOpenAppPin: openAppPinSheet,
            onOpenTotpSecurity: openTotpSecurity,
            onRegisterPasskey: registerPasskey,
          ),
          loading: () => const SettingsLoadingPanel(
            label: 'Carregando perfil de segurança',
          ),
          error: (_, __) => const SettingsEmptyPanel(
            icon: KeroseneIcons.warning,
            title: 'Não conseguimos carregar a segurança',
            body: 'Revise sua conexão e tente novamente.',
          ),
        ),
      ],
    );
  }
}

class _SecurityAdvancedContent extends StatelessWidget {
  final AccountSecurityProfile profile;
  final Future<void> Function(AppPinStatus status) onOpenAppPin;
  final VoidCallback onOpenTotpSecurity;
  final Future<void> Function() onRegisterPasskey;

  const _SecurityAdvancedContent({
    required this.profile,
    required this.onOpenAppPin,
    required this.onOpenTotpSecurity,
    required this.onRegisterPasskey,
  });

  @override
  Widget build(BuildContext context) {
    final appPin = profile.appPin;
    final registeredPasskey = profile.passkeys?.passkeyRegistered == true;
    final knownDevices = profile.passkeys?.devices ?? const [];
    final firstDevice = knownDevices.isEmpty ? null : knownDevices.first;
    final deviceCount = knownDevices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Proteção de acesso',
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.lock,
              title: 'Alterar PIN',
              subtitle: appPin.enabled
                  ? 'Atualize seu código de 4 dígitos'
                  : 'Configure um código de 4 dígitos',
              onTap: () => onOpenAppPin(appPin),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.biometric,
              title: 'Biometria',
              subtitle: registeredPasskey
                  ? 'Usar digital para entrar no app'
                  : 'Registre uma passkey neste dispositivo',
              trailing: SettingsReadonlySwitch(value: registeredPasskey),
              onTap: onRegisterPasskey,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.verified,
              title: 'Autenticação em 2 fatores',
              subtitle: profile.requiresTotp
                  ? 'Ativa no modo ${settingsSecurityModeLabel(profile.mode)}'
                  : 'Validar TOTP e ativar proteção extra',
              onTap: onOpenTotpSecurity,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: 'Dispositivos e acesso',
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.devices,
              title: 'Dispositivos autorizados',
              subtitle: firstDevice == null
                  ? 'Nenhum dispositivo com passkey'
                  : deviceCount == 1
                      ? '${firstDevice.deviceName} · gerenciar'
                      : '$deviceCount dispositivos · gerenciar',
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsDevicesScreen());
              },
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.monitor,
              title: 'Sessões e dispositivos',
              subtitle: deviceCount == 0
                  ? 'Acesso ligado a passkeys deste aparelho'
                  : '$deviceCount acesso(s) com chave registrada',
              onTap: () {
                // Sessions JWT are not exposed as a separate API — device keys
                // are the product model for authorized access.
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsDevicesScreen());
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: 'Recuperação',
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.inbox,
              title: 'Recuperação da conta',
              subtitle: profile.requiresPassphrase
                  ? 'Frase, shares e emergência'
                  : 'Backup codes e recuperação de emergência',
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsRecoveryHubScreen());
              },
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.download,
              title: 'Backup de segurança',
              subtitle: 'Códigos de recuperação (2FA)',
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsBackupCodesScreen());
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'PIN do app: ${settingsPinAttemptsLabel(appPin)}',
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textMuted,
            fontSize: 12,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
