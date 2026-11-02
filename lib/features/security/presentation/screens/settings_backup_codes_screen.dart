import 'security_change_result_screen.dart';
import 'settings_account_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import '../widgets/recovery_codes_sheet.dart';
import '../widgets/security_change_prompt.dart';
import '../providers/security_provider.dart'
    show accountSecurityProfileProvider;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';

import 'security_settings_components.dart';
import 'security_totp_screen.dart' deferred as security_totp;
import 'settings_navigation.dart';
import 'settings_route_helpers.dart';
import 'security_lookup.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';

/// Backup codes management — real API status + regenerate (requires TOTP).
class SettingsBackupCodesScreen extends ConsumerStatefulWidget {
  final String? ownerScope;
  const SettingsBackupCodesScreen({super.key, this.ownerScope});

  @override
  ConsumerState<SettingsBackupCodesScreen> createState() =>
      _SettingsBackupCodesScreenState();
}

class _SettingsBackupCodesScreenState
    extends ConsumerState<SettingsBackupCodesScreen>
    with WidgetsBindingObserver {
  List<String> _latestCodes = const [];
  bool _busy = false;
  String? _error;
  late final String? _ownerScope;
  bool _foreground = true;
  bool _openingCodes = false;
  bool _openingTotp = false;
  final _securityLookup = SecurityLookup<AccountSecurityStatusResult>();
  final _backupLookup = SecurityLookup<BackupCodesStatusResult>();
  final _profileLookup = SecurityLookup<AccountSecurityProfile>();

  bool get _protectionCurrent =>
      _ownsScreen &&
      _foreground &&
      securityLookupIsCurrent(ref.read(securityStatusProvider)) &&
      securityLookupIsCurrent(ref.read(accountSecurityProfileProvider));
  bool get _backupCurrent =>
      _protectionCurrent &&
      securityLookupIsCurrent(ref.read(backupCodesStatusProvider)) &&
      ref.read(securityStatusProvider).requireValue.totpEnabled;

  @override
  void initState() {
    super.initState();
    _ownerScope = widget.ownerScope ?? ref.read(sessionStorageScopeProvider);
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
    if (_foreground && _ownsScreen) _refresh();
  }

  bool get _ownsScreen =>
      mounted &&
      _ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

  void _refresh() {
    ref.invalidate(backupCodesStatusProvider);
    ref.invalidate(securityStatusProvider);
    ref.invalidate(accountSecurityProfileProvider);
  }

  Future<void> _regenerate() async {
    if (_busy || !_backupCurrent) return;
    // Lock before opening confirmation, including the before-render tap gap.
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await confirmAccountSetting(context,
          ownerScope: _ownerScope!,
          title: context.tr.securityBackupCodesTitle,
          body: context.tr.securityRegenerateCodesConfirmation,
          confirmLabel: context.tr.securityRegenerateCodesAction);
      if (!mounted || !confirmed || !_backupCurrent) return;
      final factors = await promptSecurityChange(context, ref, _ownerScope!);
      if (!mounted || factors == null || !_backupCurrent) return;
      setState(() => _latestCodes = const []);
      final result = await ref
          .read(authRepositoryProvider)
          .regenerateBackupCodes(factors: factors);
      if (!mounted || !_ownsScreen) return;
      _refresh();
      result.fold((failure) {
        setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
        AppNotice.showError(context,
            title: context.tr.securityBackupRegenerateFailedTitle,
            message: ErrorTranslator.translate(context.tr, failure.toString()));
      }, (status) {
        if (!status.enabled ||
            !hasUsableRecoveryCodes(status.newlyGeneratedCodes)) {
          setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
          AppNotice.showError(context,
              title: context.tr.securityBackupRegenerateFailedTitle,
              message: context.tr.securityUpdateUnconfirmedMessage);
          return;
        }
        setState(() => _latestCodes = status.newlyGeneratedCodes);
        pushSettingsResultPage<bool>(
            context,
            SecurityChangeResultScreen(
                ownerScope: _ownerScope!,
                title: context.tr.securityBackupCodesTitle,
                body: context.tr.securityResultCodesChangedBody,
                codes: status.newlyGeneratedCodes));
      });
    } catch (error) {
      if (mounted && _ownsScreen) {
        setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
        AppNotice.showError(context,
            title: context.tr.securityBackupRegenerateFailedTitle,
            message: context.tr.securityUpdateUnconfirmedMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCodesSheet(List<String> codes) async {
    if (!_ownsScreen || !_foreground || _openingCodes || codes.isEmpty) return;
    setState(() => _openingCodes = true);
    try {
      await showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          sheetAnimationStyle: AnimationStyle(
              duration: KeroseneMotion.duration(context, KeroseneMotion.short),
              reverseDuration:
                  KeroseneMotion.duration(context, KeroseneMotion.short)),
          builder: (_) =>
              RecoveryCodesSheet(codes: codes, ownerScope: _ownerScope));
    } finally {
      if (mounted) setState(() => _openingCodes = false);
    }
  }

  Future<void> _openTotp() async {
    if (_openingTotp || _busy || !_protectionCurrent) return;
    setState(() => _openingTotp = true);
    try {
      await security_totp.loadLibrary();
      if (!mounted || !_protectionCurrent) return;
      await pushSettingsResultPage<void>(
          context, security_totp.SecurityTotpScreen());
    } catch (_) {
      if (mounted && _ownsScreen && _foreground) {
        AppNotice.showError(context,
            message: context.tr.securityStatusLoadError);
      }
    } finally {
      if (mounted) setState(() => _openingTotp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    if (!_ownsScreen) {
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
    final securityAsync = ref.watch(securityStatusProvider);
    final backupAsync = ref.watch(backupCodesStatusProvider);
    final profileAsync = ref.watch(accountSecurityProfileProvider);
    _securityLookup.observe(_ownerScope, securityAsync);
    _backupLookup.observe(_ownerScope, backupAsync);
    _profileLookup.observe(_ownerScope, profileAsync);
    final security = _securityLookup.last;
    final backup = _backupLookup.last;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final mayRegenerate = !_busy && _backupCurrent;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
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
                          IgnorePointer(
                              ignoring: _busy,
                              child: Opacity(
                                  opacity: _busy ? .5 : 1,
                                  child: SettingsHeader(onClose: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).maybePop();
                                  }))),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(context.tr.settingsBackupTitle,
                              style: AppTypography.playfairDisplay(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2)),
                          const SizedBox(height: AppSpacing.md),
                          Text(context.tr.settingsBackupSubtitle,
                              style: AppTypography.inter(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 16,
                                  height: 1.55)),
                          const SizedBox(height: AppSpacing.xxl),
                          SecurityLookupNotice(sources: [
                            (
                              label: context.tr.twoFactorAuth,
                              lookup: _securityLookup
                            ),
                            (
                              label: context.tr.securityBackupCodesTitle,
                              lookup: _backupLookup
                            ),
                            (
                              label: context.tr.securityScreenTitle,
                              lookup: _profileLookup
                            ),
                          ], onRetry: _busy ? null : _refresh),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const KeroseneIcon(KeroseneIcons.error,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(_error!,
                                              key: const ValueKey(
                                                  'backup-inline-error')))
                                    ])),
                          if (security == null)
                            securityAsync.isLoading
                                ? const SecurityLoadingCard()
                                : SecurityErrorCard(
                                    title: context.tr.securityScreenTitle,
                                    body: context.tr.securityStatusLoadError)
                          else if (!security.totpEnabled)
                            SecuritySectionCard(
                                title: context.tr.securityBackupCodesTitle,
                                subtitle: context
                                    .tr.securityBackupCodesLockedSubtitle,
                                actionLabel:
                                    context.tr.securityEnableTotpAction,
                                disabled: _busy ||
                                    _openingTotp ||
                                    !_protectionCurrent,
                                onAction:
                                    _busy || _openingTotp || !_protectionCurrent
                                        ? null
                                        : _openTotp)
                          else if (backup == null)
                            backupAsync.isLoading
                                ? const SecurityLoadingCard()
                                : SecurityErrorCard(
                                    title: context.tr.securityBackupCodesTitle,
                                    body:
                                        context.tr.securityBackupCodesLoadError)
                          else
                            SecuritySectionCard(
                                title: context.tr.securityBackupCodesTitle,
                                subtitle: context.tr
                                    .securityBackupCodesRemaining(
                                        backup.remainingCodes),
                                actionLabel:
                                    context.tr.securityRegenerateCodesAction,
                                disabled: !mayRegenerate,
                                onAction: mayRegenerate ? _regenerate : null,
                                trailing: _latestCodes.isNotEmpty
                                    ? TextButton(
                                        onPressed: _busy || _openingCodes
                                            ? null
                                            : () =>
                                                _showCodesSheet(_latestCodes),
                                        child: Text(context
                                            .tr.securityViewLatestAction))
                                    : null),
                        ]),
                  ))),
                )
              ]),
        ),
      ),
    );
  }
}
