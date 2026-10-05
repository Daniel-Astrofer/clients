import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/financial_payment_challenge.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/test_vectors.dart';

final _seed = List<int>.generate(32, (i) => i); // Local test key only.
String get _prefix => keroseneSecurePrefix();
String get _activeKey => '${_prefix}device_key_active_credential.YWxpY2U';
String get _seedKey => '${_prefix}device_key_seed.YWxpY2U.credential-test';
String get _counterKey =>
    '${_prefix}device_key_counter.YWxpY2U.credential-test';

FinancialPaymentChallenge _challenge() {
  final vector = loadPaymentApprovalVector();
  return FinancialPaymentChallenge.fromJson(
    Map<String, dynamic>.from(vector['challenge'] as Map),
  );
}

DeviceKeyService _service({DateTime Function()? clock}) => DeviceKeyService(
      clock: clock ?? () => DateTime.fromMillisecondsSinceEpoch(1800000001000),
      deviceInstallId: () async => 'install-test',
    );

void _storage(
    {String counter = '6', bool withCredential = true, bool withSeed = true}) {
  FlutterSecureStorage.setMockInitialValues({
    if (withCredential) _activeKey: 'credential-test',
    if (withSeed) _seedKey: base64.encode(_seed),
    _counterKey: counter,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _storage();
  });

  test('produces real financial signature and persists counter before return',
      () async {
    final proof = await _service().authenticateFinancial(
      challenge: _challenge(),
      username: ' ALICE ',
    );
    expect(proof.keys.toSet(), {
      'version',
      'type',
      'credentialId',
      'deviceInstallId',
      'signedPayload',
      'signature',
    });
    expect(proof['type'], 'FINANCIAL_DEVICE_KEY');
    expect(proof['version'], 1);
    final vector = loadPaymentApprovalVector();
    expect(proof['signedPayload'], vector['signedPayload']);
    final keyPair = await Ed25519().newKeyPairFromSeed(_seed);
    expect(
        await Ed25519().verify(
          utf8.encode(proof['signedPayload'] as String),
          signature: Signature(
            base64Url.decode(base64Url.normalize(proof['signature'] as String)),
            publicKey: await keyPair.extractPublicKey(),
          ),
        ),
        isTrue);
    expect(proof['signature'], isNot(contains('=')));
    expect(await const FlutterSecureStorage().read(key: _counterKey), '7');
    final next = await _service().authenticateFinancial(
      challenge: _challenge(),
      username: 'alice',
    );
    expect(jsonDecode(next['signedPayload'] as String)['counter'], 8);
  });

  test('concurrent signing does not allocate the same local counter', () async {
    final service = _service();
    final proofs = await Future.wait(List.generate(
        2,
        (_) => service.authenticateFinancial(
            challenge: _challenge(), username: 'alice')));
    expect(
        proofs
            .map((p) => jsonDecode(p['signedPayload'] as String)['counter'])
            .toSet(),
        {7, 8});
  });

  test('missing credential cannot sign or silently enroll', () async {
    _storage(withCredential: false);
    await expectLater(
        _service().authenticateFinancial(
          challenge: _challenge(),
          username: 'alice',
        ),
        throwsA(isA<DeviceKeyException>().having(
            (e) => e.code, 'code', 'ERR_AUTH_DEVICE_KEY_NOT_REGISTERED')));
    expect(await const FlutterSecureStorage().read(key: _activeKey), isNull);
    expect(await const FlutterSecureStorage().read(key: _counterKey), '6');
  });

  test('missing seed cannot sign', () async {
    _storage(withSeed: false);
    await expectLater(
        _service().authenticateFinancial(
          challenge: _challenge(),
          username: 'alice',
        ),
        throwsA(isA<DeviceKeyException>()));
  });

  for (final counter in ['corrupt', '-1', '9007199254740991']) {
    test('rejects counter $counter without resetting it', () async {
      _storage(counter: counter);
      await expectLater(
          _service().authenticateFinancial(
            challenge: _challenge(),
            username: 'alice',
          ),
          throwsA(isA<DeviceKeyException>().having(
              (e) => e.code, 'code', 'ERR_AUTH_DEVICE_KEY_COUNTER_INVALID')));
      expect(
          await const FlutterSecureStorage().read(key: _counterKey), counter);
    });
  }

  test('wrong user and expiry fail before counter allocation', () async {
    await expectLater(
        _service().authenticateFinancial(
          challenge: _challenge(),
          username: 'bob',
        ),
        throwsA(isA<DeviceKeyException>()));
    await expectLater(
        _service(
                clock: () => DateTime.fromMillisecondsSinceEpoch(1800000090000))
            .authenticateFinancial(
          challenge: _challenge(),
          username: 'alice',
        ),
        throwsA(isA<DeviceKeyException>()));
    expect(await const FlutterSecureStorage().read(key: _counterKey), '6');
  });

  test('expiry during signing burns counter and never returns expired proof',
      () async {
    var reads = 0;
    final service = _service(
        clock: () => DateTime.fromMillisecondsSinceEpoch(
              (++reads < 3 ? 1800000001 : 1800000090) * 1000,
            ));
    await expectLater(
        service.authenticateFinancial(
          challenge: _challenge(),
          username: 'alice',
        ),
        throwsA(isA<DeviceKeyException>()));
    expect(await const FlutterSecureStorage().read(key: _counterKey), '7');
  });
}
