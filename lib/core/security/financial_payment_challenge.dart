/// Strict consumer of Contracts financial/payment-approval-v1.
/// A financial challenge is never a login/registration challenge.
class FinancialPaymentChallenge {
  static const purpose = 'KFE_PAYMENT_APPROVAL';
  static const action = 'ASSERT_FINANCIAL_DEVICE_KEY';
  static const errorCode = 'KFE_PAYMENT_APPROVAL_REQUIRED';
  static const maxSafeInteger = 9007199254740991;
  static const _fields = {
    'version',
    'purpose',
    'challengeId',
    'challenge',
    'bindingHash',
    'username',
    'onionServiceId',
    'issuedAtEpochSeconds',
    'expiresAtEpochSeconds',
    'algorithm',
    'canonicalization',
  };

  final String challengeId;
  final String challenge;
  final String bindingHash;
  final String username;
  final String onionServiceId;
  final int issuedAtEpochSeconds;
  final int expiresAtEpochSeconds;

  const FinancialPaymentChallenge._({
    required this.challengeId,
    required this.challenge,
    required this.bindingHash,
    required this.username,
    required this.onionServiceId,
    required this.issuedAtEpochSeconds,
    required this.expiresAtEpochSeconds,
  });

  factory FinancialPaymentChallenge.fromJson(Map<String, dynamic> json) {
    if (json.length != _fields.length ||
        !json.keys.every(_fields.contains) ||
        json['version'] is! int ||
        json['version'] != 1 ||
        json['purpose'] != purpose ||
        json['algorithm'] != 'Ed25519' ||
        json['canonicalization'] != 'KEROSENE_JSON_V1') {
      throw _invalid();
    }
    final issued = _integer(json['issuedAtEpochSeconds']);
    final expires = _integer(json['expiresAtEpochSeconds']);
    if (issued <= 0 || expires <= issued || expires - issued > 120) {
      throw _invalid();
    }
    final nonce = _string(json['challenge'], 64);
    final binding = _string(json['bindingHash'], 64);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(binding)) {
      throw _invalid();
    }
    return FinancialPaymentChallenge._(
      challengeId: _string(json['challengeId'], 128),
      challenge: nonce,
      bindingHash: binding,
      username: _string(json['username'], 255),
      onionServiceId: _string(json['onionServiceId'], 255),
      issuedAtEpochSeconds: issued,
      expiresAtEpochSeconds: expires,
    );
  }

  void validateForSigning({required String username, required DateTime now}) {
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    if (this.username != username.trim().toLowerCase() ||
        seconds < issuedAtEpochSeconds ||
        seconds >= expiresAtEpochSeconds) {
      throw _invalid();
    }
  }

  /// Fields are serialized with the existing KEROSENE_JSON_V1 canonicalizer.
  Map<String, Object> signedPayloadValues({
    required String credentialId,
    required String deviceInstallId,
    required int counter,
    required int signedAtEpochSeconds,
  }) {
    if (counter <= 0 ||
        counter > maxSafeInteger ||
        signedAtEpochSeconds < issuedAtEpochSeconds ||
        signedAtEpochSeconds >= expiresAtEpochSeconds) {
      throw _invalid();
    }
    return {
      'bindingHash': bindingHash,
      'challenge': challenge,
      'challengeId': challengeId,
      'counter': counter,
      'credentialId': _string(credentialId, 128),
      'deviceInstallId': _string(deviceInstallId, 128),
      'issuedAtEpochSeconds': signedAtEpochSeconds,
      'onionServiceId': onionServiceId,
      'type': purpose,
      'username': username,
      'version': 1,
    };
  }

  static int _integer(Object? value) {
    if (value is! int || value < 0 || value > maxSafeInteger) {
      throw _invalid();
    }
    return value;
  }

  static String _string(Object? value, int maxLength) {
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      throw _invalid();
    }
    // Dart's UTF-8 encoder replaces unpaired surrogates: reject before signing.
    final units = value.codeUnits;
    for (var i = 0; i < units.length; i++) {
      if (units[i] >= 0xd800 && units[i] <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          throw _invalid();
        }
      } else if (units[i] >= 0xdc00 && units[i] <= 0xdfff) {
        throw _invalid();
      }
    }
    return value;
  }

  static FormatException _invalid() => const FormatException(
        'Invalid financial payment challenge v1',
      );

  @override
  String toString() => 'FinancialPaymentChallenge[REDACTED]';
}
