// architecture-allow-large-file: auth state transitions and compatibility
// adapters remain co-located to preserve DI and session contracts.
import 'dart:async';
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/signup_usecase.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/entities/user.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';
import '../../../core/providers/background_alerts_runtime_provider.dart';
import '../../../core/services/device_key_service.dart';
import '../../../core/services/passkey_service.dart';
import '../../../core/security/device_credential_enroll_policy.dart';
import '../../../core/errors/failures.dart';
import '../presentation/state/auth_state.dart';
import '../presentation/state/passkey_register_result.dart';
import 'auth_providers.dart';

export '../presentation/state/auth_state.dart';
export '../presentation/state/passkey_register_result.dart';

/// @nodoc
/// Role: AI-Native Controller for Authentication feature.
/// Responsibility: Orchestrates the state of authentication using the original logic but with Notifier (v3).
class AuthController extends Notifier<AuthState> {
  late LoginUseCase loginUseCase;
  late SignupUseCase signupUseCase;
  late AuthRepository authRepository;
  final PasskeyService passkeyService = PasskeyService.instance;
  DeviceKeyService get deviceKeyService => DeviceKeyService.instance;
  Timer? _onboardingPollTimer;
  bool _isPollingOnboarding = false;
  bool _isCompletingOnboarding = false;
  AuthAuthenticated? _credentialEnrollmentOwner;
  Future<PasskeyRegisterResult>? _credentialEnrollment;
  static const int _maxTransparentChallengeRenewals = 2;
  static final RegExp _passkeyErrorCodePattern = RegExp(
    r'(ERR_AUTH_PASSKEY_NO_LOCAL_CREDENTIALS|ERR_AUTH_PASSKEY_AUTH_CANCELLED|ERR_AUTH_PASSKEY_NOT_REGISTERED|ERR_AUTH_PASSKEY_CORRUPTED_KEY_MATERIAL)',
  );
  static final RegExp _hexChallengePattern = RegExp(r'^[0-9a-fA-F]{64}$');

  AuthError _mapFailureToAuthError(Failure failure) {
    return AuthError(
      failure.message,
      statusCode: failure.statusCode,
      errorCode: failure.errorCode,
      data: failure.data,
    );
  }

  AuthError _mapPasskeyExceptionToAuthError(
    Object error, {
    required String fallbackMessage,
  }) {
    final raw = error.toString().trim();
    final knownCode = _passkeyErrorCodePattern.firstMatch(raw);

    if (knownCode != null) {
      return AuthError(
        raw,
        errorCode: knownCode.group(1),
      );
    }

    return AuthError('$fallbackMessage: $raw');
  }

  bool _isPasskeyChallengeExpired(Failure failure) {
    final code = failure.errorCode ?? '';
    return code == 'CHALLENGE_EXPIRED' || code == 'AUTH_012';
  }

  @override
  AuthState build() {
    loginUseCase = ref.watch(loginUseCaseProvider);
    signupUseCase = ref.watch(signupUseCaseProvider);
    authRepository = ref.watch(authRepositoryProvider);
    ref.onDispose(_stopOnboardingPolling);

    // Stay on AuthLoading (K logo shell) until the first session probe finishes,
    // so cold start never flashes Welcome/PIN before the K loading.
    final initialProbe = AuthLoading();
    Future.microtask(() async {
      if (!ref.mounted || !identical(state, initialProbe)) return;
      await _checkAuthStatus(ownerOperation: initialProbe);
    });
    return initialProbe;
  }

  void _stopOnboardingPolling() {
    _onboardingPollTimer?.cancel();
    _onboardingPollTimer = null;
    _isPollingOnboarding = false;
  }

  Future<void> _syncBackgroundAlertsService() async {
    if (!ref.mounted) return;
    final current = state;
    if (current is AuthAuthenticated) {
      await ref
          .read(backgroundAlertsRuntimeProvider.notifier)
          .activateFor(current.user.id);
    }
  }

  Future<bool> _prepareBackgroundSession(AuthLoading operation) async {
    await ref.read(backgroundAlertsRuntimeProvider.notifier).deactivate();
    if (!ref.mounted || !identical(state, operation)) return false;
    if (ref.read(backgroundAlertsRuntimeProvider).phase ==
        BackgroundAlertsPhase.failedStop) {
      state = const AuthError('ERR_BACKGROUND_SESSION_STOP',
          errorCode: 'ERR_BACKGROUND_SESSION_STOP');
      return false;
    }
    return true;
  }

  void _startOnboardingPolling({
    required String linkId,
    String? username,
    String? password,
  }) {
    _stopOnboardingPolling();
    _onboardingPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_pollOnboardingPaymentStatus(
        linkId: linkId,
        username: username,
        password: password,
      ));
    });
  }

  void _completeOnboardingAndLogin({
    String? username,
    String? password,
  }) {
    if (_isCompletingOnboarding) {
      return;
    }

    _isCompletingOnboarding = true;
    _stopOnboardingPolling();
    unawaited(
      continueAfterOnboardingPayment(
        username: username,
        password: password,
      ).whenComplete(() {
        _isCompletingOnboarding = false;
      }),
    );
  }

  String _statusMessageForPaymentStatus(String status) {
    switch (status) {
      case 'VERIFYING_ACTIVATION':
      case 'verifying_activation':
        return 'Depósito localizado. Agora faltam confirmações na rede para liberar o recebimento.';
      case 'completed':
        return 'Depósito confirmado. Sua conta agora pode receber fundos.';
      case 'expired':
        return 'O endereço de depósito expirou. Gere um novo depósito para continuar.';
      default:
        return 'Para receber fundos dentro da plataforma, deposite algum valor primeiro.';
    }
  }

  Future<void> _pollOnboardingPaymentStatus({
    required String linkId,
    String? username,
    String? password,
  }) async {
    if (_isPollingOnboarding) {
      return;
    }

    final currentState = state;
    if (currentState is! AuthPaymentRequired ||
        currentState.paymentLinkId != linkId) {
      _stopOnboardingPolling();
      return;
    }

    try {
      _isPollingOnboarding = true;
      final result = await authRepository.getActivationStatus();

      result.fold(
        (failure) {
          final latestState = state;
          if (latestState is AuthPaymentRequired &&
              latestState.paymentLinkId == linkId) {
            state = latestState.copyWith(
              isSubmitting: false,
              errorMessage: failure.message,
            );
          }
        },
        (status) {
          final latestState = state;
          if (latestState is! AuthPaymentRequired ||
              latestState.paymentLinkId != linkId) {
            _stopOnboardingPolling();
            return;
          }

          state = latestState.copyWith(
            amountBtc:
                status.amountBtc > 0 ? status.amountBtc : latestState.amountBtc,
            depositAddress: status.depositAddress.isNotEmpty
                ? status.depositAddress
                : latestState.depositAddress,
            paymentStatus: status.paymentStatus.isNotEmpty
                ? status.paymentStatus
                : latestState.paymentStatus,
            statusMessage: status.warningMessage.isNotEmpty
                ? status.warningMessage
                : _statusMessageForPaymentStatus(status.paymentStatus),
            isSubmitting: false,
            clearError: true,
          );

          if (status.activated) {
            _completeOnboardingAndLogin(
              username: username,
              password: password,
            );
          } else if (status.paymentStatus == 'expired') {
            _stopOnboardingPolling();
          }
        },
      );
    } catch (error) {
      final latestState = state;
      if (latestState is AuthPaymentRequired &&
          latestState.paymentLinkId == linkId) {
        state = latestState.copyWith(
          isSubmitting: false,
          errorMessage: 'Erro inesperado: $error',
        );
      }
    } finally {
      _isPollingOnboarding = false;
    }
  }

  Future<void> _checkAuthStatus({
    bool forceRemote = false,
    bool probeWhenUnauthenticated = false,
    AuthLoading? ownerOperation,
    String? pendingSignupUsername,
  }) async {
    try {
      final isAuth = await authRepository.isAuthenticated();
      if (!ref.mounted ||
          (ownerOperation != null &&
              !_ownsOnboardingOperation(ownerOperation))) {
        return;
      }
      if (isAuth) {
        final result = await authRepository.getCurrentUser(
          forceRemote: forceRemote,
        );
        if (ownerOperation != null &&
            !_ownsOnboardingOperation(ownerOperation)) {
          return;
        }
        await result.fold<Future<void>>(
          (failure) async {
            if (pendingSignupUsername != null) {
              state = AuthOnboardingOutcomeUnknown(pendingSignupUsername);
            } else if (failure is AuthFailure) {
              // Token actually expired or invalid
              state = const AuthUnauthenticated();
            } else {
              // Server is down or no network, preserve session visually and show unavailable
              state = AuthServerUnavailable(failure.message);
            }
          },
          (user) async {
            if (pendingSignupUsername != null &&
                user.username != pendingSignupUsername) {
              await authRepository.clearInvalidSession();
              if (ownerOperation != null &&
                  !_ownsOnboardingOperation(ownerOperation)) {
                return;
              }
              state = AuthOnboardingOutcomeUnknown(pendingSignupUsername);
              return;
            }
            state = AuthAuthenticated(user);
            unawaited(_syncBackgroundAlertsService());
          },
        );
      } else {
        if (probeWhenUnauthenticated) {
          final result = await authRepository.checkServerAvailability();
          if (ownerOperation != null &&
              !_ownsOnboardingOperation(ownerOperation)) {
            return;
          }
          result.fold(
            (failure) => state = AuthServerUnavailable(failure.message),
            (_) => state = const AuthUnauthenticated(),
          );
          return;
        }
        state = pendingSignupUsername != null
            ? AuthOnboardingOutcomeUnknown(pendingSignupUsername)
            : const AuthUnauthenticated();
      }
    } catch (e) {
      if (!ref.mounted ||
          (ownerOperation != null &&
              !_ownsOnboardingOperation(ownerOperation))) {
        return;
      }
      state = pendingSignupUsername != null
          ? AuthOnboardingOutcomeUnknown(pendingSignupUsername)
          : AuthServerUnavailable(e.toString());
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (state is AuthLoading) return;
    _stopOnboardingPolling();
    final operation = AuthLoading();
    try {
      state = operation;
      if (!await _prepareBackgroundSession(operation)) return;
      final result = await loginUseCase(
        LoginParams(username: username, passphrase: password),
      );

      if (!ref.mounted || !identical(state, operation)) return;

      await result.fold<Future<void>>(
        (failure) async {
          await authRepository.clearInvalidSession();
          if (!ref.mounted || !identical(state, operation)) return;
          state = _mapFailureToAuthError(failure);
        },
        (loginResult) async {
          if (loginResult.requiresTotp) {
            state = AuthRequiresLoginTotp(
              username: username,
              passphrase: password,
              preAuthToken: loginResult.jwt,
            );
          } else {
            await loginWithPasskey(username);
          }
        },
      );
    } catch (e) {
      if (ref.mounted && identical(state, operation)) {
        state = AuthError('Erro inesperado: $e');
      }
    }
  }

  Future<void> signup({
    required String username,
    required String password,
    String accountSecurity = 'STANDARD',
    int? shamirTotalShares,
    int? shamirThreshold,
    int? multisigThreshold,
  }) async {
    if (state is AuthLoading) return;
    final operation = AuthLoading();
    try {
      state = operation;
      if (!await _prepareBackgroundSession(operation)) return;
      final result = await signupUseCase(
        SignupParams(
          username: username,
          passphrase: password,
          accountSecurity: accountSecurity,
          shamirTotalShares: shamirTotalShares,
          shamirThreshold: shamirThreshold,
          multisigThreshold: multisigThreshold,
        ),
      );

      if (!ref.mounted || !identical(state, operation)) return;
      result.fold(
        (failure) {
          state = _mapFailureToAuthError(failure);
        },
        (signupResult) => state = AuthRequiresTotpSetup(
          username: username,
          passphrase: password,
          sessionId: signupResult.sessionId,
          totpSecret: signupResult.totpSecret,
          qrCodeUri: signupResult.qrCodeUri,
          backupCodes: signupResult.backupCodes,
          totpOptional: signupResult.totpOptional,
        ),
      );
    } catch (e) {
      if (ref.mounted && identical(state, operation)) {
        state = const AuthError('Não foi possível iniciar o cadastro agora.');
      }
    }
  }

  AuthState _resumableState() =>
      state is AuthError ? (state as AuthError).resumeState ?? state : state;

  Future<void> verifyTotp({
    required String username,
    required String passphrase,
    required String totpSecret,
    required String totpCode,
  }) async {
    if (state is AuthLoading) return;
    final currentState = _resumableState();
    if (currentState is! AuthRequiresTotpSetup ||
        currentState.username != username) {
      state = const AuthError(
          'Sessão de cadastro inválida. Reinicie a criação da conta.');
      return;
    }
    final operation = AuthLoading();
    state = operation;
    try {
      final result = await authRepository.verifyTotp(
          sessionId: currentState.sessionId, totpCode: totpCode);
      if (!ref.mounted || !identical(state, operation)) return;
      result.fold((failure) {
        final expired =
            failure.errorCode == 'AUTH_011' || failure.statusCode == 408;
        final canRetry = !expired &&
            (failure.errorCode == 'AUTH_008' ||
                failure is NetworkFailure ||
                failure.statusCode == 429 ||
                (failure.statusCode != null && failure.statusCode! >= 500) ||
                (failure.statusCode == null && failure is! AuthFailure));
        state = AuthError(failure.message,
            statusCode: failure.statusCode,
            errorCode: failure.errorCode,
            data: failure.data,
            resumeState: canRetry ? currentState : null);
      }, (sessionId) {
        if (sessionId != currentState.sessionId) {
          state = const AuthError('Resposta de cadastro inválida.',
              errorCode: 'ERR_SIGNUP_SESSION_MISMATCH');
        } else {
          state = AuthTotpVerified(sessionId, username);
        }
      });
    } catch (_) {
      if (ref.mounted && identical(state, operation)) {
        state = AuthError('Não foi possível verificar o código agora.',
            errorCode: 'ERR_NETWORK', resumeState: currentState);
      }
    }
  }

  Future<void> skipTotpSetup() async {
    if (state is AuthLoading) return;
    final currentState = _resumableState();
    if (currentState is! AuthRequiresTotpSetup) {
      state = const AuthError(
          'Sessão de cadastro inválida. Reinicie a criação da conta.');
      return;
    }
    if (!currentState.totpOptional) {
      state = AuthError('TOTP é obrigatório para este perfil de segurança.',
          resumeState: currentState);
      return;
    }
    state = AuthTotpVerified(currentState.sessionId, currentState.username);
  }

  Future<void> verifyLoginTotp({
    required String username,
    required String passphrase,
    required String totpCode,
    String? preAuthToken,
  }) async {
    if (state is AuthLoading) return;
    final operation = AuthLoading();
    state = operation;
    if (!await _prepareBackgroundSession(operation)) return;
    final result = await authRepository.verifyLoginTotp(
      username: username,
      passphrase: passphrase,
      totpCode: totpCode,
      preAuthToken: preAuthToken,
    );

    if (!ref.mounted || !identical(state, operation)) return;

    await result.fold<Future<void>>(
      (failure) async => state = _mapFailureToAuthError(failure),
      (user) async {
        final deviceSessionEstablished = await authRepository.isAuthenticated();
        if (!ref.mounted || !identical(state, operation)) return;
        if (!deviceSessionEstablished) {
          await loginWithPasskey(username);
          return;
        }
        state = AuthAuthenticated(user);
        unawaited(_syncBackgroundAlertsService());
      },
    );
  }

  /// Compatibility entry point that only restores an already-final device session.
  /// Password and primary TOTP never persist a token for this check to restore.
  Future<void> establishSessionAfterPasswordLogin() async {
    state = const AuthLoading();
    await _checkAuthStatus(forceRemote: true);
    if (state is AuthAuthenticated) {
      unawaited(_syncBackgroundAlertsService());
    } else if (state is! AuthError && state is! AuthServerUnavailable) {
      // Token present but profile fetch failed — still treat as unauthenticated for UX.
      state = const AuthError(
        'Não conseguimos carregar sua sessão. Tente novamente.',
      );
    }
  }

  Future<void> logout() async {
    _stopOnboardingPolling();
    try {
      state = const AuthLoading();
      await ref.read(backgroundAlertsRuntimeProvider.notifier).deactivate();
      final result = await authRepository.logout();
      result.fold((failure) => state = _mapFailureToAuthError(failure),
          (_) => state = const AuthUnauthenticated());
    } catch (e) {
      state = AuthError('Erro ao sair: $e');
    }
  }

  void markSessionInvalidated() {
    _stopOnboardingPolling();
    state = const AuthUnauthenticated();
    unawaited(ref.read(backgroundAlertsRuntimeProvider.notifier).deactivate());
  }

  void clearError() {
    if (state is AuthError || state is AuthOnboardingOutcomeUnknown) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> retrySessionCheck() async {
    // Keep [AuthAuthenticated] while probing so the PIN unlock flag and home
    // shell are not torn down (AuthLoading used to re-ask the entry PIN).
    final keepAuthenticatedShell = state is AuthAuthenticated;
    if (!keepAuthenticatedShell) {
      state = const AuthLoading();
    }
    await _checkAuthStatus(
      forceRemote: true,
      probeWhenUnauthenticated: !keepAuthenticatedShell,
    );
  }

  Future<void> loginWithPasskey(
    String username, {
    int remainingChallengeRenewals = _maxTransparentChallengeRenewals,
  }) async {
    username = username.trim();
    if (username.isEmpty) {
      state = const AuthError(
          'Por favor, insira o usuário para entrar com a chave do dispositivo');
      return;
    }
    final operation = AuthLoading();
    state = operation;
    bool current() => ref.mounted && identical(state, operation);

    final hasDeviceKey =
        await DeviceKeyService.instance.hasRegisteredDeviceKey(username);
    if (!current()) return;
    if (hasDeviceKey) {
      await _loginWithDeviceKey(username, operation);
      return;
    }

    final allowLegacy =
        await DeviceCredentialEnrollPolicy.allowWebAuthnShapedAuth();
    if (!current()) return;
    if (!allowLegacy) {
      state = const AuthError(
        DeviceCredentialEnrollPolicy.reconfigureRequiredMessage,
        errorCode: DeviceCredentialEnrollPolicy.reconfigureRequiredCode,
      );
      return;
    }

    final startResult = await authRepository.passkeyLoginStart(username);
    if (!current()) return;
    await startResult.fold(
      (failure) async {
        if (current()) state = _mapFailureToAuthError(failure);
      },
      (challengeHex) async {
        try {
          final credential = await passkeyService.authenticate(
            challengeHex: challengeHex,
            username: username,
          );
          if (!current()) return;
          final finishResult = await authRepository.passkeyLoginFinish(
            username: username,
            credential: PasskeyService.toWirePayload(credential),
          );
          if (!current()) return;
          await finishResult.fold(
            (failure) async {
              final renewedChallenge = _extractPasskeyChallenge(failure);
              if (renewedChallenge == null) {
                if (_isPasskeyChallengeExpired(failure) &&
                    remainingChallengeRenewals > 0) {
                  await loginWithPasskey(
                    username,
                    remainingChallengeRenewals: remainingChallengeRenewals - 1,
                  );
                  return;
                }
                if (current()) state = _mapFailureToAuthError(failure);
                return;
              }
              final renewedCredential = await passkeyService.authenticate(
                challengeHex: renewedChallenge,
                username: username,
              );
              if (!current()) return;
              final renewedFinish = await authRepository.passkeyLoginFinish(
                username: username,
                credential: PasskeyService.toWirePayload(renewedCredential),
              );
              if (!current()) return;
              await renewedFinish.fold(
                (secondFailure) async {
                  if (_isPasskeyChallengeExpired(secondFailure) &&
                      remainingChallengeRenewals > 0) {
                    await loginWithPasskey(
                      username,
                      remainingChallengeRenewals:
                          remainingChallengeRenewals - 1,
                    );
                    return;
                  }
                  if (current()) state = _mapFailureToAuthError(secondFailure);
                },
                (loginResult) async {
                  await passkeyService
                      .commitAuthenticationCounter(renewedCredential);
                  if (current()) {
                    _completePasskeyLogin(username, loginResult, operation);
                  }
                },
              );
            },
            (loginResult) async {
              await passkeyService.commitAuthenticationCounter(credential);
              if (current()) {
                _completePasskeyLogin(username, loginResult, operation);
              }
            },
          );
        } catch (e) {
          if (current()) {
            state = _mapPasskeyExceptionToAuthError(
              e,
              fallbackMessage: 'Erro na autenticação via passkey',
            );
          }
        }
      },
    );
  }

  void _completePasskeyLogin(
      String username, LoginResult loginResult, AuthLoading operation) {
    if (!ref.mounted || !identical(state, operation)) return;
    if (loginResult.requiresTotp) {
      state = AuthRequiresLoginTotp(
        username: username,
        passphrase: '',
        preAuthToken: loginResult.jwt,
      );
    } else {
      unawaited(_checkAuthStatus(ownerOperation: operation));
    }
  }

  String? _extractPasskeyChallenge(Failure failure) {
    final challenge = _extractChallengeFromValue(failure.data);
    if (challenge != null) {
      return challenge;
    }

    const marker = 'PASSKEY_CHALLENGE_REQUIRED:';
    final markerIndex = failure.message.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    final value = failure.message.substring(markerIndex + marker.length).trim();
    return _hexChallengePattern.hasMatch(value) ? value : null;
  }

  String? _extractChallengeFromValue(Object? value) {
    if (value is Map) {
      final direct = value['challenge']?.toString().trim();
      if (direct != null && _hexChallengePattern.hasMatch(direct)) {
        return direct;
      }
      return _extractChallengeFromValue(value['data']);
    }
    return null;
  }

  /// Registers a passkey for the **currently authenticated** session.
  ///
  /// Must not transition global auth to [AuthLoading]/[AuthError]: the mobile
  /// shell only keeps the home/settings tree when state is [AuthAuthenticated].
  /// Device-binding conflicts (AUTH_024) are returned as
  /// [PasskeyRegisterResult.deviceConflict] so settings can confirm unlink and
  /// retry while the session stays alive.
  Future<void> _loginWithDeviceKey(
      String username, AuthLoading operation) async {
    bool current() => ref.mounted && identical(state, operation);
    final startResult = await authRepository.deviceKeyLoginStart(username);
    if (!current()) return;
    await startResult.fold(
      (failure) async {
        if (current()) state = _mapFailureToAuthError(failure);
      },
      (challengeJson) async {
        try {
          final challenge = DeviceKeyChallenge.fromJson(challengeJson);
          final assertion = await DeviceKeyService.instance.authenticate(
            challenge: challenge,
            username: username,
          );
          if (!current()) return;
          final finishResult =
              await authRepository.deviceKeyLoginFinish(assertion);
          if (!current()) return;
          await finishResult.fold(
            (failure) async {
              if (current()) state = _mapFailureToAuthError(failure);
            },
            (loginResult) async {
              _completePasskeyLogin(username, loginResult, operation);
            },
          );
        } catch (e) {
          if (current()) {
            state = _mapPasskeyExceptionToAuthError(
              e,
              fallbackMessage:
                  'Erro na autenticação com a chave do dispositivo',
            );
          }
        }
      },
    );
  }

  Future<PasskeyRegisterResult> registerPasskey({
    bool confirmUnlinkDevice = false,
  }) {
    final owner = state;
    if (owner is! AuthAuthenticated) {
      return Future.value(const PasskeyRegisterResult.notAuthenticated());
    }
    final pending = _credentialEnrollment;
    if (pending != null) {
      return identical(_credentialEnrollmentOwner, owner)
          ? pending
          : Future.value(const PasskeyRegisterResult.failure(
              errorCode: 'ERR_AUTH_DEVICE_KEY_REGISTRATION_BUSY',
              message:
                  'Existe uma vinculação em andamento neste aparelho. Aguarde sua conclusão.'));
    }
    _credentialEnrollmentOwner = owner;
    final operation = _registerAuthenticatedCredential(owner,
        confirmUnlinkDevice: confirmUnlinkDevice);
    _credentialEnrollment = operation;
    operation.then<void>((_) {
      if (identical(_credentialEnrollment, operation)) {
        _credentialEnrollment = null;
        _credentialEnrollmentOwner = null;
      }
    });
    return operation;
  }

  bool _ownsCredentialEnrollment(AuthAuthenticated owner) =>
      ref.mounted && identical(state, owner);

  Future<PasskeyRegisterResult> _registerAuthenticatedCredential(
      AuthAuthenticated owner,
      {required bool confirmUnlinkDevice}) async {
    final username = owner.user.username;
    try {
      final canonical =
          await DeviceCredentialEnrollPolicy.preferCanonicalDeviceKeyEnroll();
      if (!_ownsCredentialEnrollment(owner)) {
        return const PasskeyRegisterResult.notAuthenticated();
      }
      if (canonical) {
        return await _registerDeviceKeyAuthenticated(
            username: username,
            owner: owner,
            confirmUnlinkDevice: confirmUnlinkDevice);
      }
      final start = await authRepository.passkeyRegisterStart(username);
      if (!_ownsCredentialEnrollment(owner)) {
        return const PasskeyRegisterResult.notAuthenticated();
      }
      final failure = start.fold((f) => f, (_) => null);
      if (failure != null) {
        return PasskeyRegisterResult.failure(
            message: failure.message,
            errorCode: failure.errorCode,
            data: failure.data);
      }
      final challenge = start.fold((_) => '', (value) => value);
      final credential = await passkeyService.register(
          challengeHex: challenge,
          username: username,
          confirmUnlinkDevice: confirmUnlinkDevice);
      if (!_ownsCredentialEnrollment(owner)) {
        return const PasskeyRegisterResult.notAuthenticated();
      }
      final finish = await authRepository.passkeyRegisterFinish(credential);
      if (!_ownsCredentialEnrollment(owner)) {
        return const PasskeyRegisterResult.notAuthenticated();
      }
      final finishFailure = finish.fold((f) => f, (_) => null);
      if (finishFailure != null) {
        return _credentialEnrollmentFailure(finishFailure);
      }
      if (confirmUnlinkDevice) {
        await passkeyService.prepareDeviceRebind(newUsername: username);
        if (!_ownsCredentialEnrollment(owner)) {
          return const PasskeyRegisterResult.notAuthenticated();
        }
      }
      return await _finishAuthenticatedCredential(owner);
    } catch (error) {
      if (!_ownsCredentialEnrollment(owner)) {
        return const PasskeyRegisterResult.notAuthenticated();
      }
      final mapped = _mapPasskeyExceptionToAuthError(error,
          fallbackMessage:
              'Não foi possível confirmar o registro da chave deste aparelho');
      return PasskeyRegisterResult.failure(
          message: mapped.message,
          errorCode: error is DeviceKeyException
              ? error.code
              : mapped.errorCode ??
                  RegExp(r'ERR_AUTH_DEVICE_KEY_[A-Z_]+')
                      .firstMatch(error.toString())
                      ?.group(0),
          data: mapped.data);
    }
  }

  PasskeyRegisterResult _credentialEnrollmentFailure(Failure failure) =>
      _isDeviceBindingConflict(failure)
          ? PasskeyRegisterResult.deviceConflict(
              message: failure.message,
              errorCode: failure.errorCode,
              data: failure.data)
          : PasskeyRegisterResult.failure(
              message: failure.message,
              errorCode: failure.errorCode,
              data: failure.data);

  Future<PasskeyRegisterResult> _finishAuthenticatedCredential(
      AuthAuthenticated owner) async {
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    await passkeyService.markDeviceBound(username: owner.user.username);
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    final refreshed = await authRepository.getCurrentUser(forceRemote: true);
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    final user = refreshed.fold<User?>((_) => null, (value) => value);
    if (user != null) {
      final id = owner.user.id.trim();
      final sameAccount = id.isNotEmpty && id != '0'
          ? user.id.trim() == id
          : user.username.trim().toLowerCase() ==
              owner.user.username.trim().toLowerCase();
      if (!sameAccount) return const PasskeyRegisterResult.notAuthenticated();
      state = AuthAuthenticated(user);
    }
    // The binding was acknowledged. A profile lookup failure leaves the same
    // authenticated session intact; it must never resurrect a previous one.
    return const PasskeyRegisterResult.success();
  }

  bool _isDeviceBindingConflict(Failure failure) {
    final code = (failure.errorCode ?? '').toUpperCase();
    if (code == 'AUTH_024' ||
        code == 'ERR_AUTH_DEVICE_ALREADY_BOUND' ||
        code.endsWith('AUTH_DEVICE_ALREADY_BOUND')) {
      return true;
    }
    final data = failure.data;
    if (data is Map && data['action']?.toString() == 'CONFIRM_UNLINK_DEVICE') {
      return true;
    }
    return false;
  }

  Future<PasskeyRegisterResult> _registerDeviceKeyAuthenticated({
    required String username,
    required AuthAuthenticated owner,
    bool confirmUnlinkDevice = false,
  }) async {
    final start = await authRepository.deviceKeyRegisterStart();
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    final failure = start.fold((f) => f, (_) => null);
    if (failure != null) return _credentialEnrollmentFailure(failure);
    final challenge = DeviceKeyChallenge.fromJson(
        start.fold((_) => const <String, dynamic>{}, (value) => value));
    final credential = await deviceKeyService.register(
        challenge: challenge,
        username: username,
        sessionId: '',
        activateImmediately: false);
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    final credentialId = credential['credentialId'];
    if (credentialId is! String || credentialId.trim().isEmpty) {
      throw StateError('Prepared credential identifier unavailable');
    }
    if (confirmUnlinkDevice) {
      credential['confirmUnlinkDevice'] = true;
      credential['confirm_unlink_device'] = true;
    }
    final finish = await authRepository.deviceKeyRegisterFinish(credential);
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    final finishFailure = finish.fold((f) => f, (_) => null);
    if (finishFailure != null) {
      return _credentialEnrollmentFailure(finishFailure);
    }
    await deviceKeyService.activateRegistration(
        username: username, credentialId: credentialId);
    if (!_ownsCredentialEnrollment(owner)) {
      return const PasskeyRegisterResult.notAuthenticated();
    }
    return _finishAuthenticatedCredential(owner);
  }

  bool _ownsOnboardingOperation(AuthLoading operation) =>
      ref.mounted && identical(state, operation);

  AuthError _onboardingEnrollmentError(
      AuthError error, AuthTotpVerified context) {
    final expired = error.errorCode == 'AUTH_013' ||
        error.errorCode == 'AUTH_011' ||
        error.statusCode == 408;
    return AuthError(error.message,
        statusCode: error.statusCode,
        errorCode: error.errorCode,
        data: error.data,
        resumeState: expired ? null : context);
  }

  Future<void> _completeOnboardingEnrollment({
    required AuthTotpVerified context,
    required AuthLoading operation,
    required Future<Either<Failure, LoginResult>> completion,
  }) async {
    try {
      final result = await completion;
      if (!_ownsOnboardingOperation(operation)) return;
      await result.fold((failure) async {
        final expired =
            failure.errorCode == 'AUTH_013' || failure.errorCode == 'AUTH_011';
        final uncertain = !expired &&
            (failure is NetworkFailure ||
                failure.statusCode == 408 ||
                (failure.statusCode != null && failure.statusCode! >= 500) ||
                (failure.statusCode == null && failure is! AuthFailure));
        state = uncertain
            ? AuthOnboardingOutcomeUnknown(context.username)
            : _onboardingEnrollmentError(
                _mapFailureToAuthError(failure), context);
      }, (_) async {
        await passkeyService.markDeviceBound(username: context.username);
        if (!_ownsOnboardingOperation(operation)) return;
        await _checkAuthStatus(
          forceRemote: true,
          ownerOperation: operation,
          pendingSignupUsername: context.username,
        );
      });
    } catch (_) {
      if (_ownsOnboardingOperation(operation)) {
        state = AuthOnboardingOutcomeUnknown(context.username);
      }
    }
  }

  Future<void> registerPasskeyOnboarding(
    String sessionId, {
    bool confirmUnlinkDevice = false,
  }) async {
    if (state is AuthLoading || state is AuthOnboardingOutcomeUnknown) return;
    final currentState = _resumableState();
    if (currentState is! AuthTotpVerified ||
        currentState.sessionId != sessionId) {
      state = const AuthError(
          'Sessão de cadastro inválida. Reinicie a criação da conta.',
          errorCode: 'ERR_SIGNUP_SESSION_MISMATCH');
      return;
    }
    final operation = AuthLoading();
    state = operation;
    try {
      final canonical =
          await DeviceCredentialEnrollPolicy.preferCanonicalDeviceKeyEnroll();
      if (!_ownsOnboardingOperation(operation)) return;
      if (canonical) {
        await _registerDeviceKeyOnboarding(
            context: currentState,
            operation: operation,
            confirmUnlinkDevice: confirmUnlinkDevice);
        return;
      }

      // Retain the legacy path only where the existing runtime policy permits.
      final result = await authRepository.passkeyRegisterOnboardingStart(
          sessionId: sessionId, username: currentState.username);
      if (!_ownsOnboardingOperation(operation)) return;
      await result.fold((failure) async {
        state = _onboardingEnrollmentError(
            _mapFailureToAuthError(failure), currentState);
      }, (challengeHex) async {
        if (confirmUnlinkDevice) {
          await passkeyService.prepareDeviceRebind(
              newUsername: currentState.username);
          if (!_ownsOnboardingOperation(operation)) return;
        }
        final credential = await passkeyService.register(
            challengeHex: challengeHex,
            username: currentState.username,
            confirmUnlinkDevice: confirmUnlinkDevice);
        if (!_ownsOnboardingOperation(operation)) return;
        await _completeOnboardingEnrollment(
          context: currentState,
          operation: operation,
          completion: authRepository.passkeyRegisterOnboardingFinish(
              sessionId, credential),
        );
      });
    } catch (error) {
      if (_ownsOnboardingOperation(operation)) {
        final knownCode =
            _passkeyErrorCodePattern.firstMatch(error.toString())?.group(1);
        state = _onboardingEnrollmentError(
            error is DeviceKeyException
                ? AuthError(error.message, errorCode: error.code)
                : AuthError('Não foi possível vincular este dispositivo agora.',
                    errorCode: knownCode),
            currentState);
      }
    }
  }

  Future<void> _registerDeviceKeyOnboarding({
    required AuthTotpVerified context,
    required AuthLoading operation,
    bool confirmUnlinkDevice = false,
  }) async {
    final startResult = await authRepository.deviceKeyRegisterOnboardingStart(
        sessionId: context.sessionId, username: context.username);
    if (!_ownsOnboardingOperation(operation)) return;
    await startResult.fold((failure) async {
      state =
          _onboardingEnrollmentError(_mapFailureToAuthError(failure), context);
    }, (challengeJson) async {
      final challenge = DeviceKeyChallenge.fromJson(challengeJson);
      final credential = await deviceKeyService.register(
          challenge: challenge,
          username: context.username,
          sessionId: context.sessionId);
      if (!_ownsOnboardingOperation(operation)) return;
      if (confirmUnlinkDevice) {
        credential['confirmUnlinkDevice'] = true;
        credential['confirm_unlink_device'] = true;
      }
      await _completeOnboardingEnrollment(
        context: context,
        operation: operation,
        completion: authRepository.deviceKeyRegisterOnboardingFinish(
            context.sessionId, credential),
      );
    });
  }

  Future<void> _loadActivationDepositState({
    required String sessionId,
  }) async {
    final result = await authRepository.getActivationStatus();
    result.fold(
      (failure) => state = _mapFailureToAuthError(failure),
      (status) {
        state = AuthPaymentRequired(
          sessionId: sessionId,
          paymentLinkId: status.paymentLinkId,
          amountBtc: status.amountBtc,
          depositAddress: status.depositAddress,
          paymentStatus: status.paymentStatus.isNotEmpty
              ? status.paymentStatus
              : 'pending',
          statusMessage: status.warningMessage.isNotEmpty
              ? status.warningMessage
              : _statusMessageForPaymentStatus(status.paymentStatus),
        );

        if (status.paymentLinkId.isNotEmpty) {
          _startOnboardingPolling(linkId: status.paymentLinkId);
        }
      },
    );
  }

  Future<void> getOnboardingLink({
    required String sessionId,
    required String username,
    required String password,
  }) async {
    _stopOnboardingPolling();
    try {
      state = const AuthLoading();
      await _loadActivationDepositState(sessionId: sessionId);
    } catch (e) {
      state = AuthError('Erro inesperado: $e');
    }
  }

  Future<void> submitOnboardingPayment({
    required String linkId,
    required String txid,
    required String username,
    required String password,
  }) async {
    final currentState = state;
    if (currentState is! AuthPaymentRequired) {
      return;
    }

    try {
      state = currentState.copyWith(
        isSubmitting: true,
        statusMessage: 'Atualizando o status do depósito de ativação...',
        clearError: true,
      );

      final result = await authRepository.getActivationStatus();

      result.fold(
        (failure) {
          final latestState = state;
          if (latestState is AuthPaymentRequired) {
            state = latestState.copyWith(
              isSubmitting: false,
              errorMessage: failure.message,
            );
          } else {
            state = _mapFailureToAuthError(failure);
          }
        },
        (status) {
          final latestState = state;
          if (latestState is! AuthPaymentRequired) {
            return;
          }

          state = latestState.copyWith(
            paymentStatus: status.paymentStatus.isNotEmpty
                ? status.paymentStatus
                : latestState.paymentStatus,
            statusMessage: status.warningMessage.isNotEmpty
                ? status.warningMessage
                : _statusMessageForPaymentStatus(status.paymentStatus),
            isSubmitting: false,
            errorMessage: status.activated
                ? null
                : 'A confirmação manual por TXID foi descontinuada. Faça o depósito pelo fluxo de recebimento do app e aguarde o monitoramento automático.',
            clearError: status.activated,
          );

          if (status.activated) {
            _completeOnboardingAndLogin(
              username: username,
              password: password,
            );
            return;
          }

          if (status.paymentStatus == 'expired') {
            _stopOnboardingPolling();
            return;
          }

          _startOnboardingPolling(
            linkId: linkId,
            username: username,
            password: password,
          );
          unawaited(_pollOnboardingPaymentStatus(
            linkId: linkId,
            username: username,
            password: password,
          ));
        },
      );
    } catch (e) {
      if (state is AuthPaymentRequired) {
        state = (state as AuthPaymentRequired).copyWith(
          isSubmitting: false,
          errorMessage: 'Erro inesperado: $e',
        );
      } else {
        state = AuthError('Erro inesperado: $e');
      }
    }
  }

  Future<void> continueAfterOnboardingPayment({
    String? username,
    String? password,
  }) async {
    _stopOnboardingPolling();
    final result = await authRepository.getActivationStatus();
    result.fold(
      (failure) => state = _mapFailureToAuthError(failure),
      (status) {
        if (status.activated) {
          unawaited(_checkAuthStatus());
          return;
        }

        final currentState = state;
        if (currentState is AuthPaymentRequired) {
          state = currentState.copyWith(
            paymentStatus: status.paymentStatus,
            statusMessage: status.warningMessage.isNotEmpty
                ? status.warningMessage
                : _statusMessageForPaymentStatus(status.paymentStatus),
            amountBtc: status.amountBtc > 0
                ? status.amountBtc
                : currentState.amountBtc,
            depositAddress: status.depositAddress.isNotEmpty
                ? status.depositAddress
                : currentState.depositAddress,
            clearError: true,
          );
        }
      },
    );
  }
}

/// Provider to expose the controller to the UI.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final sessionStorageScopeProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is! AuthAuthenticated) {
    return null;
  }

  return sessionStorageScopeFromUser(
    userId: authState.user.id,
    username: authState.user.username,
  );
});

String? sessionStorageScopeFromUser({
  required String? userId,
  required String? username,
}) {
  // Prefer stable numeric user id so multi-user devices never collide on
  // display names. Username fallback only when id is truly unavailable.
  final normalizedUserId = userId?.trim();
  if (normalizedUserId != null &&
      normalizedUserId.isNotEmpty &&
      normalizedUserId != '0' &&
      RegExp(r'^\d+$').hasMatch(normalizedUserId)) {
    return _sanitizeSessionStorageScope('user_$normalizedUserId');
  }
  if (normalizedUserId != null &&
      normalizedUserId.isNotEmpty &&
      normalizedUserId != '0') {
    // Non-numeric id (UUID) still scopes uniquely.
    return _sanitizeSessionStorageScope('user_$normalizedUserId');
  }

  final normalizedUsername = username?.trim().toLowerCase();
  if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
    // Legacy fallback only — new logins should always carry a numeric user id.
    return _sanitizeSessionStorageScope('username_$normalizedUsername');
  }

  return null;
}

String _sanitizeSessionStorageScope(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
