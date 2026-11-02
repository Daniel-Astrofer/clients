import 'package:flutter/services.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'security_change_result_screen.dart';
import 'security_lookup.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart'
    show AppTypography, HomeRadius;
import 'settings_route_helpers.dart';
// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

enum AppPinSheetMode { enable, change, disable }

class AppPinManagementSheet extends ConsumerStatefulWidget {
  final AppPinStatus initialStatus;
  final AppPinSheetMode mode;
  final String? ownerScope;

  const AppPinManagementSheet({
    required this.initialStatus,
    required this.mode,
    this.ownerScope,
  });

  @override
  ConsumerState<AppPinManagementSheet> createState() =>
      AppPinManagementSheetState();
}

class AppPinManagementSheetState extends ConsumerState<AppPinManagementSheet>
    with WidgetsBindingObserver {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _totpController = TextEditingController();
  bool _busy = false;
  bool _requiresRefresh = false;
  final _lookup = SecurityLookup<AppPinStatus>();

  bool get _current {
    if (!_owns ||
        !_foreground ||
        _requiresRefresh ||
        !securityLookupIsCurrent(ref.read(appPinManagementStatusProvider))) {
      return false;
    }
    final status = _status;
    return !status.locked || status.resettableWithTotp;
  }

  AppPinStatus get _status =>
      ref.read(appPinManagementStatusProvider).requireValue;
  AppPinSheetMode _mode(AppPinStatus status) =>
      widget.mode == AppPinSheetMode.disable
          ? AppPinSheetMode.disable
          : status.requiresVerification
              ? AppPinSheetMode.change
              : AppPinSheetMode.enable;

  void _refresh() {
    if (!_owns || !_foreground || _busy) return;
    setState(() => _requiresRefresh = false);
    ref.invalidate(appPinManagementStatusProvider);
  }

  void _unconfirmed() {
    _clearSecrets();
    setState(() {
      _requiresRefresh = true;
      _error = context.tr.securityUpdateUnconfirmedMessage;
    });
    ref.invalidate(accountSecurityProfileProvider);
    ref.invalidate(appPinStatusProvider);
  }

  bool _foreground = true;
  String? _error;
  late final String? _ownerScope;
  @override
  void initState() {
    super.initState();
    _ownerScope =
        widget.ownerScope ?? ref.read(sessionStorageScopeProvider)?.trim();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _clearSecrets();
    });
    if (_foreground && _owns) ref.invalidate(appPinManagementStatusProvider);
  }

  bool get _owns =>
      mounted &&
      _ownerScope?.isNotEmpty == true &&
      ref.read(sessionStorageScopeProvider)?.trim() == _ownerScope;
  void _clearSecrets() {
    _currentPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();
    _totpController.clear();
  }

  bool get _requiresNewPin => widget.mode != AppPinSheetMode.disable;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_current) return;
    final tr = context.tr;
    final submittedMode = _mode(_status);
    final min = _status.minPinLength;
    final max = _status.maxPinLength;
    bool validPin(String value) =>
        min > 0 && max >= min && RegExp('^[0-9]{$min,$max}\$').hasMatch(value);
    if (_requiresNewPin && !validPin(_newPinController.text.trim())) {
      setState(() => _error = tr.securityPinLengthError(min, max));
      return;
    }
    if (_requiresNewPin &&
        _newPinController.text.trim() != _confirmPinController.text.trim()) {
      setState(() => _error = tr.securityPinMismatchError);
      return;
    }
    final current = _currentPinController.text.trim();
    final totp = _totpController.text.trim();
    final validCurrent = !_status.locked && validPin(current);
    if (_status.requiresVerification &&
        !validCurrent &&
        !(_status.resettableWithTotp && RegExp(r'^[0-9]{6}$').hasMatch(totp))) {
      setState(() => _error = tr.securityPinAuthorizationMissing);
      return;
    }
    if (totp.isNotEmpty && !RegExp(r'^[0-9]{6}$').hasMatch(totp)) {
      setState(() => _error = tr.securityTotpCodeRequiredMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final expected = widget.mode != AppPinSheetMode.disable;
      final result = await ref.read(securityRepositoryProvider).configureAppPin(
          enabled: expected,
          pin: _requiresNewPin ? _newPinController.text.trim() : null,
          currentPin: validCurrent ? current : null,
          totpCode: totp.isNotEmpty ? totp : null);
      if (!mounted || !_owns) return;
      final status = result.fold((_) => null, (value) => value);
      if (status == null ||
          status.enabled != expected ||
          (expected && !status.configured)) {
        _unconfirmed();
        return;
      }
      _clearSecrets();
      ref.invalidate(accountSecurityProfileProvider);
      ref.invalidate(appPinStatusProvider);
      ref.invalidate(appPinManagementStatusProvider);
      final title = switch (submittedMode) {
        AppPinSheetMode.enable => tr.securityPinEnabledResult,
        AppPinSheetMode.change => tr.securityPinChangedResult,
        AppPinSheetMode.disable => tr.securityPinDisabledResult,
      };
      replaceSettingsResultPage<bool, bool>(
          context,
          SecurityChangeResultScreen(
              ownerScope: _ownerScope!,
              title: title,
              body: expected
                  ? tr.securityPinSavedResultBody
                  : tr.securityPinDisabledResultBody),
          result: true);
    } catch (_) {
      if (mounted && _owns) {
        _unconfirmed();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (previous, next) {
      if (previous != next) _clearSecrets();
    });
    ref.watch(sessionStorageScopeProvider);
    if (!_foreground) {
      return FinancialSecureScope(
          child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr.securitySensitiveHiddenMessage))));
    }
    if (!_owns) {
      return FinancialSecureScope(
          child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr.securitySessionChangedMessage))));
    }
    final source = ref.watch(appPinManagementStatusProvider);
    _lookup.observe(_ownerScope, source);
    final status = _lookup.last;
    final mono = MonochromeColors.of(context);
    final canEdit = !_busy && _current;
    final mode = status == null ? widget.mode : _mode(status);
    final title = switch (mode) {
      AppPinSheetMode.enable => context.tr.securityPinEnableTitle,
      AppPinSheetMode.change => context.tr.securityPinChangeTitle,
      AppPinSheetMode.disable => context.tr.securityPinDisableTitle,
    };

    final body = switch (mode) {
      AppPinSheetMode.enable => context.tr.securityPinEnableBody,
      AppPinSheetMode.change =>
        status?.locked == true && status?.resettableWithTotp == true
            ? context.tr.securityPinLockedResetBody
            : status?.resettableWithTotp == true
                ? context.tr.securityPinChangeBody
                : context.tr.securityPinChangePinOnlyBody,
      AppPinSheetMode.disable => context.tr.securityPinDisableBody,
    };

    return FinancialSecureScope(
        child: SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: monochromePanelDecoration(
              context: context,
              color: mono.surface,
              borderColor: mono.border,
            ).copyWith(borderRadius: BorderRadius.circular(HomeRadius.card)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTypography.h1.copyWith(
                    fontSize: 28,
                    height: 1.2,
                    color: mono.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: AppTypography.bodyMedium.copyWith(
                    color: mono.mutedText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SecurityLookupNotice(
                    sources: [
                      (label: context.tr.securityPinEntryTitle, lookup: _lookup)
                    ],
                    onRetry: _busy ? null : _refresh,
                    retryKey: 'security-pin-status-retry'),
                if (status == null)
                  Text(source.isLoading && !source.hasError
                      ? context.tr.settingsSecurityLoading
                      : context.tr.securityPinLoadError),
                if (status != null) ...[
                  if (status.locked) ...[
                    Text(context.tr.securityPinActiveLockedSubtitle),
                    TextButton(
                        key: const ValueKey('security-pin-lock-refresh'),
                        onPressed: _busy ? null : _refresh,
                        child: Text(context.tr.securityPinCheckStatusAction)),
                  ],
                  if (status.requiresVerification) ...[
                    TextField(
                      key: const ValueKey('security-current-pin'),
                      enabled: canEdit && !status.locked,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      controller: _currentPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: status.maxPinLength,
                      style: TextStyle(color: mono.text),
                      decoration: monochromeInputDecoration(
                        context: context,
                        label: context.tr.securityCurrentPinLabel,
                        counterText: '',
                      ),
                    ),
                    if (status.resettableWithTotp)
                      TextField(
                        key: const ValueKey('security-pin-totp'),
                        enabled: canEdit,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        controller: _totpController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        style: TextStyle(color: mono.text),
                        decoration: monochromeInputDecoration(
                          context: context,
                          label: context.tr.securityPinTotpCodeLabel,
                          counterText: '',
                        ),
                      ),
                  ],
                  if (_requiresNewPin) ...[
                    TextField(
                      key: const ValueKey('security-new-pin'),
                      enabled: canEdit,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      controller: _newPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: status.maxPinLength,
                      style: TextStyle(color: mono.text),
                      decoration: monochromeInputDecoration(
                        context: context,
                        label: context.tr.securityNewPinLabel(
                          status.minPinLength,
                          status.maxPinLength,
                        ),
                        counterText: '',
                      ),
                    ),
                    TextField(
                      key: const ValueKey('security-confirm-pin'),
                      enabled: canEdit,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      controller: _confirmPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: status.maxPinLength,
                      style: TextStyle(color: mono.text),
                      decoration: monochromeInputDecoration(
                        context: context,
                        label: context.tr.securityConfirmNewPinLabel,
                        counterText: '',
                      ),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mono.mutedText,
                        ),
                  ),
                ],
                if (_requiresRefresh)
                  TextButton(
                      key: const ValueKey('security-pin-recheck'),
                      onPressed: _busy ? null : _refresh,
                      child: Text(context.tr.securityPinCheckStatusAction)),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const ValueKey('security-save-pin'),
                  onPressed: canEdit ? _submit : null,
                  style: monochromeFilledButtonStyle(
                    context: context,
                    emphasis: widget.mode != AppPinSheetMode.disable,
                    destructive: widget.mode == AppPinSheetMode.disable,
                  ).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 54))),
                  child: _busy
                      ? SizedBox(
                          height: 18,
                          child: TorLoadingDots(
                            dotSize: 6,
                            spacing: 8,
                            travel: 10,
                            color: mono.text,
                          ),
                        )
                      : Text(
                          widget.mode == AppPinSheetMode.disable
                              ? context.tr.securityDisablePinAction
                              : context.tr.securitySavePinAction,
                        ),
                ),
              ],
            ),
          )),
    ));
  }
}
