/// Outcome of [AuthController.registerPasskey] while the user is already logged in.
///
/// The mobile shell only keeps `/home` when auth state is [AuthAuthenticated].
/// Passkey registration must not replace that with [AuthLoading]/[AuthError], or
/// the user is bounced to welcome and the confirm-unlink retry cannot proceed.
class PasskeyRegisterResult {
  final PasskeyRegisterStatus status;
  final String message;
  final String? errorCode;
  final Object? data;

  const PasskeyRegisterResult._({
    required this.status,
    required this.message,
    this.errorCode,
    this.data,
  });

  const PasskeyRegisterResult.success()
      : this._(
          status: PasskeyRegisterStatus.success,
          message: 'Passkey registered.',
        );

  const PasskeyRegisterResult.deviceConflict({
    required String message,
    String? errorCode,
    Object? data,
  }) : this._(
          status: PasskeyRegisterStatus.deviceConflict,
          message: message,
          errorCode: errorCode,
          data: data,
        );

  const PasskeyRegisterResult.failure({
    required String message,
    String? errorCode,
    Object? data,
  }) : this._(
          status: PasskeyRegisterStatus.failure,
          message: message,
          errorCode: errorCode,
          data: data,
        );

  const PasskeyRegisterResult.notAuthenticated([
    String message = 'Você precisa estar logado para registrar uma passkey',
  ]) : this._(
          status: PasskeyRegisterStatus.notAuthenticated,
          message: message,
        );

  bool get isSuccess => status == PasskeyRegisterStatus.success;

  bool get isDeviceConflict => status == PasskeyRegisterStatus.deviceConflict;

  bool get isFailure =>
      status == PasskeyRegisterStatus.failure ||
      status == PasskeyRegisterStatus.notAuthenticated;
}

enum PasskeyRegisterStatus {
  success,
  deviceConflict,
  failure,
  notAuthenticated,
}
