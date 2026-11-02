import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('recovery cannot sign on a platform without user-presence support',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefix = keroseneSecurePrefix();
    FlutterSecureStorage.setMockInitialValues({
      '${prefix}device_key_active_credential.YWxpY2U': 'test-key',
      '${prefix}device_key_seed.YWxpY2U.test-key':
          base64.encode(List<int>.generate(32, (i) => i)),
    });
    await expectLater(
        DeviceKeyService().authenticate(
          challenge: const DeviceKeyChallenge(
              challengeId: 'test',
              challenge: 'nonce',
              expiresInSeconds: 90,
              onionServiceId: 'test-service',
              algorithm: 'Ed25519',
              canonicalization: 'KEROSENE_JSON_V1'),
          username: 'alice',
          requireStrictUserPresence: true,
        ),
        throwsA(isA<DeviceKeyException>().having((e) => e.code, 'code',
            'ERR_AUTH_DEVICE_KEY_NO_LOCAL_CREDENTIALS')));
  }, skip: !Platform.isLinux);
}
