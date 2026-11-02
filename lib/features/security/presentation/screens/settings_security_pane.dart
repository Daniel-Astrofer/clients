import 'security_profile_view.dart';
import 'security_credential_enrollment_screen.dart';
import 'settings_account_confirmation.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart'
    deferred as statement;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show authControllerProvider, sessionStorageScopeProvider, AuthAuthenticated;
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
import 'settings_recovery_hub_screen.dart';
import 'settings_route_helpers.dart';
import 'settings_section_components.dart';

class SettingsSecurityPane extends ConsumerStatefulWidget {
  const SettingsSecurityPane({super.key});

  @override
  ConsumerState<SettingsSecurityPane> createState() =>
      _SettingsSecurityPaneState();
}

class _SettingsSecurityPaneState extends ConsumerState<SettingsSecurityPane> {
  bool _openingPin = false;

  @override
  Widget build(BuildContext context) {
    final ownerScope = ref.watch(sessionStorageScopeProvider)?.trim();
    Future<void> registerPasskey() async {
      await openCredentialEnrollment(context);
    }

    Future<void> openAppPinSheet(AppPinStatus status) async {
      if (_openingPin ||
          ownerScope == null ||
          !context.mounted ||
          ref.read(sessionStorageScopeProvider)?.trim() != ownerScope) {
        return;
      }
      _openingPin = true;
      try {
        final refreshed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          sheetAnimationStyle: AnimationStyle(
              duration: KeroseneMotion.duration(context, KeroseneMotion.short),
              reverseDuration:
                  KeroseneMotion.duration(context, KeroseneMotion.short)),
          builder: (_) => AppPinManagementSheet(
            ownerScope: ownerScope,
            initialStatus: status,
            mode: status.enabled
                ? AppPinSheetMode.change
                : AppPinSheetMode.enable,
          ),
        );

        if (refreshed == true &&
            context.mounted &&
            ref.read(sessionStorageScopeProvider)?.trim() == ownerScope) {
          ref.invalidate(accountSecurityProfileProvider);
          ref.invalidate(appPinStatusProvider);
          ref.invalidate(appPinManagementStatusProvider);
        }
      } finally {
        _openingPin = false;
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
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          context.tr.settingsSecuritySubtitle,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecurityProfileView(
            builder: (profile, current) => _SecurityAdvancedContent(
                profile: profile,
                mutationsAllowed: current,
                onOpenAppPin: openAppPinSheet,
                onOpenTotpSecurity: openTotpSecurity,
                onRegisterPasskey: registerPasskey)),
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
        subtitle: 'Pulls: ${s.fullPulls} full / ${s.incrementalPulls} incr. · '
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
class _LocalLedgerWipeSection extends ConsumerStatefulWidget {
  const _LocalLedgerWipeSection();
  @override
  ConsumerState<_LocalLedgerWipeSection> createState() =>
      _LocalLedgerWipeState();
}

class _LocalLedgerWipeState extends ConsumerState<_LocalLedgerWipeSection> {
  bool _wiping = false;
  bool _clearing = false;
  bool _savingPrivacy = false;
  bool _privacyFailed = false;
  String? _privacyScope;
  String? _wipeResult;
  bool _wipeFailed = false;
  String? _resultScope;

  bool _owns(String scope) =>
      mounted && ref.read(sessionStorageScopeProvider)?.trim() == scope;

  Future<void> _savePrivacy(bool enabled) async {
    if (_savingPrivacy) return;
    final scope = ref.read(sessionStorageScopeProvider)?.trim();
    setState(() {
      _savingPrivacy = true;
      _privacyFailed = false;
      _privacyScope = scope;
    });
    try {
      await ref
          .read(privacyPreferencesProvider.notifier)
          .setBlockFinancialScreenshots(enabled);
    } catch (_) {
      if (mounted && ref.read(sessionStorageScopeProvider)?.trim() == scope) {
        setState(() => _privacyFailed = true);
      }
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  Future<void> _confirmAndWipe() async {
    if (_wiping) return;
    final scope = ref.read(sessionStorageScopeProvider)?.trim();
    if (scope == null || scope.isEmpty) {
      setState(() {
        _resultScope = scope;
        _wipeFailed = true;
        _wipeResult = context.tr.settingsSecurityWipeSessionMissingMessage;
      });
      return;
    }
    final tr = context.tr;
    final auth = ref.read(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    setState(() {
      _wiping = true;
      _wipeFailed = false;
      _wipeResult = null;
      _resultScope = scope;
    });
    try {
      HapticFeedback.mediumImpact();
      final confirmed = await confirmAccountSetting(context,
          ownerScope: scope,
          accountName: user?.username,
          accountId: user?.id,
          title: tr.settingsSecurityWipeConfirmTitle,
          body: tr.settingsSecurityWipeConfirmBody,
          confirmLabel: tr.settingsSecurityWipeConfirmAction);
      if (!confirmed || !_owns(scope)) return;
      setState(() => _clearing = true);
      await ref.read(localTransactionHistoryStoreProvider).clear(scope);
      if (!mounted || !_owns(scope)) return;
      ref.read(lastTransactionHistoryProvider.notifier).set(const []);
      ref.read(transactionHistoryCursorProvider.notifier).reset();
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(localTransactionHistoryProvider);
      setState(() => _wipeResult = tr.settingsSecurityWipeOkMessage);
      AppNotice.showInfo(context,
          title: tr.settingsSecurityWipeOkTitle,
          message: tr.settingsSecurityWipeOkMessage);
    } catch (_) {
      if (!mounted || !_owns(scope)) return;
      setState(() {
        _wipeFailed = true;
        _wipeResult = tr.settingsSecurityWipeFailMessage;
      });
      AppNotice.showError(context,
          title: tr.settingsSecurityWipeFailTitle,
          message: tr.settingsSecurityWipeFailMessage);
    } finally {
      if (mounted) {
        setState(() {
          _wiping = false;
          _clearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyPreferencesProvider);
    final scope = ref.watch(sessionStorageScopeProvider)?.trim();
    final tr = context.tr;
    final showResult = _resultScope == scope && _wipeResult != null;
    return SettingsSection(
      title: tr.settingsSecurityLocalDataSection,
      children: [
        if (_savingPrivacy ||
            privacy.loading ||
            (_clearing && scope == _resultScope))
          TickerMode(
              enabled: !KeroseneMotion.reduceMotion(context),
              child: const LinearProgressIndicator(minHeight: 2)),
        SettingsSectionRow(
          icon: KeroseneIcons.lock,
          title: tr.settingsSecurityBlockCaptures,
          subtitle: privacy.loading
              ? tr.settingsSecurityLoading
              : privacy.readFailed
                  ? tr.settingsPrivacyLoadFailed
                  : privacy.blockFinancialScreenshots
                      ? tr.settingsPrivacyCaptureEnabled
                      : tr.settingsPrivacyCaptureDisabled,
          trailing: privacy.loading
              ? const SizedBox.shrink()
              : privacy.readFailed
                  ? const KeroseneIcon(KeroseneIcons.warning)
                  : SettingsReadonlySwitch(
                      value: privacy.blockFinancialScreenshots),
          onTap: _savingPrivacy || privacy.loading
              ? null
              : privacy.readFailed
                  ? () => ref.read(privacyPreferencesProvider.notifier).reload()
                  : () => _savePrivacy(!privacy.blockFinancialScreenshots),
        ),
        if (_privacyFailed && _privacyScope == scope)
          Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KeroseneIcon(KeroseneIcons.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(tr.settingsPreferenceSaveFailed,
                        style: AppTypography.bodyMedium)),
              ])),
        SettingsSectionRow(
          icon: KeroseneIcons.trash,
          title: tr.settingsSecurityWipeLedgerTitle,
          subtitle: tr.settingsSecurityWipeLedgerSubtitle,
          onTap: _wiping ? null : _confirmAndWipe,
        ),
        if (showResult)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KeroseneIcon(
                              _wipeFailed
                                  ? KeroseneIcons.error
                                  : KeroseneIcons.success,
                              size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(_wipeResult!,
                                  key: const ValueKey('settings-ledger-result'),
                                  style: AppTypography.bodyMedium)),
                        ]),
                    const SizedBox(height: 12),
                    AppButton(
                        label: _wipeFailed
                            ? tr.tryAgain
                            : tr.settingsSecurityViewStatement,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        onPressed: _wiping
                            ? null
                            : _wipeFailed
                                ? _confirmAndWipe
                                : () => pushSettingsDeferred(
                                    context,
                                    statement.loadLibrary,
                                    (_) => statement
                                        .TransactionStatementScreen())),
                  ])),
        ExpansionTile(
            title: Text(tr.settingsSecurityLedgerDiagTitle),
            children: const [_LedgerTelemetryRow()]),
      ],
    );
  }
}

class _SecurityAdvancedContent extends StatelessWidget {
  final AccountSecurityProfile profile;
  final bool mutationsAllowed;
  final Future<void> Function(AppPinStatus status) onOpenAppPin;
  final VoidCallback onOpenTotpSecurity;
  final Future<void> Function() onRegisterPasskey;

  const _SecurityAdvancedContent({
    required this.profile,
    this.mutationsAllowed = true,
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
              onTap: mutationsAllowed ? () => onOpenAppPin(appPin) : null,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.biometric,
              title: context.tr.settingsSecurityBiometricsTitle,
              subtitle: registeredPasskey
                  ? context.tr.settingsSecurityBiometricsOn
                  : context.tr.settingsSecurityBiometricsOff,
              trailing: KeroseneIcon(registeredPasskey
                  ? KeroseneIcons.verified
                  : KeroseneIcons.next),
              onTap: mutationsAllowed ? onRegisterPasskey : null,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.verified,
              title: context.tr.settingsSecurityTotpTitle,
              subtitle: profile.requiresTotp
                  ? context.tr.settingsSecurityTotpOn(
                      settingsSecurityModeLabel(profile.mode))
                  : context.tr.settingsSecurityTotpOff,
              onTap: mutationsAllowed ? onOpenTotpSecurity : null,
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
                      ? context.tr.settingsSecurityOneDeviceManage(
                          firstDevice.deviceName)
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
        SizedBox(height: AppSpacing.lg),
        Text(
          context.tr
              .settingsSecurityAppPinLabel(settingsPinAttemptsLabel(appPin)),
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
