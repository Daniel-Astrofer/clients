import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/core/services/sovereign_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePasskeyCryptographyService implements PasskeyCryptographyService {
  final Uint8List publicKey;
  Uint8List? credentialId;
  String? lastSubject;
  int counter = 0;

  _FakePasskeyCryptographyService({
    required this.publicKey,
  });

  @override
  Future<Uint8List> generateKeyPair({
    String? subject,
    Uint8List? credentialId,
  }) async {
    lastSubject = subject;
    this.credentialId = credentialId;
    return publicKey;
  }

  @override
  Future<Uint8List?> getCredentialId({String? subject}) async {
    lastSubject = subject;
    return credentialId;
  }

  @override
  Future<Uint8List?> getPublicKey({String? subject}) async {
    lastSubject = subject;
    return publicKey;
  }

  @override
  Future<bool> hasRegisteredKey({String? subject}) async {
    lastSubject = subject;
    return true;
  }

  @override
  Future<String> getDeviceName() async => 'Test Device';

  @override
  Future<int> nextSignatureCounter({String? subject}) async {
    lastSubject = subject;
    return counter + 1;
  }

  @override
  Future<void> commitSignatureCounter(int value, {String? subject}) async {
    lastSubject = subject;
    counter = value;
  }

  @override
  Future<void> clearSubjectMaterial({String? subject}) async {
    lastSubject = subject;
  }

  @override
  Future<Uint8List> signBytes(
    Uint8List data, {
    String? localizedReason,
    String? subject,
  }) async {
    lastSubject = subject;
    return Uint8List.fromList(List<int>.generate(64, (index) => index));
  }

  @override
  Future<String> signChallenge(String hexChallenge, {String? subject}) async {
    lastSubject = subject;
    return base64Encode(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  group('PasskeyService', () {
    test('blocks shaped enrollment under the tier-A device-key policy',
        () async {
      final publicKey = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final crypto = _FakePasskeyCryptographyService(publicKey: publicKey);
      final service = PasskeyService(cryptographyService: crypto);

      await expectLater(
        service.register(
          challengeHex: 'a' * 64,
          username: ' Alice ',
          appPinConfigured: true,
        ),
        throwsA(
          predicate<Object>(
            (error) => error
                .toString()
                .contains('ERR_AUTH_WEBAUTHN_SHAPED_ENROLL_DEPRECATED'),
          ),
        ),
      );
      expect(crypto.credentialId, isNull);
    });

    test('blocks shaped authentication under the tier-A device-key policy',
        () async {
      final publicKey = Uint8List.fromList(List<int>.filled(32, 7));
      final crypto = _FakePasskeyCryptographyService(publicKey: publicKey);
      final service = PasskeyService(cryptographyService: crypto);

      await expectLater(
        service.authenticate(
          challengeHex: 'c' * 64,
          username: 'kerosene',
        ),
        throwsA(
          predicate<Object>(
            (error) => error
                .toString()
                .contains('ERR_AUTH_DEVICE_KEY_RECONFIGURE_REQUIRED'),
          ),
        ),
      );
      expect(crypto.lastSubject, isNull);
    });

    test('commits authentication counters and strips local fields', () async {
      final publicKey = Uint8List.fromList(List<int>.filled(32, 7));
      final crypto = _FakePasskeyCryptographyService(publicKey: publicKey);
      final service = PasskeyService(cryptographyService: crypto);

      await service.commitAuthenticationCounter({
        '_signatureCounter': 7,
        '_subject': 'alice',
      });

      final payload = PasskeyService.toWirePayload({
        'credentialId': 'credential',
        '_signatureCounter': 7,
        '_subject': 'alice',
      });

      expect(crypto.counter, 7);
      expect(payload, {'credentialId': 'credential'});
    });
  });
}
