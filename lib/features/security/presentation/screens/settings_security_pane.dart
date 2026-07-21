import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show authControllerProvider, sessionStorageScopeProvider;
import 'package:kerosene/core/telemetry/ledger_telemetry.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
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
            title: context.tr.settingsSecurityPasskeyOkTitle,
            message: context.tr.settingsSecurityPasskeyOkMessage,
          );
        }
        return;
      }

      if (context.mounted) {
        AppNotice.showError(
          context,
          title: context.tr.settingsSecurityPasskeyFailTitle,
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
          context.tr.settingsSecurityTitle,
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
          context.tr.settingsSecuritySubtitle,
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
          loading: () => SettingsLoadingPanel(
            label: context.tr.settingsSecurityLoading,
          ),
          error: (_, __) => SettingsEmptyPanel(
            icon: KeroseneIcons.warning,
            title: context.tr.settingsSecurityLoadErrorTitle,
            body: context.tr.settingsSecurityLoadErrorBody,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _LocalLedgerWipeSection(),
      ],
    );
  }
}

class _LedgerTelemetryRow extends ConsumerWidget {
  const _LedgerTelemetryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(ledgerTelemetrySnapshotProvider);
    return snap.when(
      data: (s) => SettingsSectionRow(
        icon: KeroseneIcons.history,
        title: context.tr.settingsSecurityLedgerDiagTitle,
        subtitle:
            'Pulls: ${s.fullPulls} full / ${s.incrementalPulls} incr. · '
            'offline: ${s.offlineServed} · fallback: ${s.statementFallback} · '
            'MAC: ${s.macDiscarded} · conf↑: ${s.mergeUpgraded}',
        onTap: () async {
          HapticFeedback.selectionClick();
          ref.invalidate(ledgerTelemetrySnapshotProvider);
        },
      ),
      loading: () => SettingsSectionRow(
        icon: KeroseneIcons.history,
        title: context.tr.settingsSecurityLedgerDiagTitle,
        subtitle: context.tr.settingsSecurityLedgerDiagLoading,
        onTap: () {},
      ),
      error: (_, __) => SettingsSectionRow(
        icon: KeroseneIcons.history,
        title: context.tr.settingsSecurityLedgerDiagTitle,
        subtitle: context.tr.settingsSecurityLedgerDiagUnavailable,
        onTap: () {},
      ),
    );
  }
}

/// Explicit wipe of on-device extrato. Logout never does this.
class _LocalLedgerWipeSection extends ConsumerWidget {
  const _LocalLedgerWipeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyPreferencesProvider);
    return SettingsSection(
      title: context.tr.settingsSecurityLocalDataSection,
      children: [
        SettingsSectionRow(
          icon: KeroseneIcons.lock,
          title: context.tr.settingsSecurityBlockCaptures,
          subtitle: privacy.blockFinancialScreenshots
              ? 'Ativo: impede screenshots e prévia no multitarefa (Android).'
              : 'Desligado. Ative para esconder saldo e extrato em capturas.',
          trailing: SettingsReadonlySwitch(
            value: privacy.blockFinancialScreenshots,
          ),
          onTap: () async {
            HapticFeedback.selectionClick();
            await ref
                .read(privacyPreferencesProvider.notifier)
                .setBlockFinancialScreenshots(
                  !privacy.blockFinancialScreenshots,
                );
          },
        ),
        SettingsSectionRow(
          icon: KeroseneIcons.trash,
          title: context.tr.settingsSecurityWipeLedgerTitle,
          subtitle: context.tr.settingsSecurityWipeLedgerSubtitle,
          onTap: () => _confirmAndWipe(context, ref),
        ),
        const _LedgerTelemetryRow(),
      ],
    );
  }

  Future<void> _confirmAndWipe(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KeroseneBrandTokens.surfaceMuted,
        title: Text(
          context.tr.settingsSecurityWipeConfirmTitle,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr.settingsSecurityWipeConfirmBody,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.tr.settingsSecurityWipeConfirmAction,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final scope = ref.read(sessionStorageScopeProvider);
    if (scope == null || scope.trim().isEmpty) {
      if (context.mounted) {
        AppNotice.showError(
          context,
          title: context.tr.settingsSecurityWipeSessionMissingTitle,
          message: context.tr.settingsSecurityWipeSessionMissingMessage,
        );
      }
      return;
    }

    try {
      await ref.read(localTransactionHistoryStoreProvider).clear(scope);
      ref.read(lastTransactionHistoryProvider.notifier).set(const []);
      ref.read(transactionHistoryCursorProvider.notifier).reset();
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(localTransactionHistoryProvider);
      if (context.mounted) {
        AppNotice.showInfo(
          context,
          title: context.tr.settingsSecurityWipeOkTitle,
          message: context.tr.settingsSecurityWipeOkMessage,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppNotice.showError(
          context,
          title: context.tr.settingsSecurityWipeFailTitle,
          message: e.toString(),
        );
      }
    }
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
          title: context.tr.settingsSecurityAccessSection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.lock,
              title: context.tr.settingsSecurityChangePinTitle,
              subtitle: appPin.enabled
                  ? context.tr.settingsSecurityChangePinEnabled
                  : context.tr.settingsSecurityChangePinDisabled,
              onTap: () => onOpenAppPin(appPin),
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.biometric,
              title: context.tr.settingsSecurityBiometricsTitle,
              subtitle: registeredPasskey
                  ? context.tr.settingsSecurityBiometricsOn
                  : context.tr.settingsSecurityBiometricsOff,
              trailing: SettingsReadonlySwitch(value: registeredPasskey),
              onTap: onRegisterPasskey,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.verified,
              title: context.tr.settingsSecurityTotpTitle,
              subtitle: profile.requiresTotp
                  ? context.tr.settingsSecurityTotpOn(settingsSecurityModeLabel(profile.mode))
                  : context.tr.settingsSecurityTotpOff,
              onTap: onOpenTotpSecurity,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: context.tr.settingsSecurityDevicesSection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.devices,
              title: context.tr.settingsSecurityAuthorizedDevicesTitle,
              subtitle: firstDevice == null
                  ? context.tr.settingsSecurityNoPasskeyDevice
                  : deviceCount == 1
                      ? context.tr.settingsSecurityOneDeviceManage(firstDevice.deviceName)
                      : context.tr.settingsSecurityNDevicesManage(deviceCount),
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsDevicesScreen());
              },
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.monitor,
              title: context.tr.settingsSecuritySessionsTitle,
              subtitle: deviceCount == 0
                  ? context.tr.settingsSecuritySessionsNone
                  : context.tr.settingsSecuritySessionsCount(deviceCount),
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
          title: context.tr.settingsSecurityRecoverySection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.inbox,
              title: context.tr.settingsSecurityAccountRecoveryTitle,
              subtitle: profile.requiresPassphrase
                  ? context.tr.settingsSecurityAccountRecoveryPassphrase
                  : context.tr.settingsSecurityAccountRecoveryCodes,
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsRecoveryHubScreen());
              },
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.download,
              title: context.tr.settingsSecurityBackupTitle,
              subtitle: context.tr.settingsSecurityBackupSubtitle,
              onTap: () {
                HapticFeedback.selectionClick();
                pushSettingsPage(context, const SettingsBackupCodesScreen());
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr.settingsSecurityAppPinLabel(settingsPinAttemptsLabel(appPin)),
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
