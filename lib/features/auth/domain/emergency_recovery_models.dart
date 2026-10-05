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

  /// Creates the challenge state returned by the recovery-start endpoint.
  const EmergencyRecoveryStartResult({
    required this.recoverySessionId,
    required this.otpUri,
    required this.passkeyChallenge,
    required this.expiresInSeconds,
    required this.requiredRecoveryCodes,
  });

  /// Parses the recovery-start response, defaulting absent scalar values safely.
  factory EmergencyRecoveryStartResult.fromJson(Map<String, dynamic> json) {
    return EmergencyRecoveryStartResult(
      recoverySessionId: json['recoverySessionId']?.toString() ?? '',
      otpUri: json['otpUri']?.toString() ?? '',
      passkeyChallenge: json['passkeyChallenge']?.toString() ?? '',
      expiresInSeconds: _intFrom(json['expiresInSeconds']),
      requiredRecoveryCodes: _intFrom(json['requiredRecoveryCodes']),
    );
  }

  /// Whether all challenge artifacts needed to continue are present.
  bool get isUsable =>
      recoverySessionId.isNotEmpty &&
      otpUri.isNotEmpty &&
      passkeyChallenge.isNotEmpty;
}

/// Account identity and replacement backup codes returned after recovery.
class EmergencyRecoveryFinishResult {
  /// Username whose recovery flow has completed.
  final String username;

  /// Newly issued backup codes that replace the consumed recovery codes.
  final List<String> newBackupCodes;

  /// Creates the successful recovery result.
  const EmergencyRecoveryFinishResult({
    required this.username,
    required this.newBackupCodes,
  });

  /// Parses the recovery-finish response and filters invalid code entries.
  factory EmergencyRecoveryFinishResult.fromJson(Map<String, dynamic> json) {
    return EmergencyRecoveryFinishResult(
      username: json['username']?.toString() ?? '',
      newBackupCodes: _stringList(json['newBackupCodes']),
    );
  }
}

/// Parses a JSON numeric value as an integer, returning zero when invalid.
int _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Parses a JSON list into trimmed nonempty strings, or an empty list otherwise.
List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
