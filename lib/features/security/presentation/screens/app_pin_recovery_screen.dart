import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_motion.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/application/app_pin_recovery_service.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

/// Reachable while entry is locked, but never without an authenticated account.
class AppPinRecoveryScreen extends ConsumerStatefulWidget {
  const AppPinRecoveryScreen({super.key});
  @override
  ConsumerState<AppPinRecoveryScreen> createState() =>
      _AppPinRecoveryScreenState();
}

class _AppPinRecoveryScreenState extends ConsumerState<AppPinRecoveryScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  String? _scope;
  String? _username;
  String? _error;
  bool _busy = false;
  bool _done = false;
  bool _backgrounded = false;
  bool _interruptedBusy = false;
  bool _showUnknownHint = false;
  int _epoch = 0;
  int _errorRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scope = ref.read(sessionStorageScopeProvider);
    final auth = ref.read(authControllerProvider);
    _username = auth is AuthAuthenticated ? auth.user.username : null;
  }

  bool get _owns =>
      mounted &&
      _scope != null &&
      ref.read(sessionStorageScopeProvider) == _scope &&
      ref.read(authControllerProvider) is AuthAuthenticated;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Platform authentication can temporarily make the app inactive. A real
    // background transition clears draft secrets and invalidates a late result.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
      _interruptedBusy = _busy;
      _epoch++;
      _password.clear();
      _pin.clear();
      _confirmation.clear();
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      if (mounted) {
        setState(() {
          _busy = false;
          if (_interruptedBusy) {
            _error = context.tr.pinRecoveryInterrupted;
            _showUnknownHint = true;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_owns) return;
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      setState(() => _errorRevision++);
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final epoch = ++_epoch;
    bool current() => _owns && !_backgrounded && epoch == _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _showUnknownHint = false;
    });
    try {
      await ref.read(appPinRecoveryServiceProvider).replace(
          username: _username!,
          password: _password.text,
          newPin: _pin.text,
          isCurrent: current);
      if (!current()) return;
      final prefs = ref.read(sharedPreferencesProvider);
      // Hints choose the next pad length; they never unlock the PIN gate.
      final saved = await prefs.setInt(appPinLengthPrefsKey(_scope!), 4);
      if (!current()) return;
      if (!saved) throw StateError('PIN length hint was not saved.');
      if (!await prefs.setBool(appPinConfiguredPrefsKey(_scope!), true)) {
        throw StateError('PIN configuration hint was not saved.');
      }
      if (!current()) return;
      bumpAppPinLocalState(ref);
      ref.invalidate(appPinStatusProvider);
      HapticFeedback.mediumImpact();
      setState(() => _done = true);
    } catch (error) {
      if (current()) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorRevision++;
          _showUnknownHint = error is NetworkException ||
              error is FormatException ||
              (error is AppException &&
                  (error.statusCode == null || error.statusCode! >= 500));
          _error = ErrorTranslator.translate(context.tr, error.toString());
        });
      }
    } finally {
      if (mounted && epoch == _epoch) {
        _password.clear();
        _pin.clear();
        _confirmation.clear();
        setState(() => _busy = false);
      }
    }
  }

  void _leave() {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home_loading');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(sessionStorageScopeProvider, (_, next) {
      if (next != _scope) {
        _epoch++;
        _password.clear();
        _pin.clear();
        _confirmation.clear();
      }
    });
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthAuthenticated || !_owns) {
      return Scaffold(
          body: Center(
              child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(context.tr.firstAccessSignIn))));
    }
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: context.responsive.formConstraints,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
                key: _form,
                child: AuthMotionShake(
                    triggerKey: _errorRevision,
                    child: AnimatedSwitcher(
                      duration: KeroseneMotion.reduceMotion(context)
                          ? Duration.zero
                          : KeroseneMotion.medium,
                      child: Column(
                        key: ValueKey(_done),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                  onPressed: _busy ? null : _leave,
                                  tooltip: MaterialLocalizations.of(context)
                                      .backButtonTooltip,
                                  icon:
                                      const KeroseneIcon(KeroseneIcons.back))),
                          const SizedBox(height: 28),
                          KeroseneIcon(
                              _done ? KeroseneIcons.success : KeroseneIcons.key,
                              size: 48),
                          const SizedBox(height: 24),
                          Text(
                              _done
                                  ? context.tr.pinRecoveryDone
                                  : context.tr.pinRecoveryTitle,
                              style: AppTypography.inter(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 12),
                          Text(
                              _done
                                  ? context.tr.pinRecoveryDoneBody
                                  : context.tr.pinRecoveryBody,
                              style: AppTypography.bodyMedium
                                  .copyWith(fontSize: 14, height: 1.45)),
                          const SizedBox(height: 28),
                          if (!_done) ...[
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                enabled: !_busy,
                                enableSuggestions: false,
                                autocorrect: false,
                                decoration: InputDecoration(
                                    labelText: context.tr.pinRecoveryPassword),
                                validator: (value) => value?.isNotEmpty == true
                                    ? null
                                    : context.tr.pinRecoveryPasswordRequired),
                            const SizedBox(height: 18),
                            _pinField(_pin, context.tr.pinRecoveryNewPin),
                            const SizedBox(height: 18),
                            _pinField(
                                _confirmation, context.tr.pinRecoveryConfirmPin,
                                confirm: true),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: AppTypography.bodySmall.copyWith(
                                        color: theme.colorScheme.error))),
                            if (_showUnknownHint) ...[
                              const SizedBox(height: 8),
                              Text(context.tr.pinRecoveryUnknownHint,
                                  style: AppTypography.bodySmall),
                            ],
                          ],
                          const SizedBox(height: 28),
                          if (_busy) ...[
                            const Center(
                                child: CircularProgressIndicator.adaptive()),
                            const SizedBox(height: 16),
                            Text(context.tr.pinRecoveryConfirming,
                                textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: _busy
                                  ? null
                                  : _done
                                      ? _leave
                                      : _submit,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  backgroundColor: theme.colorScheme.onSurface,
                                  foregroundColor: theme.colorScheme.surface),
                              child: Text(_done
                                  ? context.tr.pinRecoveryBack
                                  : context.tr.pinRecoveryContinue)),
                          if (!_done)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      context.push('/recovery/emergency');
                                    },
                              child: Text(context.tr.loginLostAccessButton),
                            ),
                        ],
                      ),
                    ))),
          ),
        ))),
      ),
    );
  }

  Widget _pinField(TextEditingController controller, String label,
          {bool confirm = false}) =>
      TextFormField(
          controller: controller,
          obscureText: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4)
          ],
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            if (!RegExp(r'^\d{4}$').hasMatch(value ?? '')) {
              return context.tr.pinRecoveryFourDigits;
            }
            if (confirm && value != _pin.text) {
              return context.tr.pinRecoveryMismatch;
            }
            return null;
          });
}
