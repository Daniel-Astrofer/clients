import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/presentation/widgets/tor_loading_dots.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/monochrome_theme.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'pin_entry_scaffold.dart';

/// App entry PIN.
///
/// Exact product flow:
/// 1. Kerosene K loading (~3s) — outside this widget
/// 2. PIN pad — user types fully (no network, no Tor wait)
/// 3. After complete PIN → loading dots, PIN held in memory
/// 4. Wait Tor up on dots
/// 5. Send verify request
/// 6. Unlock → child (HomeLoading)
class AppEntryPinGate extends ConsumerWidget {
  final Widget child;

  const AppEntryPinGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(appEntryPinUnlockedProvider);
    if (unlocked) {
      return child;
    }

    // Synchronous local status only — never AsyncLoading / Tor wait here.
    final status = ref.watch(appPinGateStatusProvider);

    if (status.requiresSetup) {
      return _AppEntryPinSetupScreen(
        key: const ValueKey('app-entry-pin-setup'),
        status: status,
      );
    }
    if (!status.requiresVerification) {
      return child;
    }
    return _AppEntryPinLockScreen(
      key: const ValueKey('app-entry-pin-lock'),
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
    extends ConsumerState<_AppEntryPinSetupScreen> {
  bool _busy = false;
  bool _confirming = false;
  String _pin = '';
  String _confirmation = '';
  String? _error;

  int get _pinLength => widget.status.minPinLength.clamp(4, 8);

  String get _currentInput => _confirming ? _confirmation : _pin;

  set _currentInput(String value) {
    if (_confirming) {
      _confirmation = value;
    } else {
      _pin = value;
    }
  }

  void _appendDigit(String digit) {
    if (_busy || _currentInput.length >= _pinLength) return;
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

    final torReady =
        await ref.read(appColdStartProvider.notifier).waitUntilTorReadyForApi();
    if (!mounted) return;
    if (!torReady) {
      setState(() {
        _busy = false;
        _error = _torStillWarmingMessage(context);
      });
      return;
    }

    final result = await ref.read(securityRepositoryProvider).configureAppPin(
          enabled: true,
          pin: pinToConfigure,
        );

    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _busy = false;
          _error = ErrorTranslator.translate(context.tr, failure.message);
        });
      },
      (status) {
        _persistPinConfiguredHint(
          ref,
          configured: status.configured && status.enabled,
          pinLength: pinToConfigure.length,
        );
        ref.read(appEntryPinUnlockedProvider.notifier).unlock();
      },
    );

    if (mounted && !ref.read(appEntryPinUnlockedProvider)) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinEntryScaffold(
      instruction: _confirming
          ? _appEntryPinConfirmInstruction(context)
          : _appEntryPinCreateInstruction(context),
      valueLength: _currentInput.length,
      maxLength: _pinLength,
      error: _error,
      busy: _busy,
      onDigit: _appendDigit,
      onDelete: _deleteDigit,
      onConfirm: _busy ? null : _submit,
      onCancel: () async {
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

class _AppEntryPinLockScreenState extends ConsumerState<_AppEntryPinLockScreen> {
  final ValueNotifier<String> _pinNotifier = ValueNotifier('');
  final ValueNotifier<String?> _errorNotifier = ValueNotifier(null);

  String get _pin => _pinNotifier.value;
  set _pin(String val) => _pinNotifier.value = val;
  String? get _errorMessage => _errorNotifier.value;
  set _errorMessage(String? val) => _errorNotifier.value = val;

  bool _busy = false;
  /// Captured at first frame — never changes mid-entry (no provider watch).
  late final int _pinTargetLength =
      widget.status.minPinLength.clamp(4, 8);

  @override
  void dispose() {
    _pinNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    if (_busy || _pin.length >= _pinTargetLength) return;
    HapticFeedback.selectionClick();
    _pin += digit;
    _errorMessage = null;
    if (_pin.length == _pinTargetLength) {
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
    if (_busy || widget.status.locked) return;
    if (_pin.length != _pinTargetLength) {
      _errorMessage = context.tr.appEntryPinLengthError(
        _pinTargetLength,
        _pinTargetLength,
      );
      return;
    }

    // 1) Freeze digits. 2) Dots only after full PIN. 3) Wait Tor. 4) Request.
    final pinToVerify = _pin;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final torReady =
        await ref.read(appColdStartProvider.notifier).waitUntilTorReadyForApi();
    if (!mounted) return;

    if (!torReady) {
      setState(() {
        _busy = false;
        _errorMessage = _torStillWarmingMessage(context);
      });
      return;
    }

    final result = await ref
        .read(securityRepositoryProvider)
        .verifyAppPin(pin: pinToVerify);
    if (!mounted) return;

    result.fold(
      (failure) {
        final msg = failure.message.toLowerCase();
        final code = failure.errorCode ?? '';

        if (_isTorNotReadyFailure(code, msg)) {
          // Stay on dots and retry once more — do not flash pad mid-flow.
          unawaited(_retryVerifyAfterTor(pinToVerify));
          return;
        }

        _applyVerifyFailure(failure);
        setState(() => _busy = false);
      },
      (status) {
        _applyVerifySuccess(status, pinLength: pinToVerify.length);
      },
    );

    if (mounted && !ref.read(appEntryPinUnlockedProvider) && !_busy) {
      setState(() => _busy = false);
    }
  }

  Future<void> _retryVerifyAfterTor(String pinToVerify) async {
    final ready = await ref
        .read(appColdStartProvider.notifier)
        .waitUntilTorReadyForApi(timeout: const Duration(seconds: 30));
    if (!mounted) return;

    if (!ready) {
      setState(() {
        _busy = false;
        _errorMessage = _torStillWarmingMessage(context);
      });
      return;
    }

    final retry = await ref
        .read(securityRepositoryProvider)
        .verifyAppPin(pin: pinToVerify);
    if (!mounted) return;

    retry.fold(
      (failure) {
        _applyVerifyFailure(failure);
        setState(() => _busy = false);
      },
      (status) {
        _applyVerifySuccess(status, pinLength: pinToVerify.length);
      },
    );
  }

  void _applyVerifySuccess(AppPinStatus status, {required int pinLength}) {
    _persistPinConfiguredHint(
      ref,
      configured: status.configured && status.enabled,
      pinLength: pinLength,
    );
    _pin = '';
    ref.read(appEntryPinUnlockedProvider.notifier).unlock();
  }

  void _applyVerifyFailure(dynamic failure) {
    final code = failure.errorCode?.toString() ?? '';
    final msg = failure.message.toString().toLowerCase();
    final isWrongPin = code == 'AUTH_019' ||
        code == 'ERR_AUTH_APP_PIN_INVALID' ||
        msg.contains('pin numerico incorreto') ||
        msg.contains('pin incorreto') ||
        msg.contains('pin atual incorreto');
    final isLocked =
        code == 'AUTH_020' || code == 'ERR_AUTH_APP_PIN_LOCKED';

    final base = isLocked
        ? context.tr.appEntryLockedHelper
        : isWrongPin
            ? 'PIN incorreto. Tente novamente.'
            : ErrorTranslator.translate(
                context.tr,
                failure.errorCode ?? failure.message,
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
          instruction: widget.status.locked
              ? context.tr.appEntryLockedHelper
              : _appEntryPinUnlockInstruction(context),
          valueLength: _pin.length,
          maxLength: _pinTargetLength,
          error: _errorMessage,
          busy: _busy,
          enabled: !widget.status.locked && !_busy,
          onDigit: _appendDigit,
          onDelete: _deleteDigit,
          onConfirm: widget.status.locked || _busy ? null : _submit,
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

bool _isTorNotReadyFailure(String code, String messageLower) {
  if (code == 'ERR_NETWORK' || code == 'NETWORK') return true;
  return messageLower.contains('tor ainda não está pronta') ||
      messageLower.contains('tor ainda nao esta pronta') ||
      messageLower.contains('rede tor') ||
      messageLower.contains('tempo de conexão esgotado') ||
      messageLower.contains('connection') ||
      messageLower.contains('socket') ||
      messageLower.contains('network');
}

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
          _error = ErrorTranslator.translate(context.tr, failure.message);
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
            const SizedBox(height: AppSpacing.sm),
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
              style: const TextStyle(color: monoTextColor),
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
              style: const TextStyle(color: monoTextColor),
              decoration: monochromeInputDecoration(
                label: context.tr.appEntryNewPinLabel,
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
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
