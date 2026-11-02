import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'security_lookup.dart';
import 'settings_backup_codes_screen.dart';
import 'settings_navigation.dart';
import 'settings_route_helpers.dart';
import 'settings_section_components.dart';

/// Account recovery paths remain reachable while status is unavailable.
/// Navigation does not recover an account or change its protection.
class SettingsRecoveryHubScreen extends ConsumerStatefulWidget {
  const SettingsRecoveryHubScreen({super.key});

  @override
  ConsumerState<SettingsRecoveryHubScreen> createState() => _RecoveryHubState();
}

class _RecoveryHubState extends ConsumerState<SettingsRecoveryHubScreen>
    with WidgetsBindingObserver {
  late final String? _ownerScope;
  bool _foreground = true;
  bool _opening = false;
  final _profile = SecurityLookup<AccountSecurityProfile>();
  final _security = SecurityLookup<AccountSecurityStatusResult>();
  final _backup = SecurityLookup<BackupCodesStatusResult>();

  bool get _owns =>
      mounted &&
      _ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (_foreground && _owns) _refresh();
  }

  void _refresh() {
    if (!_owns || !_foreground) return;
    ref.invalidate(accountSecurityProfileProvider);
    ref.invalidate(securityStatusProvider);
    ref.invalidate(backupCodesStatusProvider);
  }

  Future<void> _open(Widget page) async {
    if (!_owns || !_foreground || _opening) return;
    setState(() => _opening = true);
    HapticFeedback.selectionClick();
    try {
      await pushSettingsResultPage<void>(context, page);
    } catch (_) {
      if (mounted && _owns && _foreground) {
        AppNotice.showError(context,
            message: context.tr.recoveryNavigationFailed);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _modeLabel(AccountSecurityMode mode) => switch (mode) {
        AccountSecurityMode.standard => context.tr.recoveryModeStandard,
        AccountSecurityMode.passkey => context.tr.recoveryModePasskey,
        AccountSecurityMode.shamir => context.tr.recoveryModeShamir,
        AccountSecurityMode.multisig2fa => context.tr.recoveryModeMultisig,
      };

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    if (!_owns) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(context.tr.securitySessionChangedMessage),
        TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.tr.close)),
      ]))));
    }
    if (!_foreground) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Text(context.tr.securitySensitiveHiddenMessage))));
    }
    final profileAsync = ref.watch(accountSecurityProfileProvider);
    final securityAsync = ref.watch(securityStatusProvider);
    final backupAsync = ref.watch(backupCodesStatusProvider);
    _profile.observe(_ownerScope, profileAsync);
    _security.observe(_ownerScope, securityAsync);
    _backup.observe(_ownerScope, backupAsync);
    final profile = _profile.last;
    final security = _security.last;
    final backup = _backup.last;
    final tr = context.tr;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child:
            CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xl2, AppSpacing.md,
                AppSpacing.xl2, viewPadding.bottom + AppSpacing.xxl),
            sliver: SliverToBoxAdapter(
                child: Center(
                    child: ConstrainedBox(
              constraints: context.responsive.appColumnConstraints,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsHeader(
                        onClose: () => Navigator.of(context).maybePop()),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(tr.settingsRecoveryHubTitle,
                        style: AppTypography.playfairDisplay(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            height: 1.2)),
                    const SizedBox(height: AppSpacing.md),
                    Text(tr.settingsRecoveryHubSubtitle,
                        style: AppTypography.inter(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.55)),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsSection(title: tr.actions, children: [
                      SettingsSectionRow(
                          key: const ValueKey('recovery-open-codes'),
                          icon: KeroseneIcons.recovery,
                          title: tr.securityBackupCodesTitle,
                          subtitle: tr.recoveryManageCodesBody,
                          onTap: _opening
                              ? null
                              : () => _open(SettingsBackupCodesScreen(
                                  ownerScope: _ownerScope))),
                      SettingsSectionRow(
                          key: const ValueKey('recovery-open-emergency'),
                          icon: KeroseneIcons.key,
                          title: tr.settingsRecoveryEmergency,
                          subtitle: tr.settingsRecoveryEmergencyBody,
                          onTap: _opening
                              ? null
                              : () => _open(const EmergencyRecoveryScreen())),
                    ]),
                    const SizedBox(height: AppSpacing.xxl),
                    SecurityLookupNotice(
                        sources: [
                          (
                            label: tr.settingsRecoverySecurityMode,
                            lookup: _profile
                          ),
                          (
                            label: tr.securityAuthenticatorTitle,
                            lookup: _security
                          ),
                          (
                            label: tr.settingsRecoveryCodesRemaining,
                            lookup: _backup
                          ),
                        ],
                        onRetry: _refresh,
                        failureMessage: tr.recoveryStatusLookupFailure),
                    SettingsSection(
                        title: tr.settingsRecoveryStatus,
                        children: [
                          SettingsSectionRow(
                              icon: KeroseneIcons.security,
                              title: tr.settingsRecoverySecurityMode,
                              subtitle: profile != null
                                  ? _modeLabel(profile.mode)
                                  : profileAsync.hasError
                                      ? tr.securityStatusLoadError
                                      : tr.loading,
                              onTap: null),
                          SettingsSectionRow(
                              icon: security == null
                                  ? (securityAsync.hasError
                                      ? KeroseneIcons.warning
                                      : KeroseneIcons.pending)
                                  : security.totpEnabled
                                      ? KeroseneIcons.success
                                      : KeroseneIcons.shieldOff,
                              title: tr.securityAuthenticatorTitle,
                              subtitle: security != null
                                  ? (security.totpEnabled
                                      ? tr.securityAuthenticatorActive
                                      : tr.securityAuthenticatorInactive)
                                  : securityAsync.hasError
                                      ? tr.securityStatusLoadError
                                      : tr.loading,
                              onTap: null),
                          SettingsSectionRow(
                              icon: KeroseneIcons.recovery,
                              title: tr.settingsRecoveryCodesRemaining,
                              subtitle: backup != null
                                  ? tr.securityBackupCodesRemaining(
                                      backup.remainingCodes)
                                  : backupAsync.hasError
                                      ? tr.securityBackupCodesLoadError
                                      : tr.loading,
                              onTap: null),
                          if (profile?.requiresPassphrase == true)
                            SettingsSectionRow(
                                icon: KeroseneIcons.lock,
                                title: profile!.requiresShamirShares
                                    ? tr.recoverySharesTitle
                                    : tr.recoveryPassphraseTitle,
                                subtitle: profile.requiresShamirShares
                                    ? tr.recoverySharesBody
                                    : tr.recoveryPassphraseBody,
                                onTap: null),
                        ]),
                  ]),
            ))),
          )
        ]),
      ),
    );
  }
}
