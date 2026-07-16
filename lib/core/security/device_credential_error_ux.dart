import '../utils/error_translator.dart';
import '../utils/snackbar_helper.dart';
import 'device_credential_enroll_policy.dart';

/// User-facing classification for Device Credential step-up / auth failures.
enum DeviceCredentialErrorKind {
  /// Counter desync — safe to retry once or twice.
  replayConflict,

  /// Soft-lock after repeated REPLAY (AUTH_025) — wait / password+TOTP.
  replayLocked,

  /// N+2: no Device Key on this install — open devices settings.
  reconfigureRequired,

  /// Generic device credential failure.
  other,
}

class DeviceCredentialUserFacing {
  final DeviceCredentialErrorKind kind;
  final String title;
  final String message;
  final bool offerOpenDevicesSettings;

  const DeviceCredentialUserFacing({
    required this.kind,
    required this.title,
    required this.message,
    this.offerOpenDevicesSettings = false,
  });
}

/// Maps error codes / exception strings to calm, non-technical UX.
class DeviceCredentialErrorUx {
  const DeviceCredentialErrorUx._();

  static DeviceCredentialErrorKind classify(Object? error) {
    final blob = _blob(error);
    if (_matches(blob, const [
      'AUTH_025',
      'ERR_AUTH_DEVICE_CRED_REPLAY_LOCKED',
      'DEVICE_CREDENTIAL_LOCKED',
      'DEVICE_CREDENTIAL_REPLAY_LOCKED',
    ])) {
      return DeviceCredentialErrorKind.replayLocked;
    }
    if (_matches(blob, const [
      'AUTH_016',
      'ERR_AUTH_PASSKEY_REPLAY',
      'ERR_AUTH_DEVICE_CRED_REPLAY',
      'SECURITY_CONFLICT',
      'DEVICE_CREDENTIAL_REPLAY',
    ])) {
      return DeviceCredentialErrorKind.replayConflict;
    }
    if (_matches(blob, const [
      DeviceCredentialEnrollPolicy.reconfigureRequiredCode,
      'ERR_AUTH_WEBAUTHN_SHAPED_ENROLL_DEPRECATED',
      'ERR_AUTH_WEBAUTHN_SHAPED',
    ])) {
      return DeviceCredentialErrorKind.reconfigureRequired;
    }
    return DeviceCredentialErrorKind.other;
  }

  /// Prefer structured title/message over a single snackbar line.
  static DeviceCredentialUserFacing present(
    Object? error, {
    required dynamic l10n,
  }) {
    final kind = classify(error);
    final translated = ErrorTranslator.translate(l10n, error?.toString() ?? '');

    switch (kind) {
      case DeviceCredentialErrorKind.replayLocked:
        return DeviceCredentialUserFacing(
          kind: kind,
          title: 'Chave temporariamente bloqueada',
          message: translated.isNotEmpty
              ? translated
              : 'Possível conflito de segurança. Aguarde cerca de 20 minutos '
                  'ou entre com senha e TOTP, depois revise Dispositivos.',
        );
      case DeviceCredentialErrorKind.replayConflict:
        return DeviceCredentialUserFacing(
          kind: kind,
          title: 'Conflito de segurança',
          message: translated.isNotEmpty
              ? translated
              : 'O contador da chave não avançou. Tente de novo. '
                  'Não é necessário vincular outra chave neste passo.',
        );
      case DeviceCredentialErrorKind.reconfigureRequired:
        return DeviceCredentialUserFacing(
          kind: kind,
          title: 'Chave do dispositivo necessária',
          message: translated.isNotEmpty
              ? translated
              : DeviceCredentialEnrollPolicy.reconfigureRequiredMessage,
          offerOpenDevicesSettings: true,
        );
      case DeviceCredentialErrorKind.other:
        return DeviceCredentialUserFacing(
          kind: kind,
          title: 'Autorização',
          message: translated,
        );
    }
  }

  static String _blob(Object? error) {
    if (error == null) return '';
    if (error is String) return error;
    try {
      // AppException / Failure often expose errorCode.
      final dynamic d = error;
      final code = d.errorCode?.toString() ?? '';
      final message = d.message?.toString() ?? '';
      final data = d.data?.toString() ?? '';
      return '$code $message $data ${error.toString()}';
    } catch (_) {
      return error.toString();
    }
  }

  static bool _matches(String blob, List<String> needles) {
    final upper = blob.toUpperCase();
    for (final n in needles) {
      if (upper.contains(n.toUpperCase())) return true;
    }
    return false;
  }

  /// Shows a notice with kind-appropriate tone (lock = warning, reconfigure = info).
  static void showNotice(Object? error, {required dynamic l10n}) {
    final facing = present(error, l10n: l10n);
    switch (facing.kind) {
      case DeviceCredentialErrorKind.replayLocked:
        SnackbarHelper.showWarning(facing.message, title: facing.title);
      case DeviceCredentialErrorKind.reconfigureRequired:
        SnackbarHelper.showInfo(facing.message, title: facing.title);
      case DeviceCredentialErrorKind.replayConflict:
      case DeviceCredentialErrorKind.other:
        SnackbarHelper.showError(facing.message, title: facing.title);
    }
  }

  /// Use device-credential UX when the error looks related; otherwise plain error.
  static void showNoticeIfDeviceCredential(
    Object? error, {
    required dynamic l10n,
  }) {
    final kind = classify(error);
    if (kind == DeviceCredentialErrorKind.other) {
      SnackbarHelper.showError(
        ErrorTranslator.translate(l10n, error?.toString() ?? ''),
      );
      return;
    }
    showNotice(error, l10n: l10n);
  }
}
