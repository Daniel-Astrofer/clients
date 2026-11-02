/// User-provided inputs required to request an emergency recovery session.
class EmergencyRecoveryStartDraft {
  /// Account name identifying the user who is recovering access.
  final String username;

  /// New passphrase to install after recovery is successfully completed.
  final String newPassphrase;

  /// Recovery codes presented as proof of account recovery authority.
  final List<String> recoveryCodes;

  /// Creates the immutable request draft before it is submitted to Auth.
  const EmergencyRecoveryStartDraft({
    required this.username,
    required this.newPassphrase,
    required this.recoveryCodes,
  });
}

/// Challenge and session details returned when emergency recovery begins.
class EmergencyRecoveryStartResult {
  /// Server-issued identifier used to continue this recovery attempt.
  final String recoverySessionId;

  /// TOTP enrollment URI that the user can scan in an authenticator app.
  final String otpUri;

  /// Passkey challenge that must be signed to prove possession.
  final String passkeyChallenge;

  /// Remaining session lifetime supplied by the server, in seconds.
  final int expiresInSeconds;

  /// Number of recovery codes the server requires for completion.
  final int requiredRecoveryCodes;

  /// Capability advertised by the server; older replies remain compatible.
  final bool deviceKeyRecoverySupported;

  /// Creates the challenge state returned by the recovery-start endpoint.
  const EmergencyRecoveryStartResult({
    required this.recoverySessionId,
    required this.otpUri,
    required this.passkeyChallenge,
    required this.expiresInSeconds,
    required this.requiredRecoveryCodes,
    this.deviceKeyRecoverySupported = false,
  });

  /// Parses the recovery-start response, defaulting absent scalar values safely.
  factory EmergencyRecoveryStartResult.fromJson(Map<String, dynamic> json) {
    return EmergencyRecoveryStartResult(
      recoverySessionId: _stringFrom(json['recoverySessionId']),
      otpUri: _stringFrom(json['otpUri']),
      passkeyChallenge: _stringFrom(json['passkeyChallenge']),
      expiresInSeconds: _intFrom(json['expiresInSeconds']),
      requiredRecoveryCodes: _intFrom(json['requiredRecoveryCodes']),
      deviceKeyRecoverySupported: json['deviceKeyRecoverySupported'] == true,
    );
  }

  /// Rejects incomplete/expired sessions and malformed enrollment material.
  bool get isUsable {
    final uri = Uri.tryParse(otpUri);
    final secrets = uri?.queryParametersAll['secret'];
    return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(recoverySessionId) &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(passkeyChallenge) &&
        expiresInSeconds > 0 &&
        requiredRecoveryCodes >= 3 &&
        requiredRecoveryCodes <= 10 &&
        uri?.scheme == 'otpauth' &&
        uri?.host == 'totp' &&
        uri!.path.length > 1 &&
        secrets != null &&
        secrets.length == 1 &&
        RegExp(r'^[A-Z2-7]+=*$').hasMatch(secrets.single);
  }
}

/// Account identity and replacement backup codes returned after recovery.
class EmergencyRecoveryFinishResult {
  /// Username whose recovery flow has completed.
  final String username;

  /// Newly issued backup codes that replace the consumed recovery codes.
  final List<String> newBackupCodes;

  /// Exact canonical credential acknowledged by the server, when applicable.
  final String? deviceKeyCredentialId;

  /// Local activation may fail after server success; preserve the one-time codes.
  final bool localDeviceKeyReady;

  /// Creates the successful recovery result.
  const EmergencyRecoveryFinishResult({
    required this.username,
    required this.newBackupCodes,
    this.deviceKeyCredentialId,
    this.localDeviceKeyReady = true,
  });

  /// Parses without dropping malformed entries, which would disguise a bad result.
  factory EmergencyRecoveryFinishResult.fromJson(Map<String, dynamic> json) {
    return EmergencyRecoveryFinishResult(
      username: _stringFrom(json['username']),
      newBackupCodes: _stringList(json['newBackupCodes']),
      deviceKeyCredentialId: json['deviceKeyCredentialId'] is String
          ? _stringFrom(json['deviceKeyCredentialId'])
          : null,
    );
  }

  /// The current server returns ten distinct, eight-digit replacement codes.
  bool get isUsable =>
      username.trim().isNotEmpty &&
      newBackupCodes.length == 10 &&
      newBackupCodes.toSet().length == newBackupCodes.length &&
      newBackupCodes.every((code) => RegExp(r'^\d{8}$').hasMatch(code));
}

/// Parses a JSON numeric value as an integer, returning zero when invalid.
int _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Parses a JSON list into trimmed nonempty strings, or an empty list otherwise.
List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map(_stringFrom).toList(growable: false);
  }
  return const <String>[];
}

String _stringFrom(Object? value) => value is String ? value.trim() : '';
