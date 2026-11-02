import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_motion.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_progress.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'signup_flow_components.dart';
import 'signup_flow_copy.dart';
import 'signup_success_scene.dart';

Color get _signupInk => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.background
    : KeroseneBrandTheme.dark.background;
Color get _signupPanel => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.surface
    : KeroseneBrandTheme.dark.surface;
Color get _signupField => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.surfaceHigh
    : KeroseneBrandTheme.dark.surfaceElevated;
Color get _signupBorderSoft => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.border
    : KeroseneBrandTheme.dark.borderSubtle;
Color get _signupMuted => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.textSecondary
    : KeroseneBrandTheme.dark.textMuted;
Color get _signupText => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.textPrimary
    : KeroseneBrandTheme.dark.textPrimary;

enum _SignupErrorTarget {
  username,
  passphrase,
  confirmation,
  totp,
  risk,
  general
}

class SignupFlowScreen extends ConsumerStatefulWidget {
  const SignupFlowScreen({super.key});

  @override
  ConsumerState<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends ConsumerState<SignupFlowScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _totpController = TextEditingController();

  ProviderSubscription<AuthState>? _authSubscription;
  Timer? _totpTransitionTimer;

  int _step = 0;
  bool _isForward = true;
  bool _acceptedPasswordRisk = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _sessionId = '';
  bool _totpOptional = false;
  String? _sessionPassword;
  bool _totpPhaseFinished = false;
  bool _deviceUnlinkDialogOpen = false;
  bool _resumedVerifiedEnrollment = false;
  bool _isContinuing = false;
  String _totpSecret = '';
  String _qrCodeUri = '';
  List<String> _backupCodes = const [];
  String? _inlineFeedbackTitle;
  String? _inlineFeedbackMessage;
  IconData _inlineFeedbackIcon = KeroseneIcons.error;
  _SignupErrorTarget? _inlineFeedbackTarget;
  int _inlineFeedbackPulseKey = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      _handleAuthState,
    );
    final current = ref.read(authControllerProvider);
    final resumable = current is AuthError ? current.resumeState : current;
    if (current is AuthOnboardingOutcomeUnknown) {
      _step = 5;
    } else if (resumable is AuthRequiresTotpSetup) {
      // Resume only the in-memory session. Credentials are never persisted by
      // this screen, and a terminated app restarts from actual authentication.
      _usernameController.text = resumable.username;
      _passwordController.text = resumable.passphrase;
      _confirmPasswordController.text = resumable.passphrase;
      _acceptedPasswordRisk = true;
      _sessionId = resumable.sessionId;
      _sessionPassword = resumable.passphrase;
      _totpOptional = resumable.totpOptional;
      _totpSecret = resumable.totpSecret;
      _qrCodeUri = resumable.qrCodeUri;
      _backupCodes = resumable.backupCodes;
      _step = 4;
    } else if (resumable is AuthTotpVerified) {
      _usernameController.text = resumable.username;
      _sessionId = resumable.sessionId;
      _totpPhaseFinished = true;
      _resumedVerifiedEnrollment = true;
      _step = 5;
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _totpTransitionTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  String get _username => _usernameController.text.trim();
  String get _password => _passwordController.text;
  String get _totpCode => _totpController.text.replaceAll(RegExp(r'\D'), '');

  bool get _usernameLooksValid =>
      _username.length >= 3 && RegExp(r'^[a-z0-9_]+$').hasMatch(_username);

  bool get _passwordHasMin => _password.length >= 12;
  bool get _passwordHasUpper => RegExp(r'[A-Z]').hasMatch(_password);
  bool get _passwordHasLower => RegExp(r'[a-z]').hasMatch(_password);
  bool get _passwordHasNumber => RegExp(r'[0-9]').hasMatch(_password);
  bool get _passwordHasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_password);
  bool get _passwordLooksStrong =>
      _passwordHasMin &&
      _passwordHasUpper &&
      _passwordHasLower &&
      _passwordHasNumber &&
      _passwordHasSymbol;

  void _handleAuthState(AuthState? previous, AuthState next) {
    if (!mounted) {
      return;
    }

    if (next is AuthRequiresTotpSetup) {
      _sessionId = next.sessionId;
      _totpOptional = next.totpOptional;
      _sessionPassword = next.passphrase;
      _totpPhaseFinished = false;
      _totpSecret = next.totpSecret;
      _qrCodeUri = next.qrCodeUri;
      _backupCodes = next.backupCodes;
      setState(() {});
      _totpTransitionTimer?.cancel();
      _totpTransitionTimer = Timer(KeroseneMotion.totpTransition, () {
        if (mounted && _step == 3) {
          _goToStep(4);
        }
      });
      return;
    }

    if (next is AuthTotpVerified) {
      _sessionId = next.sessionId;
      _totpPhaseFinished = true;
      _goToStep(5);
      return;
    }

    if (next is AuthAuthenticated) {
      _sessionPassword = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _totpController.clear();
      _totpSecret = '';
      _qrCodeUri = '';
      _backupCodes = const [];
      unawaited(_confirmSignupSuccess(next));
      return;
    }

    if (next is AuthOnboardingOutcomeUnknown) {
      _totpTransitionTimer?.cancel();
      _goToStep(5);
      return;
    }

    if (next is AuthError) {
      _totpTransitionTimer?.cancel();
      if (next.resumeState is AuthRequiresTotpSetup) {
        _goToStep(4);
        _showInlineFeedback(
            title: context.tr.authFlowInterruptedTitle,
            message: ErrorTranslator.translate(context.tr, next.toString()),
            target: _SignupErrorTarget.totp);
        return;
      }
      final isDeviceBound = next.errorCode == 'AUTH_024' ||
          next.errorCode == 'ERR_AUTH_DEVICE_ALREADY_BOUND' ||
          (next.data is Map &&
              (next.data as Map)['action']?.toString() ==
                  'CONFIRM_UNLINK_DEVICE');
      if (isDeviceBound && _step == 5 && _sessionId.isNotEmpty) {
        unawaited(_promptDeviceUnlinkAndRetry(next));
        return;
      }
      if (next.resumeState is AuthTotpVerified) {
        _goToStep(5);
        _showInlineFeedback(
          title: context.tr.authFlowInterruptedTitle,
          message: ErrorTranslator.translate(context.tr, next.toString()),
          target: _SignupErrorTarget.general,
        );
        return;
      }
      final wasTotpOrPasskeyStep = _step == 4 || _step == 5;
      if (_step == 3 || wasTotpOrPasskeyStep) {
        _sessionId = '';
        _sessionPassword = null;
        _totpOptional = false;
        _totpPhaseFinished = false;
        _totpSecret = '';
        _qrCodeUri = '';
        _backupCodes = const [];
        _goToStep(wasTotpOrPasskeyStep ? 0 : 2);
      }
      _showInlineFeedback(
        title: context.tr.authFlowInterruptedTitle,
        message: ErrorTranslator.translate(context.tr, next.toString()),
        target: _SignupErrorTarget.general,
      );
    }
  }

  Future<void> _promptDeviceUnlinkAndRetry(AuthError error) async {
    if (!mounted || _deviceUnlinkDialogOpen) return;
    final sessionId = _sessionId;
    _deviceUnlinkDialogOpen = true;
    final l10n = context.tr;
    final data = error.data is Map
        ? Map<String, dynamic>.from(error.data as Map)
        : const <String, dynamic>{};
    final previous = (data['previousUsernameMasked'] ??
            data['previous_username_masked'] ??
            '***')
        .toString();
    final guidanceRaw = data['guidance']?.toString().trim();
    final guidance = (guidanceRaw == null || guidanceRaw.isEmpty)
        ? l10n.authDeviceUnlinkDefaultGuidance
        : guidanceRaw;

    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _signupPanel,
            title: Text(
              l10n.authDeviceUnlinkTitle,
              style: TextStyle(color: _signupText),
            ),
            content: Text(
              l10n.authDeviceUnlinkBody(previous, guidance),
              style: TextStyle(color: _signupMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.authDeviceUnlinkCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.authDeviceUnlinkConfirmSignup,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _deviceUnlinkDialogOpen = false;
    }
    if (!mounted ||
        _sessionId != sessionId ||
        !identical(ref.read(authControllerProvider), error)) {
      return;
    }
    if (confirmed == true) {
      ref.read(authControllerProvider.notifier).registerPasskeyOnboarding(
            sessionId,
            confirmUnlinkDevice: true,
          );
      return;
    }

    _showInlineFeedback(
      title: l10n.authDeviceUnlinkCancelledTitle,
      message: l10n.authDeviceUnlinkCancelledMessage(previous),
      target: _SignupErrorTarget.general,
    );
  }

  Future<void> _startAppAfterSuccess() async {
    final state = ref.read(authControllerProvider);
    if (_isContinuing || state is! AuthAuthenticated) return;
    setState(() => _isContinuing = true);
    try {
      await FirstAccessProgress.markPending(
        ref.read(sharedPreferencesProvider),
        state.user.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signupProgressSaveError(context))),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
    if (!mounted || ref.read(authControllerProvider) != state) return;
    AppScreenFeedbackBus.clear();
    context.go('/home_loading');
  }

  Future<void> _confirmSignupSuccess(AuthAuthenticated owner) async {
    try {
      await FirstAccessProgress.markPending(
        ref.read(sharedPreferencesProvider),
        owner.user.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signupProgressSaveError(context))),
        );
      }
    }
    if (!mounted || ref.read(authControllerProvider) != owner) return;
    HapticFeedback.lightImpact();
    _goToStep(6);
  }

  String? _usernameError(BuildContext context, String value) {
    final username = value.trim();
    if (username.length < 3) {
      return context.tr.authUsernameMinError;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return context.tr.authUsernameCharsError;
    }
    return null;
  }

  void _normalizeUsername(String value) {
    final sanitized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final normalized = sanitized.substring(0, sanitized.length.clamp(0, 24));
    if (normalized != value) {
      _usernameController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    setState(() {
      _inlineFeedbackTitle = null;
      _inlineFeedbackMessage = null;
      _inlineFeedbackTarget = null;
    });
  }

  void _goToStep(int nextStep) {
    if (nextStep == _step) {
      return;
    }
    setState(() {
      _isForward = nextStep > _step;
      _step = nextStep;
      _inlineFeedbackTitle = null;
      _inlineFeedbackMessage = null;
      _inlineFeedbackTarget = null;
    });
  }

  void _showInlineFeedback({
    required String title,
    required String message,
    IconData icon = KeroseneIcons.error,
    _SignupErrorTarget target = _SignupErrorTarget.general,
  }) {
    HapticFeedback.lightImpact();
    setState(() {
      _inlineFeedbackTitle = title;
      _inlineFeedbackMessage = message;
      _inlineFeedbackIcon = icon;
      _inlineFeedbackTarget = target;
      _inlineFeedbackPulseKey += 1;
    });
  }

  void _clearInlineFeedback() {
    if (_inlineFeedbackTitle == null && _inlineFeedbackMessage == null) {
      return;
    }
    setState(() {
      _inlineFeedbackTitle = null;
      _inlineFeedbackMessage = null;
      _inlineFeedbackTarget = null;
    });
  }

  void _openSignupLogin() {
    final state = ref.read(authControllerProvider);
    final username =
        state is AuthOnboardingOutcomeUnknown ? state.username : _username;
    ref.read(authControllerProvider.notifier).clearError();
    context.go('/login', extra: username);
  }

  void _handleBack() {
    if (ref.read(authControllerProvider) is AuthLoading) return;
    if (_resumedVerifiedEnrollment && _step == 5) {
      _openSignupLogin();
      return;
    }
    if (ref.read(authControllerProvider) is AuthOnboardingOutcomeUnknown) {
      _openSignupLogin();
      return;
    }
    if (_step == 4) {
      _goToStep(2);
      return;
    }
    if (_step == 0 || _step >= 6) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_step == 3) {
      ref.read(authControllerProvider.notifier).clearError();
      _totpTransitionTimer?.cancel();
      _goToStep(2);
      return;
    }
    _goToStep(_step - 1);
  }

  void _continueFromUsername() {
    final error = _usernameError(context, _username);
    if (error != null) {
      _showInlineFeedback(
        title: context.tr.authInvalidUsernameTitle,
        message: error,
        target: _SignupErrorTarget.username,
      );
      return;
    }
    _goToStep(1);
  }

  void _continueFromPassword() {
    if (!_passwordLooksStrong) {
      _showInlineFeedback(
        title: context.tr.authWeakPasswordTitle,
        message: context.tr.authPasswordStrengthMessage,
        target: _SignupErrorTarget.passphrase,
      );
      return;
    }
    _goToStep(2);
  }

  void _submitSignup() {
    if (ref.read(authControllerProvider) is AuthLoading || _step != 2) return;
    final usernameError = _usernameError(context, _username);
    if (usernameError != null) {
      _goToStep(0);
      _showInlineFeedback(
        title: context.tr.authInvalidUsernameTitle,
        message: usernameError,
        target: _SignupErrorTarget.username,
      );
      return;
    }

    if (!_passwordLooksStrong) {
      _goToStep(1);
      _showInlineFeedback(
        title: context.tr.authWeakPasswordTitle,
        message: context.tr.authPasswordStrengthMessage,
        target: _SignupErrorTarget.passphrase,
      );
      return;
    }

    if (_confirmPasswordController.text != _password) {
      _showInlineFeedback(
        title: context.tr.authInvalidConfirmationTitle,
        message: context.tr.authPasswordMismatchMessage,
        target: _SignupErrorTarget.confirmation,
      );
      return;
    }

    if (!_acceptedPasswordRisk) {
      _showInlineFeedback(
        title: context.tr.authConfirmationRequiredTitle,
        message: context.tr.authPasswordRiskRequiredMessage,
        target: _SignupErrorTarget.risk,
      );
      return;
    }

    final state = ref.read(authControllerProvider);
    final setup = state is AuthRequiresTotpSetup
        ? state
        : state is AuthError && state.resumeState is AuthRequiresTotpSetup
            ? state.resumeState as AuthRequiresTotpSetup
            : null;
    if (setup != null &&
        setup.username == _username &&
        setup.passphrase == _password) {
      _goToStep(4);
      return;
    }
    final verified = state is AuthTotpVerified
        ? state
        : state is AuthError && state.resumeState is AuthTotpVerified
            ? state.resumeState as AuthTotpVerified
            : null;
    if (verified != null &&
        _sessionId == verified.sessionId &&
        verified.username == _username &&
        _sessionPassword == _password) {
      _goToStep(5);
      return;
    }
    _totpTransitionTimer?.cancel();
    _goToStep(3);
    ref.read(authControllerProvider.notifier).signup(
          username: _username,
          password: _password,
        );
  }

  void _skipTotp() {
    ref.read(authControllerProvider.notifier).skipTotpSetup();
  }

  void _verifyTotp() {
    if (ref.read(authControllerProvider) is AuthLoading) return;
    if (_totpPhaseFinished) {
      _goToStep(5);
      return;
    }
    if (_totpCode.length != 6) {
      _showInlineFeedback(
        title: context.tr.authInvalidConfirmationTitle,
        message: context.tr.authSignupTotpCodeRequiredMessage,
        target: _SignupErrorTarget.totp,
      );
      return;
    }

    ref.read(authControllerProvider.notifier).verifyTotp(
          username: _username,
          passphrase: _password,
          totpSecret: _totpSecret,
          totpCode: _totpCode,
        );
  }

  void _registerPasskey() {
    if (ref.read(authControllerProvider) is AuthLoading) return;
    if (_sessionId.isEmpty) {
      _showInlineFeedback(
        title: context.tr.authSecurityPreparingTitle,
        message: context.tr.authSecurityPreparingMessage,
        icon: KeroseneIcons.info,
        target: _SignupErrorTarget.general,
      );
      return;
    }
    ref.read(authControllerProvider.notifier).registerPasskeyOnboarding(
          _sessionId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Theme.of(context).brightness == Brightness.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _signupInk,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
      ),
      child: PopScope(
          canPop: !isLoading && (_step == 0 || _step >= 6),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !isLoading) _handleBack();
          },
          child: Scaffold(
            backgroundColor: _signupInk,
            resizeToAvoidBottomInset: true,
            body: ColoredBox(
              color: _signupInk,
              child: _step == 6
                  ? _buildSuccessStep()
                  : SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final responsive = context.responsive;
                          final horizontalPadding =
                              responsive.isTinyPhone ? 20.0 : 24.0;
                          final maxWidth = responsive.formMaxWidth;
                          final topSpacing =
                              responsive.isTinyPhone ? 10.0 : 16.0;
                          // The Scaffold already excludes the keyboard inset.
                          const bottomPadding = 28.0;

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              topSpacing,
                              horizontalPadding,
                              bottomPadding,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxWidth,
                                  minHeight: math.max(
                                      0,
                                      constraints.maxHeight -
                                          topSpacing -
                                          bottomPadding),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SignupTopBar(
                                      step: _step,
                                      totalSteps: 6,
                                      onBack: isLoading ? null : _handleBack,
                                    ),
                                    if (_inlineFeedbackMessage != null) ...[
                                      const SizedBox(height: 18),
                                      AuthMotionShake(
                                        triggerKey: _inlineFeedbackPulseKey,
                                        child: SignupInlineFeedback(
                                          title: _inlineFeedbackTitle ??
                                              context
                                                  .tr.authFlowInterruptedTitle,
                                          message: _inlineFeedbackMessage!,
                                          icon: _inlineFeedbackIcon,
                                        ),
                                      ),
                                    ],
                                    SizedBox(
                                      height: responsive.isTinyPhone ? 24 : 34,
                                    ),
                                    AuthDirectionalSwitcher(
                                      isForward: _isForward,
                                      child: KeyedSubtree(
                                        key: ValueKey(_step),
                                        child: _buildStepBody(isLoading),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          )),
    );
  }

  Widget _buildStepBody(bool isLoading) {
    return switch (_step) {
      0 => _buildUsernameStep(),
      1 => _buildPassphraseStep(),
      2 => _buildConfirmationStep(isLoading),
      3 => _buildCreatingStep(),
      4 => _buildTotpStep(isLoading),
      5 => _buildPasskeyStep(isLoading),
      6 => _buildSuccessStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildUsernameStep() {
    return SignupStepColumn(
      title: signupCreateAccountTitle(context),
      subtitle: signupUsernameSubtitle(context),
      children: [
        AuthMotionShake(
          triggerKey: _inlineFeedbackPulseKey,
          enabled: _inlineFeedbackTarget == _SignupErrorTarget.username,
          child: SignupTextField(
            controller: _usernameController,
            label: context.tr.authSignupUsernameLabel,
            hintText: signupUsernameHint(context),
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            keyboardType: TextInputType.text,
            onChanged: _normalizeUsername,
            onSubmitted: (_) => _continueFromUsername(),
            suffixIcon: _usernameController.text.isNotEmpty
                ? AnimatedSwitcher(
                    duration: AuthMotion.entrance,
                    child: KeroseneIcon(
                      _usernameLooksValid
                          ? KeroseneIcons.success
                          : KeroseneIcons.warning,
                      key: ValueKey<bool>(_usernameLooksValid),
                      size: 18,
                      color: _usernameLooksValid ? _signupText : _signupMuted,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 18),
        SignupRuleRow(
          passed: _username.length >= 3,
          text: context.tr.authSignupUsernameRuleMin,
        ),
        SignupRuleRow(
          passed: _username.isNotEmpty &&
              RegExp(r'^[a-z0-9_]+$').hasMatch(_username),
          text: signupUsernameCharsetRule(context),
        ),
        SignupRuleRow(
          passed: _usernameController.text ==
              _usernameController.text.toLowerCase(),
          text: context.tr.authSignupUsernameRuleLowercase,
        ),
        const SizedBox(height: 68),
        SignupPrimaryButton(
          text: context.tr.continueButton,
          onPressed: _continueFromUsername,
        ),
      ],
    );
  }

  Widget _buildPassphraseStep() {
    return SignupStepColumn(
      title: signupPassphraseTitle(context),
      subtitle: signupPassphraseSubtitle(context),
      children: [
        AuthMotionShake(
          triggerKey: _inlineFeedbackPulseKey,
          enabled: _inlineFeedbackTarget == _SignupErrorTarget.passphrase,
          child: SignupTextField(
            controller: _passwordController,
            label: signupPassphraseLabel(context),
            hintText: signupPassphraseHint(context),
            autofocus: true,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) {
              _clearInlineFeedback();
              setState(() {});
            },
            onSubmitted: (_) => _continueFromPassword(),
            suffixIcon: IconButton(
              onPressed: () => setState(() {
                _obscurePassword = !_obscurePassword;
              }),
              icon: KeroseneIcon(
                _obscurePassword ? KeroseneIcons.eye : KeroseneIcons.eyeOff,
                size: 18,
                color: _signupMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SignupRuleRow(
          passed: _passwordHasMin,
          text: context.tr.authSignupPassphraseRuleMin,
        ),
        SignupRuleRow(
          passed: _passwordHasUpper,
          text: context.tr.authSignupPassphraseRuleUppercase,
        ),
        SignupRuleRow(
          passed: _passwordHasLower,
          text: context.tr.authSignupPassphraseRuleLowercase,
        ),
        SignupRuleRow(
          passed: _passwordHasNumber,
          text: context.tr.authSignupPassphraseRuleNumber,
        ),
        SignupRuleRow(
          passed: _passwordHasSymbol,
          text: context.tr.authSignupPassphraseRuleSymbol,
        ),
        const SizedBox(height: 54),
        SignupPrimaryButton(
          text: signupProceedAction(context),
          onPressed: _continueFromPassword,
          borderRadius: 999,
        ),
      ],
    );
  }

  Widget _buildConfirmationStep(bool isLoading) {
    return SignupStepColumn(
      title: signupConfirmTitle(context),
      subtitle: signupConfirmSubtitle(context),
      children: [
        AuthMotionShake(
          triggerKey: _inlineFeedbackPulseKey,
          enabled: _inlineFeedbackTarget == _SignupErrorTarget.confirmation,
          child: SignupTextField(
            controller: _confirmPasswordController,
            label: context.tr.authSignupConfirmPassphraseLabel,
            hintText: signupConfirmHint(context),
            autofocus: true,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) {
              _clearInlineFeedback();
              setState(() {});
            },
            onSubmitted: (_) => isLoading ? null : _submitSignup(),
            suffixIcon: IconButton(
              onPressed: () => setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              }),
              icon: KeroseneIcon(
                _obscureConfirmPassword
                    ? KeroseneIcons.eye
                    : KeroseneIcons.eyeOff,
                size: 18,
                color: _signupMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        AuthMotionShake(
          triggerKey: _inlineFeedbackPulseKey,
          enabled: _inlineFeedbackTarget == _SignupErrorTarget.risk,
          child: SignupRiskAcknowledgement(
            checked: _acceptedPasswordRisk,
            text: context.tr.authSignupPassphraseRiskAcknowledgement,
            onTap: () => setState(() {
              _inlineFeedbackTitle = null;
              _inlineFeedbackMessage = null;
              _inlineFeedbackTarget = null;
              _acceptedPasswordRisk = !_acceptedPasswordRisk;
            }),
          ),
        ),
        const SizedBox(height: 66),
        SignupPrimaryButton(
          text: signupFinishCreateAccountAction(context),
          isLoading: isLoading,
          onPressed: isLoading ? null : _submitSignup,
        ),
      ],
    );
  }

  Widget _buildCreatingStep() {
    return AuthMotionStagger(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        SizedBox(
          width: 72,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              KeroseneIcon(
                KeroseneIcons.shield,
                size: 82,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.92),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: KeroseneIcon(
                  KeroseneIcons.lock,
                  size: 28,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text(
          signupCreatingAlmostReadyTitle(context),
          textAlign: TextAlign.center,
          style: SignupTypography.title(),
        ),
        const SizedBox(height: 12),
        Text(
          signupCreatingAlmostReadySubtitle(context),
          textAlign: TextAlign.center,
          style: SignupTypography.subtitle(),
        ),
        const SizedBox(height: 70),
        const SignupSpinner(size: 64, strokeWidth: 4),
        const SizedBox(height: 26),
        Text(
          signupCreatingSecurityProgress(context),
          textAlign: TextAlign.center,
          style: SignupTypography.bodySmall(color: _signupMuted),
        ),
      ],
    );
  }

  Widget _buildTotpStep(bool isLoading) {
    return SignupStepColumn(
      title: _totpPhaseFinished
          ? context.tr.flowSignupTotpFinishedTitle
          : _totpOptional
              ? signupTotpTitle(context)
              : context.tr.flowSignupTotpRequiredTitle,
      subtitle: _totpPhaseFinished
          ? context.tr.flowSignupTotpFinishedSubtitle
          : _totpOptional
              ? signupTotpSubtitle(context)
              : context.tr.flowSignupTotpRequiredSubtitle,
      children: [
        if (!_totpPhaseFinished) ...[
          NumberedInstruction(
            number: 1,
            text: context.tr.authSignupTotpScanInstruction,
          ),
          const SizedBox(height: 18),
          Center(
            child: TotpQrBox(data: _qrCodeUri, size: 160),
          ),
          const SizedBox(height: 26),
          NumberedInstruction(
            number: 2,
            text: signupTotpCodeInstruction(context),
          ),
          const SizedBox(height: 14),
          AuthMotionShake(
            triggerKey: _inlineFeedbackPulseKey,
            enabled: _inlineFeedbackTarget == _SignupErrorTarget.totp,
            child: TotpDigitBoxes(
              controller: _totpController,
              enabled: !isLoading && !_totpPhaseFinished,
              onChanged: (_) {
                _clearInlineFeedback();
                setState(() {});
              },
              onSubmitted: (_) => isLoading ? null : _verifyTotp(),
            ),
          ),
          const SizedBox(height: 34),
        ],
        Text(
          signupRecoveryCodesTitle(context),
          style: SignupTypography.sectionTitle(),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr.authSignupRecoveryCodesBody,
          style: SignupTypography.bodySmall(),
        ),
        const SizedBox(height: 14),
        RecoveryCodesCopyButton(
          codes: _backupCodes,
          onCopied: _showRecoveryCodesCopied,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            if (_totpOptional && !_totpPhaseFinished)
              Expanded(
                child: SignupPrimaryButton(
                  text: signupSkipAction(context),
                  outlined: true,
                  onPressed: isLoading ? null : _skipTotp,
                  borderRadius: 999,
                ),
              ),
            if (_totpOptional && !_totpPhaseFinished) const SizedBox(width: 12),
            Expanded(
              child: SignupPrimaryButton(
                text: _totpPhaseFinished
                    ? context.tr.continueButton
                    : signupConfirmAction(context),
                isLoading: isLoading,
                onPressed: isLoading ? null : _verifyTotp,
                borderRadius: 999,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasskeyStep(bool isLoading) {
    final unknown =
        ref.read(authControllerProvider) is AuthOnboardingOutcomeUnknown;
    return SignupStepColumn(
      title: unknown
          ? context.tr.flowSignupUnknownTitle
          : isLoading
              ? signupConfirmingPasskeyTitle(context)
              : signupPasskeyTitle(context),
      subtitle: unknown
          ? context.tr.flowSignupUnknownSubtitle
          : isLoading
              ? signupConfirmingPasskeySubtitle(context)
              : signupPasskeySubtitle(context),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _signupBorderSoft),
              color: _signupPanel,
            ),
            child: AnimatedSwitcher(
              duration: AuthMotion.reduce(context)
                  ? Duration.zero
                  : KeroseneMotion.medium,
              child: KeroseneIcon(
                unknown ? KeroseneIcons.info : KeroseneIcons.biometric,
                key: ValueKey(unknown),
                size: 58,
                color: _signupText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (!unknown)
          Semantics(
            liveRegion: true,
            child: Text(
              signupPasskeyRequiredBody(context),
              textAlign: TextAlign.center,
              style: SignupTypography.bodySmall(),
            ),
          ),
        const SizedBox(height: 46),
        SignupPrimaryButton(
          text: unknown
              ? context.tr.flowSignupConfirmByLoginAction
              : signupAuthorizeDeviceAction(context),
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : unknown
                  ? _openSignupLogin
                  : _registerPasskey,
          borderRadius: 999,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return SignupSuccessScene(
      appTitle: context.tr.appTitle,
      title: context.tr.authSignupSuccessTitle,
      subtitle: signupSetupNextBody(context),
      actionLabel: context.tr.continueButton,
      isLoading: _isContinuing,
      onContinue: _startAppAfterSuccess,
    );
  }

  void _showRecoveryCodesCopied() {
    final codes = _backupCodes.where((code) => code.trim().isNotEmpty).toList();
    if (codes.isEmpty) {
      _showInlineFeedback(
        title: signupRecoveryCodesUnavailableTitle(context),
        message: signupRecoveryCodesUnavailableMessage(context),
        icon: KeroseneIcons.info,
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: codes.join('\n')));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(signupRecoveryCodesCopiedMessage(context)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _signupField,
        ),
      );
  }
}
