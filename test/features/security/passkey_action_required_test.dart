import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/security/domain/entities/passkey_action_required.dart';

void main() {
  group('PasskeyActionRequired typed 428', () {
    test('parses acceptedFactors, challenges and preferredFactor', () {
      final action = PasskeyActionRequired.fromJson({
        'action': 'ASSERT_PASSKEY',
        'reason': 'step-up',
        'challenge': 'abc123hex',
        'totpFallbackAvailable': false,
        'linkNewPasskeyAllowed': false,
        'linkPasskeyPath': '/settings/security/passkeys',
        'guidance': 'sign',
        'acceptedFactors': ['DEVICE_KEY', 'PASSKEY'],
        'preferredFactor': 'DEVICE_KEY',
        'challenges': {
          'DEVICE_KEY': {
            'kind': 'DEVICE_KEY',
            'challengeId': 'uuid-1',
            'challenge': 'dk-challenge',
            'expiresInSeconds': 90,
            'onionServiceId': 'onion',
            'algorithm': 'Ed25519',
            'canonicalization': 'KEROSENE_JSON_V1',
          },
          'PASSKEY': {
            'kind': 'PASSKEY',
            'challenge': 'abc123hex',
            'expiresInSeconds': 90,
          },
        },
      });

      expect(action.preferredFactor, 'DEVICE_KEY');
      expect(action.acceptedFactors, ['DEVICE_KEY', 'PASSKEY']);
      expect(action.challengeFor('DEVICE_KEY')?.challengeId, 'uuid-1');
      expect(action.challengeFor('DEVICE_KEY')?.isComplete, isTrue);
      expect(action.legacyOrPasskeyChallenge, 'abc123hex');
      expect(action.canRetryAssertion, isTrue);
    });

    test('legacy payload without challenges still works', () {
      final action = PasskeyActionRequired.fromJson({
        'action': 'ASSERT_PASSKEY',
        'reason': 'step-up',
        'challenge': 'deadbeef' * 8,
        'guidance': 'sign',
      });

      expect(action.challenges, isEmpty);
      expect(action.legacyOrPasskeyChallenge, 'deadbeef' * 8);
      expect(action.hasUsableStepUp, isTrue);
    });

    test('fromErrorPayload walks nested data envelope', () {
      final action = PasskeyActionRequired.fromErrorPayload({
        'success': false,
        'data': {
          'action': 'ASSERT_PASSKEY',
          'reason': 'nested',
          'challenge': 'nestedhex',
          'acceptedFactors': ['PASSKEY'],
          'preferredFactor': 'PASSKEY',
          'challenges': {
            'PASSKEY': {
              'challenge': 'nestedhex',
            },
          },
        },
      });

      expect(action, isNotNull);
      expect(action!.legacyOrPasskeyChallenge, 'nestedhex');
      expect(action.preferredFactor, 'PASSKEY');
    });
  });
}
