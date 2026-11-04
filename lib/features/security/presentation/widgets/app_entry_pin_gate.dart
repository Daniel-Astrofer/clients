import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'pin_entry_scaffold.dart';
import 'pin_background_rotator.dart';

/// App entry PIN (authenticated / token session).
///
/// Parent shell keeps the K logo until Tor is settled, then mounts this gate
/// **once** — so the user is never asked for PIN pre-Tor and again post-Tor.
///
/// Flow:
/// 1. K logo (splash + Tor) — outside this widget
/// 2. PIN pad once → verify (Tor already ready)
/// 3. Unlock → child
class AppEntryPinGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppEntryPinGate({super.key, required this.child});

  @override
  ConsumerState<AppEntryPinGate> createState() => _AppEntryPinGateState();
}

class _AppEntryPinGateState extends ConsumerState<AppEntryPinGate> {
  String? _statusSyncScope;

  void _kickServerStatusSyncOnce() {
    final scope = ref.read(sessionStorageScopeProvider);
    if (scope == null || _statusSyncScope == scope) return;
    if (!ref.read(torSettledProvider)) return;
    if (ref.read(appEntryPinUnlockedProvider) || AppEntryPinSession.unlocked) {
      return;
    }
    _statusSyncScope = scope;
    // Fire-and-forget — never watch AsyncValue (would rebuild the pad).
    unawaited(ref.read(appPinGateServerSyncProvider.future));
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(sessionStorageScopeProvider);
    final unlocked =
        ref.watch(appEntryPinUnlockedProvider) || AppEntryPinSession.unlocked;
    if (scope != null && unlocked) {
      if (!ref.read(appEntryPinUnlockedProvider) &&
          AppEntryPinSession.unlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || ref.read(sessionStorageScopeProvider) != scope) {
            return;
          }
          if (AppEntryPinSession.unlocked) {
            ref.read(appEntryPinUnlockedProvider.notifier).unlock();
          }
        });
      }
      return widget.child;
    }

    // Safety net: if this gate is mounted before Tor (e.g. named route), hold
    // dots instead of showing a pad that will be remounted when Tor settles.
    final torSettled = ref.watch(torSettledProvider);
    if (scope == null || !torSettled) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: TorLoadingDots(
            dotSize: 7,
            spacing: 10,
            travel: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    // Tor is up — optional one-shot status sync (no watch).
    _kickServerStatusSyncOnce();

    final status = ref.watch(appPinGateStatusProvider);

    if (status.requiresSetup) {
      return _AppEntryPinSetupScreen(
        key: ValueKey(('app-entry-pin-setup', scope)),
        status: status,
      );
    }
    if (!status.requiresVerification) {
      return widget.child;
    }
    return _AppEntryPinLockScreen(
      key: ValueKey(('app-entry-pin-lock', scope)),
      status: status,
    );
  }
}

class _AppEntryPinSetupScreen extends ConsumerStatefulWidget {
  final AppPinStatus status;

  const _AppEntryPinSetupScreen({super.key, required this.status});

  @override
  ConsumerState<_AppEntryPinSetupScreen> createState() =>
      _AppEntryPinSetupScreenState();
}

class _AppEntryPinSetupScreenState
    extends ConsumerState<_AppEntryPinSetupScreen> with WidgetsBindingObserver {
  late final String? _ownerScope;
  Object? _request;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _ownsSession =>
      mounted &&
      _ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !mounted) return;
    if (_request case final request?) AppEntryPinSession.endPinRequest(request);
    _request = null;
    setState(() {
      _pin = '';
      _confirmation = '';
      _confirming = false;
      _busy = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_request case final request?) AppEntryPinSession.endPinRequest(request);
    _pin = '';
    _confirmation = '';
    super.dispose();
  }

  bool _busy = false;
  bool _confirming = false;
  bool _handoffApplied = false;
  String _pin = '';
  String _confirmation = '';
  String? _error;
  static const int _pinLength = 4;

  bool get _supportsFourDigitPin =>
      widget.status.minPinLength > 0 &&
      widget.status.minPinLength <= _pinLength &&
      widget.status.maxPinLength >= _pinLength;

  String get _currentInput => _confirming ? _confirmation : _pin;

  set _currentInput(String value) {
    if (_confirming) {
      _confirmation = value;
    } else {
      _pin = value;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handoffApplied) return;
    _handoffApplied = true;
    // AUTH_018 path: user already typed a PIN on the unlock pad — only confirm.
    final handoff = AppPinSetupHandoff.take();
    if (handoff != null &&
        handoff.length == _pinLength &&
        _supportsFourDigitPin) {
      _pin = handoff;
      _confirming = true;
      _confirmation = '';
    }
  }

  void _appendDigit(String digit) {
    if (_busy ||
        !_ownsSession ||
        !_supportsFourDigitPin ||
        _currentInput.length >= _pinLength) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _currentInput = _currentInput + digit;
      _error = null;
    });
    if (_currentInput.length == _pinLength) {
      unawaited(_submit());
    }
  }

  void _deleteDigit() {
    if (_busy || _currentInput.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_ownsSession || !_supportsFourDigitPin) return;
    final input = _currentInput;
    if (input.length != _pinLength) {
      setState(() {
        _error = context.tr.appEntryPinLengthError(_pinLength, _pinLength);
      });
      return;
    }

    if (!_confirming) {
      setState(() {
        _confirming = true;
        _confirmation = '';
        _error = null;
      });
      return;
    }

    if (_pin != _confirmation) {
      setState(() {
        _error = context.tr.securityPinMismatchError;
        _pin = '';
        _confirmation = '';
        _confirming = false;
      });
      return;
    }

    final pinToConfigure = _pin;
    setState(() {
      _busy = true;
      _error = null;
    });
    final request = _request = AppEntryPinSession.beginPinRequest();
    bool current() =>
        _ownsSession && AppEntryPinSession.isCurrentPinRequest(request);
    try {
      final torReady = await ref
          .read(appColdStartProvider.notifier)
          .waitUntilTorReadyForApi();
      if (!mounted || !current()) return;
      if (!torReady) {
        setState(() => _error = _torStillWarmingMessage(context));
        return;
      }
      final result = await ref
          .read(securityRepositoryProvider)
          .configureAppPin(enabled: true, pin: pinToConfigure);
      if (!current()) return;
      result.fold(
        (failure) => setState(() =>
            _error = ErrorTranslator.translate(context.tr, failure.toString())),
        (status) {
          if (!status.enabled || !status.configured || status.locked) {
            setState(
                () => _error = context.tr.securityUpdateUnconfirmedMessage);
            ref.invalidate(appPinStatusProvider);
            return;
          }
          _pin = '';
          _confirmation = '';
          ref.read(appEntryPinUnlockedProvider.notifier).unlock();
          _persistPinConfiguredHint(ref,
              configured: true, pinLength: pinToConfigure.length);
        },
      );
    } catch (error) {
      if (current()) {
        setState(() =>
            _error = ErrorTranslator.translate(context.tr, error.toString()));
      }
    } finally {
      final ownsRequest = identical(_request, request);
      AppEntryPinSession.endPinRequest(request);
      if (ownsRequest) {
        _request = null;
        if (_ownsSession) setState(() => _busy = false);
      } else if (_ownsSession &&
          _request == null &&
          !ref.read(appEntryPinUnlockedProvider)) {
        // Backgrounding discards the input and ignores this response, but an
        // already-sent write can still commit. Reconcile through a fresh server
        // read; a late setup response must never unlock the application.
        unawaited(_refreshAfterUnconfirmedWrite());
      }
    }
  }

  Future<void> _refreshAfterUnconfirmedWrite() async {
    try {
      ref.invalidate(appPinGateServerSyncProvider);
      await ref.read(appPinGateServerSyncProvider.future);
    } catch (error) {
      if (_ownsSession) {
        setState(() =>
            _error = ErrorTranslator.translate(context.tr, error.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinEntryScaffold(
      instruction: _confirming
          ? _appEntryPinConfirmInstruction(context)
          : _appEntryPinCreateInstruction(context),
      subtitle: _confirming
          ? context.tr.appEntryPinConfirmSubtitle
          : context.tr.appEntryPinCreateSubtitle,
      valueLength: _currentInput.length,
      maxLength: _pinLength,
      error: _supportsFourDigitPin
          ? _error
          : context.tr.appEntryPinUnavailableMessage,
      enabled: _supportsFourDigitPin,
      busy: _busy,
      busyLabel: context.tr.pinEntrySaving,
      onDigit: _appendDigit,
      onDelete: _deleteDigit,
      onConfirm:
          _busy || !_supportsFourDigitPin || _currentInput.length != _pinLength
              ? null
              : _submit,
      confirmLabel: context.tr.confirm,
      onCancel: () async {
        if (_confirming) {
          final interrupted = _busy;
          if (_request case final request?) {
            AppEntryPinSession.endPinRequest(request);
          }
          _request = null;
          setState(() {
            _pin = '';
            _confirmation = '';
            _confirming = false;
            _busy = false;
            _error = interrupted
                ? context.tr.securityUpdateUnconfirmedMessage
                : null;
          });
          return;
        }
        await ref.read(authControllerProvider.notifier).logout();
      },
    );
  }
}

class _AppEntryPinLockScreen extends ConsumerStatefulWidget {
  final AppPinStatus status;

  const _AppEntryPinLockScreen({super.key, required this.status});

  @override
  ConsumerState<_AppEntryPinLockScreen> createState() =>
      _AppEntryPinLockScreenState();
}

class _AppEntryPinLockScreenState extends ConsumerState<_AppEntryPinLockScreen>
    with WidgetsBindingObserver {
  late final String? _ownerScope;
  Object? _request;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _ownsSession =>
      mounted &&
      _ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;
  final ValueNotifier<String> _pinNotifier = ValueNotifier('');
  final ValueNotifier<String?> _errorNotifier = ValueNotifier(null);

  String get _pin => _pinNotifier.value;
  set _pin(String val) => _pinNotifier.value = val;
  String? get _errorMessage => _errorNotifier.value;
  set _errorMessage(String? val) => _errorNotifier.value = val;

  bool _busy = false;

  /// Captured at first frame — never changes mid-entry (no provider watch).
  late final int _minPinLength = widget.status.minPinLength.clamp(4, 8);
  late final int _maxPinLength = widget.status.maxPinLength.clamp(4, 8);

  /// When min==max we know the length → auto-submit. Otherwise wait for confirm.
  late final bool _fixedLength = _minPinLength == _maxPinLength;
  late final int _pinTargetLength =
      _fixedLength ? _minPinLength : _maxPinLength;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !mounted) return;
    if (_request case final request?) AppEntryPinSession.endPinRequest(request);
    _request = null;
    setState(() {
      _pin = '';
      _errorMessage = null;
      _busy = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_request case final request?) AppEntryPinSession.endPinRequest(request);
    _pinNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    if (_busy || !_ownsSession || _pin.length >= _pinTargetLength) return;
    HapticFeedback.selectionClick();
    _pin += digit;
    _errorMessage = null;
    // Auto-submit only when we know the exact length (avoids submitting a
    // 4-digit prefix of a longer PIN and forcing a second try).
    if (_fixedLength && _pin.length == _pinTargetLength) {
      unawaited(_submit());
    }
  }

  void _deleteDigit() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    _pin = _pin.substring(0, _pin.length - 1);
    _errorMessage = null;
  }

  Future<void> _submit() async {
    if (_busy || !_ownsSession || widget.status.locked) return;
    if (_pin.length < _minPinLength || _pin.length > _maxPinLength) {
      _errorMessage = context.tr.appEntryPinLengthError(
        _minPinLength,
        _maxPinLength,
      );
      return;
    }

    // 1) Freeze digits. 2) Dots only after full PIN. 3) Wait Tor. 4) Request.
    final pinToVerify = _pin;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    // Block GET /app-pin sync from remounting the pad while verify runs.
    final request = _request = AppEntryPinSession.beginPinRequest();
    bool current() =>
        _ownsSession && AppEntryPinSession.isCurrentPinRequest(request);
    try {
      final torReady = await ref
          .read(appColdStartProvider.notifier)
          .waitUntilTorReadyForApi();
      if (!mounted || !current()) return;
      if (!torReady) {
        _errorMessage = _torStillWarmingMessage(context);
        return;
      }
      final result = await ref
          .read(securityRepositoryProvider)
          .verifyAppPin(pin: pinToVerify);
      if (!current()) return;
      result.fold(
          _applyVerifyFailure,
          (status) =>
              _applyVerifySuccess(status, pinLength: pinToVerify.length));
    } catch (error) {
      if (mounted && current()) {
        _errorMessage = ErrorTranslator.translate(context.tr, error.toString());
      }
    } finally {
      final ownsRequest = identical(_request, request);
      AppEntryPinSession.endPinRequest(request);
      if (ownsRequest) {
        _request = null;
        if (_ownsSession) setState(() => _busy = false);
      }
    }
  }

  void _applyVerifySuccess(AppPinStatus status, {required int pinLength}) {
    // Unlock **before** local-hint writes / epoch bumps so the gate cannot
    // rebuild into the pad again for one frame (double PIN).
    ref.read(appEntryPinUnlockedProvider.notifier).unlock();
    _pin = '';
    _persistPinConfiguredHint(
      ref,
      configured: true,
      pinLength: pinLength,
    );
  }

  void _applyVerifyFailure(dynamic failure) {
    final code = failure.errorCode?.toString().toUpperCase() ?? '';
    final msg = failure.message.toString().toLowerCase();
    final isWrongPin = code == 'AUTH_019' ||
        code == 'ERR_AUTH_APP_PIN_INVALID' ||
        msg.contains('pin numerico incorreto') ||
        msg.contains('pin incorreto') ||
        msg.contains('pin atual incorreto');
    final isLocked = code == 'AUTH_020' || code == 'ERR_AUTH_APP_PIN_LOCKED';
    // Server has no PIN for this device hash (common on new Linux/desktop
    // installs). Flip local hint to setup — keep the digits already typed so
    // the user only confirms once (no full re-create after unlock attempt).
    final isNotConfigured = code == 'AUTH_018' ||
        code == 'ERR_AUTH_APP_PIN_NOT_CONFIGURED' ||
        msg.contains('ainda nao configurado') ||
        msg.contains('ainda não configurado') ||
        msg.contains('not configured');

    if (isNotConfigured) {
      final typed = _pin;
      if (typed.length >= 4) {
        AppPinSetupHandoff.offer(typed);
      }
      _persistPinConfiguredHint(
        ref,
        configured: false,
        pinLength: typed.length >= 4 ? typed.length : null,
      );
      setState(() {
        _busy = false;
        _pin = '';
        _errorMessage = null;
      });
      return;
    }

    final base = isLocked
        ? context.tr.appEntryLockedHelper
        : isWrongPin
            ? context.tr.pinIncorrect
            : ErrorTranslator.translate(
                context.tr,
                failure.toString(),
              );

    setState(() {
      if (isWrongPin || isLocked) {
        _pin = '';
      }
      _errorMessage = base;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_pinNotifier, _errorNotifier]),
      builder: (context, _) {
        return PinEntryScaffold(
          background: const PinBackgroundRotator(),
          instruction: widget.status.locked
              ? context.tr.appEntryLockedHelper
              : _appEntryPinUnlockInstruction(context),
          subtitle: context.tr.appEntryPinUnlockSubtitle,
          valueLength: _pin.length,
          maxLength: _pinTargetLength,
          error: _errorMessage,
          busy: _busy,
          busyLabel: context.tr.pinEntryChecking,
          enabled: !widget.status.locked && !_busy,
          onDigit: _appendDigit,
          onDelete: _deleteDigit,
          // Confirm always available when length is flexible; with fixed length
          // auto-submit covers most cases but confirm still works as fallback.
          onConfirm:
              widget.status.locked || _busy || _pin.length < _minPinLength
                  ? null
                  : _submit,
          confirmLabel: context.tr.confirm,
          footer: TextButton(
            key: const ValueKey('app-entry-forgot-pin'),
            style: TextButton.styleFrom(
              foregroundColor: MonochromeColors.of(context).mutedText,
              minimumSize: const Size(48, 48),
            ),
            onPressed: _busy
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    _pin = '';
                    _errorMessage = null;
                    context.push('/recovery/app-pin');
                  },
            child: Text(context.tr.appEntryForgotPin),
          ),
          onCancel: () async {
            await ref.read(authControllerProvider.notifier).logout();
          },
        );
      },
    );
  }
}

String _appEntryPinCreateInstruction(BuildContext context) =>
    context.tr.appEntryPinCreateInstruction;

String _appEntryPinConfirmInstruction(BuildContext context) =>
    context.tr.appEntryPinConfirmInstruction;

String _appEntryPinUnlockInstruction(BuildContext context) =>
    context.tr.appEntryPinUnlockInstruction;

String _torStillWarmingMessage(BuildContext context) =>
    context.tr.appEntryPinTorWarming;

void _persistPinConfiguredHint(
  WidgetRef ref, {
  required bool configured,
  int? pinLength,
}) {
  final scope = ref.read(sessionStorageScopeProvider);
  if (scope == null || scope.isEmpty) return;
  final prefs = ref.read(sharedPreferencesProvider);
  prefs.setBool(appPinConfiguredPrefsKey(scope), configured);
  if (pinLength != null && pinLength >= 4 && pinLength <= 8) {
    prefs.setInt(appPinLengthPrefsKey(scope), pinLength);
  }
  // Always bump so AppEntryPinGate switches setup ↔ unlock immediately.
  bumpAppPinLocalState(ref);
}

class _TotpResetSheet extends ConsumerStatefulWidget {
  const _TotpResetSheet();

  @override
  ConsumerState<_TotpResetSheet> createState() => _TotpResetSheetState();
}

class _TotpResetSheetState extends ConsumerState<_TotpResetSheet> {
  final _totpController = TextEditingController();
  final _newPinController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _totpController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final pin = _newPinController.text.trim();
    final result = await ref.read(securityRepositoryProvider).configureAppPin(
          enabled: true,
          pin: pin,
          totpCode: _totpController.text.trim(),
        );
    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = ErrorTranslator.translate(context.tr, failure.toString());
        });
      },
      (_) {
        _persistPinConfiguredHint(
          ref,
          configured: true,
          pinLength: pin.length,
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: monochromePanelDecoration(
          color: monoSurfaceColor,
          borderColor: monoBorderStrongColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 1,
              width: 48,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              color: monoBorderStrongColor,
            ),
            Text(
              context.tr.appEntryResetTitle.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: monoMutedTextColor,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              context.tr.appEntryResetMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: monoMutedTextColor,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _totpController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: TextStyle(color: monoTextColor),
              decoration: monochromeInputDecoration(
                label: context.tr.appEntryTotpLabel,
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _newPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              style: TextStyle(color: monoTextColor),
              decoration: monochromeInputDecoration(
                label: context.tr.appEntryNewPinLabel,
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: AppSpacing.md),
              Text(
                _error!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: monoMutedTextColor,
                      letterSpacing: 0.8,
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: monochromeFilledButtonStyle(),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      child: TorLoadingDots(
                        dotSize: 6,
                        spacing: 8,
                        travel: 10,
                        color: Colors.black,
                      ),
                    )
                  : Text(context.tr.appEntrySavePin),
            ),
          ],
        ),
      ),
    );
  }
}
