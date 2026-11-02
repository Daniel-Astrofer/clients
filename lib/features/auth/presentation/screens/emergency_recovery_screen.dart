import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/generic/kerosene_logo.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/components/inputs/app_text_field.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/security/secure_screen_guard.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/data/emergency_recovery_service.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';
import 'package:kerosene/features/auth/application/providers/emergency_recovery_service_provider.dart';

enum _RecoveryStep { start, verify, complete, restart, unknown }

class EmergencyRecoveryScreen extends ConsumerStatefulWidget {
  const EmergencyRecoveryScreen({super.key});

  @override
  ConsumerState<EmergencyRecoveryScreen> createState() =>
      _EmergencyRecoveryScreenState();
}

class _EmergencyRecoveryScreenState
    extends ConsumerState<EmergencyRecoveryScreen> with WidgetsBindingObserver {
  final _usernameController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _confirmPassphraseController = TextEditingController();
  final _totpController = TextEditingController();
  final List<TextEditingController> _codeControllers =
      List.generate(3, (_) => TextEditingController());

  _RecoveryStep _step = _RecoveryStep.start;
  EmergencyRecoveryStartResult? _started;
  EmergencyRecoveryFinishResult? _finished;
  bool _busy = false;
  String? _error;
  Timer? _expiryTimer;
  DateTime? _deadline;
  int _remainingMinutes = 0;
  int _operation = 0;
  String? _recoveryUsername;
  bool _foreground = true;
  bool _revealed = true;
  bool _copying = false;
  bool _savedCodes = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _revealed = _foreground;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _revealed = false;
    });
    if (_foreground) {
      _checkExpiry();
      _scheduleExpiry();
    } else {
      _expiryTimer?.cancel();
      _expiryTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _usernameController.dispose();
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    _totpController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (previous, next) {
      if (previous == next) return;
      // The expected logout transition has no account. A foreign new account still clears the result.
      if (_leaving && next == null) return;
      _operation++;
      _clearSession();
      _clearSensitiveInputs();
      _usernameController.clear();
      setState(() {
        _finished = null;
        _step = _RecoveryStep.start;
        _busy = false;
        _savedCodes = false;
        _leaving = false;
        _error = context.tr.emergencyRecoveryAccountChanged;
      });
    });
    return SecureScreenScope(
        child: PopScope(
            canPop: !_busy && !_copying && _step != _RecoveryStep.complete,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: (Theme.of(context).brightness == Brightness.light
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light)
                  .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.black,
                systemNavigationBarIconBrightness:
                    Theme.of(context).brightness == Brightness.light
                        ? Brightness.dark
                        : Brightness.light,
              ),
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: context.responsive.formConstraints,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl2,
                              AppSpacing.base,
                              AppSpacing.xl2,
                              AppSpacing.xxl,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _RecoveryTopBar(
                                    onBack: _busy ||
                                            _copying ||
                                            _step == _RecoveryStep.complete
                                        ? null
                                        : () =>
                                            Navigator.of(context).maybePop(),
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  const Center(
                                    child:
                                        KeroseneLogo(size: 46, showText: false),
                                  ),
                                  const SizedBox(height: AppSpacing.xl2),
                                  _RecoveryTitle(
                                    eyebrow:
                                        context.tr.emergencyRecoveryEyebrow,
                                    title: _titleForStep(),
                                    body: _bodyForStep(),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: AppSpacing.xl2),
                                    _RecoveryNotice(
                                      icon: KeroseneIcons.error,
                                      title: context
                                          .tr.emergencyRecoveryUnableContinue,
                                      message: _error!,
                                      tone: _RecoveryNoticeTone.error,
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xl2),
                                  if (!_foreground)
                                    Text(context
                                        .tr.securitySensitiveHiddenMessage)
                                  else
                                    switch (_step) {
                                      _RecoveryStep.start => _buildStartStep(),
                                      _RecoveryStep.verify =>
                                        _buildVerifyStep(),
                                      _RecoveryStep.complete =>
                                        _buildCompleteStep(),
                                      _RecoveryStep.restart =>
                                        _RecoveryActionButton(
                                            label: context.tr
                                                .emergencyRecoveryRestartAction,
                                            loading: false,
                                            onPressed: _restart),
                                      _RecoveryStep.unknown => OutlinedButton(
                                          onPressed:
                                              _busy ? null : _signInAgain,
                                          child: Text(context.tr
                                              .emergencyRecoverySignInAgain)),
                                    },
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
            )));
  }

  String _titleForStep() {
    return switch (_step) {
      _RecoveryStep.start => context.tr.emergencyRecoveryTitleStart,
      _RecoveryStep.verify => context.tr.emergencyRecoveryTitleVerify,
      _RecoveryStep.complete => context.tr.emergencyRecoveryTitleComplete,
      _RecoveryStep.restart => context.tr.emergencyRecoverySessionClosedTitle,
      _RecoveryStep.unknown => context.tr.emergencyRecoveryUnknownTitle,
    };
  }

  String _bodyForStep() {
    return switch (_step) {
      _RecoveryStep.start => context.tr.emergencyRecoveryBodyStart,
      _RecoveryStep.verify => context.tr.emergencyRecoveryBodyVerify,
      _RecoveryStep.complete => context.tr.emergencyRecoveryBodyComplete,
      _RecoveryStep.restart => context.tr.emergencyRecoverySessionClosedBody,
      _RecoveryStep.unknown => context.tr.emergencyRecoveryUnknownBody,
    };
  }

  Widget _buildStartStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryTextField(
          controller: _usernameController,
          label: context.tr.username,
          icon: KeroseneIcons.user,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.base),
        _RecoveryTextField(
          controller: _passphraseController,
          label: context.tr.emergencyRecoveryNewPassword,
          icon: KeroseneIcons.lock,
          enabled: !_busy,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.base),
        _RecoveryTextField(
          controller: _confirmPassphraseController,
          label: context.tr.emergencyRecoveryConfirmPassword,
          icon: KeroseneIcons.passkey,
          enabled: !_busy,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.xl2),
        Text(
          context.tr.emergencyRecoveryCodesLabel,
          style: AppTypography.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _codeControllers.length; i++) ...[
          _RecoveryTextField(
            controller: _codeControllers[i],
            label: context.tr.emergencyRecoveryCodeN(i + 1),
            icon: KeroseneIcons.binary,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            textInputAction: i == _codeControllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy || _codeControllers.length >= 10
                ? null
                : _addRecoveryCodeField,
            icon: const KeroseneIcon(KeroseneIcons.plus, size: 16),
            label: Text(
              context.tr.emergencyRecoveryAddCode,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryStartAction,
          loading: _busy,
          onPressed: _busy ? null : _startRecovery,
        ),
      ],
    );
  }

  Widget _buildVerifyStep() {
    final started = _started;
    if (started == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryNotice(
          icon: KeroseneIcons.timer,
          title: _busy
              ? context.tr.emergencyRecoveryConfirmingTitle
              : context.tr.emergencyRecoveryTempSession,
          message: _busy
              ? context.tr.emergencyRecoveryConfirmingBody
              : context.tr.emergencyRecoveryFinishWithin(_remainingMinutes),
          tone: _RecoveryNoticeTone.info,
        ),
        const SizedBox(height: AppSpacing.xl2),
        if (_revealed)
          _TotpQrPanel(
            data: started.otpUri,
            onCopy: _copying || _busy
                ? null
                : () => _copyToClipboard(started.otpUri),
          )
        else
          _buildReveal(),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryTextField(
          controller: _totpController,
          label: context.tr.totpCodeLabel,
          icon: KeroseneIcons.security,
          enabled: !_busy && _revealed,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_busy && _revealed) {
              _finishRecovery();
            }
          },
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryConfirmPasskey,
          loading: _busy,
          onPressed: _busy || !_revealed ? null : _finishRecovery,
        ),
        const SizedBox(height: AppSpacing.base),
        TextButton(
          onPressed: _busy ? null : _restart,
          child: Text(
            context.tr.emergencyRecoveryGoBackReview,
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    final finished = _finished;
    final codes = finished?.newBackupCodes ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecoveryNotice(
          icon: KeroseneIcons.success,
          title: context.tr.emergencyRecoveryCredentialsRotated,
          message: context.tr
              .emergencyRecoveryAccountRotatedBody(finished?.username ?? ''),
          tone: _RecoveryNoticeTone.success,
        ),
        if (finished?.localDeviceKeyReady == false) ...[
          const SizedBox(height: AppSpacing.base),
          _RecoveryNotice(
              icon: KeroseneIcons.warning,
              title: context.tr.emergencyRecoveryDeviceActivationTitle,
              message: context.tr.emergencyRecoveryDeviceActivationFailed,
              tone: _RecoveryNoticeTone.info),
        ],
        const SizedBox(height: AppSpacing.xl2),
        if (_revealed) _BackupCodesGrid(codes: codes) else _buildReveal(),
        const SizedBox(height: AppSpacing.xl2),
        _RecoveryActionButton(
          label: context.tr.emergencyRecoveryCopyNewCodes,
          icon: KeroseneIcons.copy,
          loading: _copying,
          onPressed: codes.isEmpty || !_revealed || _copying || _busy
              ? null
              : () => _copyToClipboard(
                    codes.join('\n'),
                    isCodes: true,
                  ),
        ),
        const SizedBox(height: AppSpacing.base),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _savedCodes,
          onChanged: _copying || _busy
              ? null
              : (value) => setState(() => _savedCodes = value == true),
          title: Text(context.tr.emergencyRecoveryCodesSaved),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        OutlinedButton.icon(
          onPressed: !_savedCodes || _copying
              ? null
              : _busy
                  ? null
                  : _signInAgain,
          icon: const KeroseneIcon(KeroseneIcons.login, size: 18),
          label: Text(
            context.tr.emergencyRecoverySignInAgain,
          ),
        ),
      ],
    );
  }

  void _addRecoveryCodeField() {
    setState(() => _codeControllers.add(TextEditingController()));
  }

  Future<void> _signInAgain() async {
    if (_busy ||
        _copying ||
        !_foreground ||
        (_step == _RecoveryStep.complete && !_savedCodes)) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _leaving = true;
      _error = null;
    });
    try {
      final ended = await ref.read(emergencyRecoverySessionExitProvider)();
      if (!mounted || operation != _operation) return;
      if (!ended) {
        throw const AppException(
            message: 'Session exit failed.',
            errorCode: 'ERR_RECOVERY_SESSION_EXIT');
      }
      GoRouter.of(context)
          .go('/login', extra: _usernameController.text.trim().toLowerCase());
    } catch (error) {
      if (mounted && operation == _operation) _setTranslatedError(error);
    } finally {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _leaving = false;
        });
      }
    }
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  Future<void> _startRecovery() async {
    if (_busy || !_foreground || _step != _RecoveryStep.start) return;
    final username = _usernameController.text.trim().toLowerCase();
    final passphrase = _passphraseController.text;
    final confirmPassphrase = _confirmPassphraseController.text;
    final codes = _codeControllers
        .map((controller) => controller.text.trim())
        .where((code) => code.isNotEmpty)
        .toList(growable: false);

    final validationError = _validateStart(
      username: username,
      passphrase: passphrase,
      confirmPassphrase: confirmPassphrase,
      codes: codes,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final operation = ++_operation;
    // Start the UI deadline before I/O, conservatively including request latency.
    final requestedAt = ref.read(emergencyRecoveryClockProvider)();

    try {
      final started = await ref.read(emergencyRecoveryServiceProvider).start(
            EmergencyRecoveryStartDraft(
              username: username,
              newPassphrase: passphrase,
              recoveryCodes: codes,
            ),
          );
      if (!mounted || operation != _operation) return;
      if (!started.isUsable) {
        throw const ServerException(
            message: 'Invalid recovery session.',
            errorCode: 'ERR_RECOVERY_START_INVALID_RESPONSE');
      }
      _recoveryUsername = username;
      _deadline = requestedAt.add(Duration(seconds: started.expiresInSeconds));
      _clearSensitiveInputs();
      setState(() {
        _started = started;
        _step = _RecoveryStep.verify;
      });
      _scheduleExpiry();
    } catch (error) {
      if (operation == _operation) _setTranslatedError(error);
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _busy = false);
        _checkExpiry();
      }
    }
  }

  Future<void> _finishRecovery() async {
    if (_busy || !_foreground || !_revealed || _step != _RecoveryStep.verify) {
      return;
    }
    _checkExpiry();
    final started = _started;
    if (started == null) return;

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = context.tr.emergencyRecoveryTotpInstruction;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final operation = ++_operation;
    final username = _recoveryUsername!;

    try {
      final finished = await ref.read(emergencyRecoveryServiceProvider).finish(
            username: username,
            started: started,
            totpCode: totp,
          );
      if (!mounted || operation != _operation) return;
      if (!finished.isUsable || finished.username != username) {
        throw const EmergencyRecoveryResultUnknownException();
      }
      _clearSession();
      setState(() {
        _finished = finished;
        _step = _RecoveryStep.complete;
      });
    } catch (error) {
      if (mounted && operation == _operation) {
        if (error is EmergencyRecoveryResultUnknownException) {
          _clearSession();
          setState(() {
            _step = _RecoveryStep.unknown;
            _error = null;
          });
        } else if (error is EmergencyRecoveryPreparationException &&
            !error.sessionClosed) {
          _setTranslatedError(error);
        } else if (error is AppException &&
            error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          _clearSession();
          setState(() => _step = _RecoveryStep.restart);
          _setTranslatedError(error);
        } else {
          // Local enrollment failed before the completion request was sent.
          _setTranslatedError(error);
        }
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _busy = false);
        _checkExpiry();
      }
    }
  }

  String? _validateStart({
    required String username,
    required String passphrase,
    required String confirmPassphrase,
    required List<String> codes,
  }) {
    if (username.length < 3) {
      return context.tr.authUsernameRequiredMessage;
    }
    if (passphrase.length < 12) {
      return context.tr.emergencyRecoveryPasswordMin;
    }
    if (passphrase != confirmPassphrase) {
      return context.tr.emergencyRecoveryPasswordMismatch;
    }
    if (codes.length < 3) {
      return context.tr.emergencyRecoveryNeedThreeCodes;
    }
    if (codes.toSet().length != codes.length) {
      return context.tr.emergencyRecoveryCodesDistinct;
    }
    if (codes.any((code) => !RegExp(r'^\d{8}$').hasMatch(code))) {
      return context.tr.emergencyRecoveryCodeEightDigits;
    }
    return null;
  }

  void _setTranslatedError(Object error) {
    if (!mounted) return;
    final message = ErrorTranslator.translate(context.tr, error.toString());
    setState(() => _error = message);
  }

  Future<void> _copyToClipboard(String value, {bool isCodes = false}) async {
    if (_copying || _busy || !_foreground || !_revealed) return;
    final operation = _operation;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted || !_foreground || operation != _operation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr.emergencyRecoveryCopied,
          ),
        ),
      );
    } catch (_) {
      if (mounted && _foreground && operation == _operation) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isCodes
                ? context.tr.securityCopyFailedMessage
                : context.tr.emergencyRecoveryAuthenticatorCopyFailed)));
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Widget _buildReveal() => Column(children: [
        Text(context.tr.securitySensitiveHiddenMessage),
        TextButton(
            onPressed: () => setState(() => _revealed = true),
            child: Text(context.tr.emergencyRecoveryReveal)),
      ]);

  void _checkExpiry() {
    if (!mounted || _step != _RecoveryStep.verify || _deadline == null) return;
    final remaining =
        _deadline!.difference(ref.read(emergencyRecoveryClockProvider)());
    if (remaining <= Duration.zero && !_busy) {
      _clearSession();
      setState(() {
        _step = _RecoveryStep.restart;
        _error = null;
      });
    } else {
      final minutes = remaining <= Duration.zero
          ? 0
          : (remaining.inMilliseconds / 60000).ceil();
      if (minutes != _remainingMinutes) {
        setState(() => _remainingMinutes = minutes);
      }
    }
  }

  void _clearSensitiveInputs() {
    _passphraseController.clear();
    _confirmPassphraseController.clear();
    _totpController.clear();
    for (final controller in _codeControllers) {
      controller.clear();
    }
  }

  void _scheduleExpiry() {
    if (!_foreground || _step != _RecoveryStep.verify || _deadline == null) {
      return;
    }
    _expiryTimer ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _checkExpiry());
  }

  void _clearSession() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _started = null;
    _deadline = null;
    _recoveryUsername = null;
    _totpController.clear();
  }

  void _restart() {
    if (_busy || _copying || !_foreground) return;
    _operation++;
    _clearSession();
    _clearSensitiveInputs();
    setState(() {
      _step = _RecoveryStep.start;
      _error = null;
      _savedCodes = false;
    });
  }
}

class _RecoveryTopBar extends StatelessWidget {
  final VoidCallback? onBack;

  const _RecoveryTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const KeroseneIcon(KeroseneIcons.back, size: 22),
          color: Theme.of(context).colorScheme.onSurface,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const Spacer(),
      ],
    );
  }
}

class _RecoveryTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;

  const _RecoveryTitle({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.playfairDisplay(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 31,
            fontWeight: FontWeight.w500,
            height: 1.08,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.70)),
        ),
      ],
    );
  }
}

class _RecoveryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _RecoveryTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      label: label,
      prefixIcon: KeroseneIcon(icon, size: 18),
    );
  }
}

enum _RecoveryNoticeTone { info, success, error }

class _RecoveryNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final _RecoveryNoticeTone tone;

  const _RecoveryNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeroseneIcon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotpQrPanel extends StatelessWidget {
  final String data;
  final VoidCallback? onCopy;

  const _TotpQrPanel({
    required this.data,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 212,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const KeroseneIcon(KeroseneIcons.copy, size: 16),
              label: Text(context.tr.emergencyRecoveryCopyAuthenticator),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCodesGrid extends StatelessWidget {
  final List<String> codes;

  const _BackupCodesGrid({required this.codes});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final code in codes)
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: AppTypography.technicalMono(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: AppTypography.w590,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecoveryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _RecoveryActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      expand: true,
      icon: KeroseneIcon(icon ?? KeroseneIcons.next, size: 18),
    );
  }
}
