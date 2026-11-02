import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'security_change_result_screen.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'settings_account_confirmation.dart';
import 'settings_route_helpers.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import '../widgets/recovery_codes_sheet.dart';
import '../widgets/security_change_prompt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/design_system/components/generic/kerosene_screen_background.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'security_settings_components.dart';
import 'settings_navigation.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'security_lookup.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';

class SecurityTotpScreen extends ConsumerStatefulWidget {
  const SecurityTotpScreen({super.key});

  @override
  ConsumerState<SecurityTotpScreen> createState() => _SecurityTotpScreenState();
}

class _SecurityTotpScreenState extends ConsumerState<SecurityTotpScreen>
    with WidgetsBindingObserver {
  final _totpCodeController = TextEditingController();

  String _setupUri = '';
  String _setupSecret = '';
  List<String> _latestGeneratedCodes = const [];
  bool _busy = false;
  String? _error;
  String? _busyMessage;
  late final String? _ownerScope;
  bool _foreground = true;
  bool _openingCodes = false;
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
    _ownerScope = ref.read(sessionStorageScopeProvider);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _ownsScreen =>
      mounted &&
      _ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _totpCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _totpCodeController.clear();
    });
    if (_foreground && _ownsScreen) _refreshSecurityProviders();
  }

  Future<void> _run(String message, Future<void> Function() action) async {
    if (_busy || !_ownsScreen || !_foreground) {
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = message;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && _ownsScreen) {
        setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
        AppNotice.showError(context,
            title: context.tr.securityTotpFailureTitle,
            message: error is AppException || error is DeviceKeyException
                ? ErrorTranslator.translate(context.tr, error.toString())
                : context.tr.securityUpdateUnconfirmedMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _refreshSecurityProviders() {
    ref.invalidate(securityStatusProvider);
    ref.invalidate(backupCodesStatusProvider);
    ref.invalidate(accountSecurityProfileProvider);
  }

  Future<void> _beginTotpSetup() async {
    if (!_protectionCurrent) return;
    await _run(context.tr.securityTotpPreparingMessage, () async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.setupTotp();
      if (!mounted || !_ownsScreen) return;
      result.fold(
        (failure) {
          setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
          AppNotice.showError(
            context,
            title: context.tr.securityTotpFailureTitle,
            message: ErrorTranslator.translate(context.tr, failure.toString()),
          );
        },
        (setup) {
          if (setup.otpUri.isEmpty || setup.secret.isEmpty) {
            setState(
                () => _error = context.tr.securityUpdateUnconfirmedMessage);
            AppNotice.showError(context,
                title: context.tr.securityTotpFailureTitle,
                message: context.tr.securityUpdateUnconfirmedMessage);
            return;
          }
          setState(() {
            _setupUri = setup.otpUri;
            _setupSecret = setup.secret;
            _totpCodeController.clear();
          });
        },
      );
    });
  }

  Future<void> _verifyTotpSetup() async {
    if (_busy || !_protectionCurrent) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_totpCodeController.text.trim())) {
      setState(() => _error = context.tr.securityTotpCodeRequiredMessage);
      AppNotice.showError(
        context,
        title: context.tr.securityInvalidCodeTitle,
        message: context.tr.securityTotpCodeRequiredMessage,
      );
      return;
    }

    await _run(context.tr.securityTotpValidating, () async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.verifyTotpSetup(
        totpCode: _totpCodeController.text.trim(),
      );
      if (!mounted || !_ownsScreen) return;
      _refreshSecurityProviders();
      result.fold(
        (failure) {
          if (failure.errorCode == 'AUTH_011') {
            setState(() {
              _setupUri = '';
              _setupSecret = '';
              _totpCodeController.clear();
            });
          }
          setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
          AppNotice.showError(
            context,
            title: context.tr.securityTotpFailureTitle,
            message: ErrorTranslator.translate(context.tr, failure.toString()),
          );
        },
        (status) {
          if (!status.enabled ||
              !hasUsableRecoveryCodes(status.newlyGeneratedCodes)) {
            setState(
                () => _error = context.tr.securityUpdateUnconfirmedMessage);
            AppNotice.showError(context,
                title: context.tr.securityTotpFailureTitle,
                message: context.tr.securityUpdateUnconfirmedMessage);
            return;
          }
          setState(() {
            _setupUri = '';
            _setupSecret = '';
            _latestGeneratedCodes = status.newlyGeneratedCodes;
          });
          _refreshSecurityProviders();
          AppNotice.showSuccess(
            context,
            title: context.tr.securityTotpEnabledTitle,
            message: context.tr.securityTotpEnabledMessage,
          );
          if (status.newlyGeneratedCodes.isNotEmpty) {
            _showResult(context.tr.securityTotpEnabledTitle,
                context.tr.securityTotpEnabledMessage,
                codes: status.newlyGeneratedCodes);
          }
        },
      );
    });
  }

  Future<bool> _confirmChange(String body, String action) =>
      confirmAccountSetting(context,
          ownerScope: _ownerScope!,
          title: action,
          body: body,
          confirmLabel: action);

  void _showResult(String title, String body, {List<String> codes = const []}) {
    if (!_ownsScreen) return;
    pushSettingsResultPage<bool>(
        context,
        SecurityChangeResultScreen(
            ownerScope: _ownerScope!, title: title, body: body, codes: codes));
  }

  Future<void> _disableTotp() async {
    if (!_protectionCurrent) return;
    await _run(context.tr.securityChangeProcessingMessage, () async {
      final profile = (await ref.read(accountSecurityProfileProvider.future))
          .forAccountSecurityChange();
      if (!mounted || !_ownsScreen) return;
      if (profile.requiresTotp) {
        AppNotice.showInfo(context,
            title: context.tr.twoFactorAuth,
            message: context.tr.securityTotpRequiredSubtitle);
        return;
      }
      if (!await _confirmChange(context.tr.securityDisableTotpConfirmation,
              context.tr.securityDisableTotpAction) ||
          !mounted ||
          !_ownsScreen) {
        return;
      }
      final factors = await promptSecurityChange(context, ref, _ownerScope!);
      if (!mounted || factors == null || !_protectionCurrent) return;
      setState(() => _latestGeneratedCodes = const []);
      final result =
          await ref.read(authRepositoryProvider).disableTotp(factors: factors);
      if (!mounted || !_ownsScreen) return;
      _refreshSecurityProviders();
      result.fold((failure) {
        setState(() => _error = context.tr.securityUpdateUnconfirmedMessage);
        AppNotice.showError(context,
            title: context.tr.securityTotpDisableFailedTitle,
            message: ErrorTranslator.translate(context.tr, failure.toString()));
      }, (_) {
        setState(() {
          _setupUri = '';
          _setupSecret = '';
          _totpCodeController.clear();
        });
        AppNotice.showSuccess(context,
            title: context.tr.securityTotpDisabledTitle,
            message: context.tr.securityTotpDisabledMessage);
        _showResult(context.tr.securityTotpDisabledTitle,
            context.tr.securityTotpDisabledMessage);
      });
    });
  }

  Future<void> _regenerateBackupCodes() async {
    if (!_backupCurrent) return;
    await _run(context.tr.securityChangeProcessingMessage, () async {
      if (!await _confirmChange(context.tr.securityRegenerateCodesConfirmation,
              context.tr.securityRegenerateCodesAction) ||
          !mounted ||
          !_ownsScreen) {
        return;
      }
      final factors = await promptSecurityChange(context, ref, _ownerScope!);
      if (!mounted || factors == null || !_backupCurrent) return;
      setState(() => _latestGeneratedCodes = const []);
      final result = await ref
          .read(authRepositoryProvider)
          .regenerateBackupCodes(factors: factors);
      if (!mounted || !_ownsScreen) return;
      _refreshSecurityProviders();
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
        setState(() => _latestGeneratedCodes = status.newlyGeneratedCodes);
        _showResult(context.tr.securityBackupCodesTitle,
            context.tr.securityResultCodesChangedBody,
            codes: status.newlyGeneratedCodes);
      });
    });
  }

  Future<void> _showBackupCodesSheet(List<String> codes) async {
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

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    if (!_ownsScreen) {
      return FinancialSecureScope(
          child: Scaffold(
              body: SafeArea(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(context.tr.securitySessionChangedMessage),
        TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.tr.close)),
      ])))));
    }
    if (!_foreground) {
      return FinancialSecureScope(
          child: Scaffold(
              body: SafeArea(
                  child: Center(
                      child:
                          Text(context.tr.securitySensitiveHiddenMessage)))));
    }
    ref.listen(securityStatusProvider, (previous, next) {
      if (_ownsScreen &&
          next.asData?.value.totpEnabled == true &&
          _setupUri.isNotEmpty) {
        setState(() {
          _setupUri = '';
          _setupSecret = '';
          _totpCodeController.clear();
        });
      }
    });
    final profileAsync = ref.watch(accountSecurityProfileProvider);
    final securityAsync = ref.watch(securityStatusProvider);
    final backupAsync = ref.watch(backupCodesStatusProvider);
    _profileLookup.observe(_ownerScope, profileAsync);
    _securityLookup.observe(_ownerScope, securityAsync);
    _backupLookup.observe(_ownerScope, backupAsync);
    final profile = _profileLookup.last?.forAccountSecurityChange();
    final security = _securityLookup.last;
    final backup = _backupLookup.last;
    final mayChange = !_busy && _protectionCurrent;
    final mayDisable = mayChange && profile?.requiresTotp == false;
    final mayRegenerate = !_busy && _backupCurrent;

    return FinancialSecureScope(
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: KeroseneScreenBackground(
                useScroll: true,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TotpScreenHeader(
                            onBack: _busy
                                ? null
                                : () => Navigator.of(context).maybePop()),
                        const SizedBox(height: AppSpacing.xl),
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
                        ], onRetry: _busy ? null : _refreshSecurityProviders),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const KeroseneIcon(KeroseneIcons.error,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(_error!,
                                            key: const ValueKey(
                                                'totp-inline-error'))),
                                  ])),
                        if (security == null)
                          securityAsync.isLoading
                              ? const SecurityLoadingCard()
                              : SecurityErrorCard(
                                  title: context.tr.twoFactorAuth,
                                  body: context.tr.securityStatusLoadError)
                        else ...[
                          _TotpOverviewCard(
                              totpEnabled: security.totpEnabled,
                              configuring: _setupUri.isNotEmpty),
                          const SizedBox(height: AppSpacing.md),
                          if (_setupUri.isNotEmpty)
                            TotpSetupCard(
                                setupUri: _setupUri,
                                setupSecret: _setupSecret,
                                controller: _totpCodeController,
                                busy: _busy,
                                enabled: mayChange,
                                onVerify: _verifyTotpSetup)
                          else
                            SecuritySectionCard(
                                title: profile == null
                                    ? context.tr.twoFactorAuth
                                    : profile.requiresTotp
                                        ? context.tr.securityTotpRequiredTitle
                                        : context.tr.securityTotpOptionalTitle,
                                subtitle: profile == null
                                    ? (profileAsync.hasError
                                        ? context
                                            .tr.settingsSecurityLoadErrorBody
                                        : context.tr.settingsSecurityLoading)
                                    : profile.requiresTotp &&
                                            security.totpEnabled
                                        ? context
                                            .tr.securityTotpRequiredSubtitle
                                        : security.totpEnabled
                                            ? context
                                                .tr.securityTotpEnabledSubtitle
                                            : context.tr
                                                .securityTotpDisabledSubtitle,
                                actionLabel: security.totpEnabled
                                    ? context.tr.securityDisableTotpAction
                                    : context.tr.securityEnableTotpAction,
                                destructive: security.totpEnabled,
                                disabled: security.totpEnabled
                                    ? !mayDisable
                                    : !mayChange,
                                onAction: security.totpEnabled
                                    ? (mayDisable ? _disableTotp : null)
                                    : (mayChange ? _beginTotpSetup : null)),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (backup == null || security == null)
                          backupAsync.isLoading || securityAsync.isLoading
                              ? const SecurityLoadingCard()
                              : SecurityErrorCard(
                                  title: context.tr.securityBackupCodesTitle,
                                  body: context.tr.securityBackupCodesLoadError)
                        else
                          SecuritySectionCard(
                              title: context.tr.securityBackupCodesTitle,
                              subtitle: security.totpEnabled
                                  ? context.tr.securityBackupCodesRemaining(
                                      backup.remainingCodes)
                                  : context
                                      .tr.securityBackupCodesLockedSubtitle,
                              actionLabel: security.totpEnabled
                                  ? context.tr.securityRegenerateCodesAction
                                  : context.tr.securityWaitingTotpAction,
                              disabled: !mayRegenerate,
                              onAction:
                                  mayRegenerate ? _regenerateBackupCodes : null,
                              trailing: _latestGeneratedCodes.isNotEmpty
                                  ? TextButton(
                                      onPressed: _busy || _openingCodes
                                          ? null
                                          : () => _showBackupCodesSheet(
                                              _latestGeneratedCodes),
                                      style: monochromeTextButtonStyle(
                                          context: context),
                                      child: Text(
                                          context.tr.securityViewLatestAction))
                                  : null),
                        if (_busy) ...[
                          const SizedBox(height: AppSpacing.md),
                          _TotpBusyCard(
                              message: _busyMessage ?? context.tr.processing),
                        ],
                      ]),
                )),
          ),
        ),
      ),
    );
  }
}

class _TotpScreenHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _TotpScreenHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final mono = MonochromeColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      IgnorePointer(
          ignoring: onBack == null,
          child: Opacity(
              opacity: onBack == null ? .5 : 1,
              child: SettingsHeader(onClose: onBack ?? () {}))),
      const SizedBox(height: AppSpacing.xxl),
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(context.tr.securityAuthenticatorTitle,
              style: AppTypography.playfairDisplay(
                  color: mono.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  height: 1.2))),
      const SizedBox(height: AppSpacing.md),
      Text(context.tr.securityTotpDescription,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: mono.mutedText, height: 1.4)),
    ]);
  }
}

class _TotpOverviewCard extends StatelessWidget {
  final bool totpEnabled;
  final bool configuring;

  const _TotpOverviewCard(
      {required this.totpEnabled, required this.configuring});

  @override
  Widget build(BuildContext context) {
    final mono = MonochromeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: monochromePanelDecoration(
              context: context, color: mono.surface, borderColor: mono.border)
          .copyWith(borderRadius: BorderRadius.circular(HomeRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KeroseneIcon(
              totpEnabled
                  ? KeroseneIcons.success
                  : configuring
                      ? KeroseneIcons.pending
                      : KeroseneIcons.shieldOff,
              color: mono.text,
              size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Text(
                  totpEnabled
                      ? context.tr.securityTotpActiveStatusTitle
                      : configuring
                          ? context.tr.securityTotpSetupStatusTitle
                          : context.tr.securityTotpInactiveStatusTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: mono.text, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(
            totpEnabled
                ? context.tr.securityTotpActiveStatusBody
                : context.tr.securityTotpInactiveStatusBody,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: mono.mutedText, height: 1.45)),
      ]),
    );
  }
}

class _TotpBusyCard extends StatelessWidget {
  final String message;
  const _TotpBusyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final mono = MonochromeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: monochromePanelDecoration(
        context: context,
        color: mono.surfaceAlt,
        borderColor: mono.border,
        showShadow: false,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 24,
            child: Center(
              child: TorLoadingDots(
                dotSize: 4,
                spacing: 5,
                travel: 7,
                color: mono.mutedText,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mono.mutedText,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
