import 'package:kerosene/features/auth/controller/auth_providers.dart'
    show securityStatusProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'settings_account_confirmation.dart';
import 'settings_devices_screen.dart';
import 'settings_route_helpers.dart';

enum _EnrollmentPhase { working, done, unconfirmed, sessionChanged, cancelled }

/// Both settings entry points use one account-bound enrollment and result flow.
Future<bool> openCredentialEnrollment(BuildContext context,
    {bool returnToDevices = false}) async {
  if (ModalRoute.of(context)?.isCurrent != true) return false;
  return await pushSettingsResultPage<bool>(
          context,
          SecurityCredentialEnrollmentScreen(
              returnToDevices: returnToDevices)) ??
      false;
}

class SecurityCredentialEnrollmentScreen extends ConsumerStatefulWidget {
  final bool returnToDevices;
  const SecurityCredentialEnrollmentScreen(
      {super.key, this.returnToDevices = false});
  @override
  ConsumerState<SecurityCredentialEnrollmentScreen> createState() =>
      _CredentialEnrollmentState();
}

class _CredentialEnrollmentState
    extends ConsumerState<SecurityCredentialEnrollmentScreen> {
  String? _ownerScope;
  User? _user;
  bool _busy = false;
  bool _busyElsewhere = false;
  String? _setupRequired;
  _EnrollmentPhase _phase = _EnrollmentPhase.working;
  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider)?.trim();
    final auth = ref.read(authControllerProvider);
    _user = auth is AuthAuthenticated ? auth.user : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _register();
    });
  }

  bool get _owns =>
      mounted &&
      _user != null &&
      _ownerScope?.isNotEmpty == true &&
      ref.read(sessionStorageScopeProvider)?.trim() == _ownerScope;

  Future<void> _register() async {
    if (_busy || !_owns || _phase == _EnrollmentPhase.done) return;
    setState(() {
      _busy = true;
      _phase = _EnrollmentPhase.working;
      _busyElsewhere = false;
      _setupRequired = null;
    });
    final tr = context.tr;
    try {
      var confirmedUnlink = false;
      while (_owns) {
        final result = await ref
            .read(authControllerProvider.notifier)
            .registerPasskey(confirmUnlinkDevice: confirmedUnlink);
        if (!mounted || !_owns) return;
        if (result.isDeviceConflict && !confirmedUnlink) {
          final data = result.data is Map ? result.data as Map : const {};
          final previous = (data['previousUsernameMasked'] ??
                  data['previous_username_masked'] ??
                  '***')
              .toString();
          // Server text may contain diagnostics. The decision uses localized
          // product copy and the explicitly masked previous account only.
          final accepted = await confirmAccountSetting(context,
              ownerScope: _ownerScope!,
              accountName: _user!.username,
              accountId: _user!.id,
              title: tr.authDeviceUnlinkTitle,
              body: tr.authDeviceUnlinkBody(
                  previous, tr.authDeviceUnlinkDefaultGuidance),
              confirmLabel: tr.authDeviceUnlinkConfirmLink);
          if (!mounted || !_owns) return;
          if (!accepted) {
            setState(() => _phase = _EnrollmentPhase.cancelled);
            return;
          }
          confirmedUnlink = true;
          continue;
        }
        if (result.isSuccess) {
          ref.invalidate(accountSecurityProfileProvider);
          ref.invalidate(securityStatusProvider);
          setState(() => _phase = _EnrollmentPhase.done);
        } else if (result.status == PasskeyRegisterStatus.notAuthenticated) {
          setState(() => _phase = _EnrollmentPhase.sessionChanged);
        } else {
          setState(() {
            _phase = _EnrollmentPhase.unconfirmed;
            _busyElsewhere =
                result.errorCode == 'ERR_AUTH_DEVICE_KEY_REGISTRATION_BUSY';
            _setupRequired = switch (result.errorCode) {
              'ERR_AUTH_DEVICE_KEY_NO_LOCAL_CREDENTIALS' =>
                tr.securityCredentialSystemSetup,
              'ERR_AUTH_DEVICE_KEY_APP_PIN_REQUIRED' =>
                tr.securityCredentialPinSetup,
              _ => null
            };
          });
        }
        return;
      }
    } catch (_) {
      if (mounted && _owns) {
        setState(() => _phase = _EnrollmentPhase.unconfirmed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScope = ref.watch(sessionStorageScopeProvider)?.trim();
    final owns = _user != null &&
        _ownerScope?.isNotEmpty == true &&
        currentScope == _ownerScope;
    final phase = owns ? _phase : _EnrollmentPhase.sessionChanged;
    final tr = context.tr;
    final theme = Theme.of(context);
    final working = phase == _EnrollmentPhase.working;
    final done = phase == _EnrollmentPhase.done;
    final title = switch (phase) {
      _EnrollmentPhase.working => tr.securityCredentialWorkingTitle,
      _EnrollmentPhase.done => tr.securityCredentialDoneTitle,
      _EnrollmentPhase.sessionChanged => tr.securityCredentialSessionTitle,
      _EnrollmentPhase.cancelled => tr.securityCredentialCancelledTitle,
      _EnrollmentPhase.unconfirmed => tr.securityCredentialUnconfirmedTitle,
    };
    final body = switch (phase) {
      _EnrollmentPhase.working => tr.securityCredentialWorkingBody,
      _EnrollmentPhase.done => tr.securityCredentialDoneBody,
      _EnrollmentPhase.sessionChanged => tr.securityCredentialSessionBody,
      _EnrollmentPhase.cancelled => tr.securityCredentialCancelledBody,
      _EnrollmentPhase.unconfirmed => _busyElsewhere
          ? tr.securityCredentialBusyBody
          : (_setupRequired ?? tr.securityCredentialUnconfirmedBody),
    };
    return PopScope<bool>(
      canPop: !working,
      child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
              child: Column(children: [
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          if (working)
                            Center(
                                child: TickerMode(
                                    enabled:
                                        !KeroseneMotion.reduceMotion(context),
                                    child: const SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))))
                          else
                            KeroseneIcon(
                                done
                                    ? KeroseneIcons.success
                                    : KeroseneIcons.warning,
                                size: 48),
                          const SizedBox(height: 24),
                          Text(title,
                              key:
                                  const ValueKey('credential-enrollment-title'),
                              textAlign: TextAlign.center,
                              style: AppTypography.playfairDisplay(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                  height: 1.14)),
                          const SizedBox(height: 16),
                          Text(body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium),
                          if (owns) ...[
                            const SizedBox(height: 28),
                            Text(tr.settingsConfirmationAccount,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            SelectableText(_user!.username,
                                style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 16),
                            Text(tr.txListId, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            SelectableText(_user!.id,
                                style: AppTypography.technicalMono(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface)),
                          ],
                        ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!working && owns) ...[
                        AppButton(
                            key:
                                const ValueKey('credential-enrollment-devices'),
                            label: tr.securityCredentialViewDevices,
                            expand: true,
                            onPressed: () => widget.returnToDevices
                                ? Navigator.of(context).pop(done)
                                : replaceSettingsResultPage<bool, bool>(
                                    context, const SettingsDevicesScreen(),
                                    result: done)),
                        const SizedBox(height: 12),
                      ],
                      if (phase == _EnrollmentPhase.unconfirmed ||
                          phase == _EnrollmentPhase.cancelled) ...[
                        AppButton(
                            key: const ValueKey('credential-enrollment-retry'),
                            label: tr.tryAgain,
                            expand: true,
                            variant: AppButtonVariant.secondary,
                            onPressed: _busy ? null : _register),
                        const SizedBox(height: 12),
                      ],
                      AppButton(
                          key: const ValueKey('credential-enrollment-close'),
                          label: done
                              ? tr.securityCredentialDoneAction
                              : tr.goBack,
                          expand: true,
                          variant: AppButtonVariant.secondary,
                          onPressed: working
                              ? null
                              : () => Navigator.of(context).pop(done)),
                    ])),
          ]))),
    );
  }
}
