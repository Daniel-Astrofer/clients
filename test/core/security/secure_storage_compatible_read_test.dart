import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
  test(
      'strict compatible read migrates legacy data before deleting its old copy',
      () async {
    final calls = <String>[];
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel,
        (call) async {
      calls.add(call.method);
      if (call.method == 'read') return ++reads == 1 ? null : '["legacy-id"]';
      return null;
    });
    expect(
        await SecureStorageService()
            .readCompatibleStrict(key: 'archive-fixture'),
        '["legacy-id"]');
    expect(calls, ['read', 'read', 'write', 'delete']);
  });
  test('read failure is not reported as missing data', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel, (_) async => throw PlatformException(code: 'locked'));
    await expectLater(
        SecureStorageService().readCompatibleStrict(key: 'archive-fixture'),
        throwsA(isA<PlatformException>()));
  });
  test('failed migration keeps legacy data and reports the failure', () async {
    final calls = <String>[];
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel,
        (call) async {
      calls.add(call.method);
      if (call.method == 'read') return ++reads == 1 ? null : '["legacy-id"]';
      if (call.method == 'write') throw PlatformException(code: 'unavailable');
      return null;
    });
    await expectLater(
        SecureStorageService().readCompatibleStrict(key: 'archive-fixture'),
        throwsA(isA<PlatformException>()));
    expect(calls, ['read', 'read', 'write']);
  });
}
