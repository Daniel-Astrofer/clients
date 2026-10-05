import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/financial_payment_challenge.dart';
import 'package:kerosene/core/services/device_key_service.dart';

Map<String, dynamic> _vector() => jsonDecode(File(
      '../contracts/test-vectors/financial-payment-approval-v1.json',
    ).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('matches shared canonical payload and real Ed25519 vector', () async {
    final vector = _vector();
    final challenge = FinancialPaymentChallenge.fromJson(
      Map<String, dynamic>.from(vector['challenge'] as Map),
    );
    final payload = DeviceKeyService().canonicalJsonForTesting(
      challenge.signedPayloadValues(
        credentialId: vector['credentialId'] as String,
        deviceInstallId: vector['deviceInstallId'] as String,
        counter: vector['counter'] as int,
        signedAtEpochSeconds: vector['issuedAtEpochSeconds'] as int,
      ),
    );
    expect(payload, vector['signedPayload']);
    expect(challenge.bindingHash, vector['bindingHash']);
    expect(
        await Ed25519().verify(
          utf8.encode(payload),
          signature: Signature(
            base64Url
                .decode(base64Url.normalize(vector['signature'] as String)),
            publicKey: SimplePublicKey(
              base64Url
                  .decode(base64Url.normalize(vector['publicKey'] as String)),
              type: KeyPairType.ed25519,
            ),
          ),
        ),
        isTrue);
  });

  final invalidFields = <String, Object?>{
    'version': 2,
    'purpose': 'AUTH_DEVICE_KEY',
    'challengeId': '',
    'challenge': 'A' * 64,
    'bindingHash': 'b' * 63,
    'username': 12,
    'onionServiceId': String.fromCharCode(0xd800),
    'issuedAtEpochSeconds': 1800000000.0,
    'expiresAtEpochSeconds': 1800000121,
    'algorithm': 'ES256',
    'canonicalization': null,
  };
  for (final entry in invalidFields.entries) {
    test('rejects invalid ${entry.key} without coercion', () {
      final json = Map<String, dynamic>.from(_vector()['challenge'] as Map);
      json[entry.key] = entry.value;
      expect(() => FinancialPaymentChallenge.fromJson(json),
          throwsFormatException);
    });
  }

  test('requires every field and rejects unknown fields', () {
    final original = Map<String, dynamic>.from(_vector()['challenge'] as Map);
    for (final key in original.keys) {
      final json = Map<String, dynamic>.from(original)..remove(key);
      expect(
          () => FinancialPaymentChallenge.fromJson(json), throwsFormatException,
          reason: key);
    }
    expect(() => FinancialPaymentChallenge.fromJson({...original, 'extra': 1}),
        throwsFormatException);
  });

  test('checks username and inclusive start/exclusive expiry', () {
    final challenge = FinancialPaymentChallenge.fromJson(
      Map<String, dynamic>.from(_vector()['challenge'] as Map),
    );
    DateTime time(int seconds) =>
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    expect(
        () => challenge.validateForSigning(
            username: ' ALICE ', now: time(1800000000)),
        returnsNormally);
    expect(
        () => challenge.validateForSigning(
            username: 'bob', now: time(1800000001)),
        throwsFormatException);
    for (final seconds in [1799999999, 1800000090]) {
      expect(
          () => challenge.validateForSigning(
              username: 'alice', now: time(seconds)),
          throwsFormatException);
    }
    expect(challenge.toString(), isNot(contains(challenge.bindingHash)));
    expect(challenge.toString(), isNot(contains(challenge.username)));
  });

  test('limits counter and rejects invalid credential Unicode', () {
    final challenge = FinancialPaymentChallenge.fromJson(
      Map<String, dynamic>.from(_vector()['challenge'] as Map),
    );
    for (final counter in [
      0,
      -1,
      FinancialPaymentChallenge.maxSafeInteger + 1
    ]) {
      expect(
          () => challenge.signedPayloadValues(
                credentialId: 'credential',
                deviceInstallId: 'install',
                counter: counter,
                signedAtEpochSeconds: 1800000001,
              ),
          throwsFormatException);
    }
    expect(
        () => challenge.signedPayloadValues(
              credentialId: String.fromCharCode(0xdfff),
              deviceInstallId: 'install',
              counter: 1,
              signedAtEpochSeconds: 1800000001,
            ),
        throwsFormatException);
  });
}
