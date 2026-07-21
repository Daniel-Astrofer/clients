import 'passkey_inventory.dart';

/// Typed challenge for one step-up factor (DEVICE_KEY or PASSKEY).
class DeviceCredentialChallenge {
  final String kind;
  final String? challengeId;
  final String challenge;
  final int? expiresInSeconds;
  final String? onionServiceId;
  final String? algorithm;
  final String? canonicalization;

  const DeviceCredentialChallenge({
    required this.kind,
    this.challengeId,
    required this.challenge,
    this.expiresInSeconds,
    this.onionServiceId,
    this.algorithm,
    this.canonicalization,
  });

  bool get isDeviceKey => kind.toUpperCase() == 'DEVICE_KEY';
  bool get isPasskey => kind.toUpperCase() == 'PASSKEY';

  bool get isComplete {
    if (challenge.isEmpty) return false;
    if (isDeviceKey) {
      return challengeId != null && challengeId!.isNotEmpty;
    }
    return true;
  }

  factory DeviceCredentialChallenge.fromJson(
    Map<String, dynamic> json, {
    String? fallbackKind,
  }) {
    final kind = (json['kind'] ?? fallbackKind ?? '').toString();
    return DeviceCredentialChallenge(
      kind: kind,
      challengeId:
          json['challengeId']?.toString() ?? json['challenge_id']?.toString(),
      challenge: (json['challenge'] ?? '').toString(),
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ??
          (json['expires_in_seconds'] as num?)?.toInt(),
      onionServiceId: json['onionServiceId']?.toString() ??
          json['onion_service_id']?.toString(),
      algorithm: json['algorithm']?.toString(),
      canonicalization: json['canonicalization']?.toString(),
    );
  }
}

class PasskeyActionRequired {
  final String action;
  final String reason;
  final String? challenge;
  final bool totpFallbackAvailable;
  final bool linkNewPasskeyAllowed;
  final String linkPasskeyPath;
  final String guidance;
  final PasskeyInventory? passkeys;
  final List<String> acceptedFactors;
  final Map<String, DeviceCredentialChallenge> challenges;
  final String? preferredFactor;

  const PasskeyActionRequired({
    required this.action,
    required this.reason,
    this.challenge,
    this.totpFallbackAvailable = false,
    this.linkNewPasskeyAllowed = false,
    this.linkPasskeyPath = '',
    this.guidance = '',
    this.passkeys,
    this.acceptedFactors = const [],
    this.challenges = const {},
    this.preferredFactor,
  });

  factory PasskeyActionRequired.fromJson(Map<String, dynamic> json) {
    final challenges = <String, DeviceCredentialChallenge>{};
    final rawChallenges = json['challenges'];
    if (rawChallenges is Map) {
      rawChallenges.forEach((key, value) {
        if (value is Map) {
          final kind = key.toString();
          challenges[kind.toUpperCase()] = DeviceCredentialChallenge.fromJson(
            Map<String, dynamic>.from(value),
            fallbackKind: kind,
          );
        }
      });
    }

    final accepted = <String>[];
    final rawAccepted = json['acceptedFactors'] ?? json['accepted_factors'];
    if (rawAccepted is Iterable) {
      for (final item in rawAccepted) {
        final factor = item.toString().trim().toUpperCase();
        if (factor.isNotEmpty) {
          accepted.add(factor);
        }
      }
    }

    return PasskeyActionRequired(
      action: (json['action'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      challenge: json['challenge']?.toString(),
      totpFallbackAvailable: json['totpFallbackAvailable'] == true ||
          json['totp_fallback_available'] == true,
      linkNewPasskeyAllowed: json['linkNewPasskeyAllowed'] == true ||
          json['link_new_passkey_allowed'] == true,
      linkPasskeyPath:
          (json['linkPasskeyPath'] ?? json['link_passkey_path'] ?? '')
              .toString(),
      guidance: (json['guidance'] ?? '').toString(),
      passkeys: json['passkeys'] is Map
          ? PasskeyInventory.fromJson(
              Map<String, dynamic>.from(json['passkeys'] as Map),
            )
          : null,
      acceptedFactors: accepted,
      challenges: challenges,
      preferredFactor: json['preferredFactor']?.toString() ??
          json['preferred_factor']?.toString(),
    );
  }

  static PasskeyActionRequired? fromDynamic(Object? data) {
    if (data is Map<String, dynamic>) {
      return PasskeyActionRequired.fromJson(data);
    }
    if (data is Map) {
      return PasskeyActionRequired.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Walks common error envelopes (`data`, nested maps) for this DTO.
  static PasskeyActionRequired? fromErrorPayload(Object? data) {
    final direct = fromDynamic(data);
    if (direct != null && direct.hasUsableStepUp) {
      return direct;
    }
    if (data is Map) {
      final nested = fromErrorPayload(data['data']);
      if (nested != null) {
        return nested;
      }
    }
    return direct;
  }

  DeviceCredentialChallenge? challengeFor(String kind) {
    final normalized = kind.trim().toUpperCase();
    return challenges[normalized];
  }

  bool get requiresLinking =>
      action == 'LINK_NEW_PASSKEY' || action == 'LINK_PASSKEY';

  bool get canRetryAssertion {
    if (action == 'ASSERT_PASSKEY' || action == 'ASSERT_DEVICE_CREDENTIAL') {
      return hasUsableStepUp;
    }
    return hasUsableStepUp;
  }

  bool get hasUsableStepUp {
    if (challenges.values.any((c) => c.isComplete)) {
      return true;
    }
    return challenge != null && challenge!.trim().isNotEmpty;
  }

  /// Prefer typed PASSKEY challenge; fall back to legacy single field.
  String? get legacyOrPasskeyChallenge {
    final typed = challengeFor('PASSKEY');
    if (typed != null && typed.challenge.isNotEmpty) {
      return typed.challenge;
    }
    final legacy = challenge?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    return null;
  }
}
