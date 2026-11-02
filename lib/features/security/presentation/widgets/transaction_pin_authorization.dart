import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';

class TransactionDeviceAuthOutcome {
  final TransactionDeviceAuthStatus status;
  final String? appPin;

  const TransactionDeviceAuthOutcome(this.status, {this.appPin});

  static const authenticatedWithoutPin =
      TransactionDeviceAuthOutcome(TransactionDeviceAuthStatus.authenticated);
  static const unavailableOutcome =
      TransactionDeviceAuthOutcome(TransactionDeviceAuthStatus.unavailable);
  static const rejectedOutcome =
      TransactionDeviceAuthOutcome(TransactionDeviceAuthStatus.rejected);
}

enum TransactionDeviceAuthStatus { authenticated, unavailable, rejected }

// ---------------------------------------------------------------------------
// PIN Setup (called when no PIN is configured for this device yet)
// ---------------------------------------------------------------------------

class TransactionPinSetupScreen extends ConsumerStatefulWidget {
  final AppPinStatus status;

  const TransactionPinSetupScreen({super.key, required this.status});

  @override
  ConsumerState<TransactionPinSetupScreen> createState() =>
      TransactionPinSetupScreenState();
}

class TransactionPinSetupScreenState
    extends ConsumerState<TransactionPinSetupScreen> {
  bool _busy = false;
  bool _confirming = false;
  String _pin = '';
  String _confirmation = '';
  String? _error;

  late final String? _ownerScope;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider);
  }

  bool get _ownsSession =>
      mounted &&
      _ownerScope != null &&
      (ModalRoute.of(context)?.isActive ?? true) &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

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
    if (_busy || !_ownsSession || _currentInput.length >= _pinLength) return;
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
    if (_busy || !_ownsSession) return;
    final input = _currentInput;
    if (input.length != _pinLength) return;

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

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(securityRepositoryProvider).configureAppPin(
          enabled: true,
          pin: _pin,
        );

    if (!_ownsSession) return;

    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = ErrorTranslator.translate(context.tr, failure.toString());
        });
      },
      (_) {
        ref.invalidate(appPinStatusProvider);
        if (mounted) {
          _finish(
            TransactionDeviceAuthOutcome(
                TransactionDeviceAuthStatus.authenticated,
                appPin: _pin),
          );
        }
      },
    );

    if (mounted) setState(() => _busy = false);
  }

  void _finish(TransactionDeviceAuthOutcome outcome) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route?.isCurrent ?? true) {
      navigator.pop(outcome);
    } else if (route != null) {
      navigator.removeRoute(route, outcome);
    }
  }

  void _cancel() => _finish(TransactionDeviceAuthOutcome.rejectedOutcome);

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (_, next) {
      if (next != _ownerScope) {
        _pin = '';
        _confirmation = '';
        _cancel();
      }
    });
    return PinEntryScaffold(
      key: ValueKey(_confirming),
      instruction: _confirming
          ? transactionAuthLocaleSwitch(context,
              ptBr: 'Confirme o PIN para finalizar o cadastro.',
              en: 'Confirm your PIN to complete setup.',
              es: 'Confirma tu PIN para completar la configuración.')
          : transactionAuthLocaleSwitch(context,
              ptBr: 'Crie um PIN de $_pinLength dígitos para esta transação.',
              en: 'Create a $_pinLength-digit PIN for this transaction.',
              es: 'Crea un PIN de $_pinLength dígitos para esta transacción.'),
      valueLength: _currentInput.length,
      maxLength: _pinLength,
      error: _error,
      busy: _busy,
      busyLabel: context.tr.pinEntrySaving,
      enabled: _ownsSession && !_busy,
      onDigit: _appendDigit,
      onDelete: _deleteDigit,
      onConfirm: _busy ? null : _submit,
      onCancel: _busy ? null : _cancel,
    );
  }
}

String transactionAuthLocaleSwitch(BuildContext context,
    {required String ptBr, required String en, required String es}) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => en,
    'es' => es,
    _ => ptBr,
  };
}

// ---------------------------------------------------------------------------
// PIN Authorization (called when PIN is already configured)
// ---------------------------------------------------------------------------

class TransactionPinAuthorizationScreen extends ConsumerStatefulWidget {
  final AppPinStatus status;

  const TransactionPinAuthorizationScreen({super.key, required this.status});

  @override
  ConsumerState<TransactionPinAuthorizationScreen> createState() =>
      TransactionPinAuthorizationScreenState();
}

class TransactionPinAuthorizationScreenState
    extends ConsumerState<TransactionPinAuthorizationScreen> {
  bool _busy = false;
  String _pin = '';
  String? _error;

  late final String? _ownerScope;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(sessionStorageScopeProvider);
  }

  bool get _ownsSession =>
      mounted &&
      _ownerScope != null &&
      (ModalRoute.of(context)?.isActive ?? true) &&
      ref.read(sessionStorageScopeProvider) == _ownerScope;

  int get _minPinLength => widget.status.minPinLength.clamp(4, 8);
  int get _maxPinLength => widget.status.maxPinLength.clamp(_minPinLength, 8);
  bool get _fixedLength => _minPinLength == _maxPinLength;

  void _appendDigit(String digit) {
    if (_busy ||
        !_ownsSession ||
        widget.status.locked ||
        _pin.length >= _maxPinLength) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    // The API reports policy bounds, not the length of the stored PIN.
    // Submit automatically only when those bounds identify an exact length.
    if (_fixedLength && _pin.length == _maxPinLength) {
      unawaited(_submit());
    }
  }

  void _deleteDigit() {
    if (_busy || _pin.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || widget.status.locked || !_ownsSession) {
      return;
    }
    if (_pin.length < _minPinLength || _pin.length > _maxPinLength) {
      setState(() {
        _error =
            context.tr.appEntryPinLengthError(_minPinLength, _maxPinLength);
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result =
        await ref.read(securityRepositoryProvider).verifyAppPin(pin: _pin);

    if (!_ownsSession) return;

    result.fold(
      (failure) {
        if (!mounted) {
          return;
        }
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _pin = '';
          _error = ErrorTranslator.translate(context.tr, failure.toString());
        });
        ref.invalidate(appPinStatusProvider);
      },
      (_) {
        ref.invalidate(appPinStatusProvider);
        _finish(TransactionDeviceAuthOutcome(
            TransactionDeviceAuthStatus.authenticated,
            appPin: _pin));
      },
    );

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  void _finish(TransactionDeviceAuthOutcome outcome) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route?.isCurrent ?? true) {
      navigator.pop(outcome);
    } else if (route != null) {
      navigator.removeRoute(route, outcome);
    }
  }

  void _cancel() => _finish(TransactionDeviceAuthOutcome.rejectedOutcome);

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (_, next) {
      if (next != _ownerScope) {
        _pin = '';
        _cancel();
      }
    });
    return PinEntryScaffold(
      instruction: transactionPinInstruction(context),
      valueLength: _pin.length,
      maxLength: _maxPinLength,
      error: _error,
      busy: _busy,
      busyLabel: context.tr.pinEntryChecking,
      enabled: _ownsSession && !widget.status.locked && !_busy,
      onDigit: _appendDigit,
      onDelete: _deleteDigit,
      onConfirm: _busy || widget.status.locked ? null : _submit,
      onCancel: _busy ? null : _cancel,
    );
  }
}

String transactionPinInstruction(BuildContext context) =>
    context.tr.transactionPinInstruction;

String transactionPinCancel(BuildContext context) => context.tr.cancel;
