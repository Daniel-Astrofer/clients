import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/services/background_service_status.dart';
import 'package:kerosene/core/services/background_network_bridge.dart';

String jwt(Map<String, Object?> claims) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';

void main() {
  final now = DateTime.utc(2026, 10, 27, 23);
  final seconds = now.millisecondsSinceEpoch ~/ 1000;

  test('background polling rejects expired, missing and malformed expiry', () {
    for (final exp in [null, seconds, seconds - 1, '$seconds', 1.5]) {
      expect(
          backgroundTokenMatchesUser(jwt({'sub': '17', 'exp': exp}), '17',
              now: now),
          isFalse);
    }
    expect(
        backgroundTokenMatchesUser(jwt({'sub': '17', 'exp': seconds + 1}), '17',
            now: now),
        isTrue);
  });

  test('background polling respects activation time and account ownership', () {
    expect(
        backgroundTokenMatchesUser(
            jwt({'sub': '17', 'exp': seconds + 60, 'nbf': seconds + 1}), '17',
            now: now),
        isFalse);
    expect(
        backgroundTokenMatchesUser(
            jwt({'sub': '17', 'exp': seconds + 60, 'nbf': seconds}), '17',
            now: now),
        isTrue);
    expect(
        backgroundTokenMatchesUser(
            jwt({'sub': '21', 'exp': seconds + 60}), '17',
            now: now),
        isFalse);
  });

  test('only rejection of the current credential suspends polling', () {
    expect(backgroundCredentialRejectionApplies(401, 'old', 'old'), isTrue);
    expect(
        backgroundCredentialRejectionApplies(401, 'old', 'renewed'), isFalse);
    expect(backgroundCredentialRejectionApplies(401, 'old', null), isFalse);
    expect(backgroundCredentialRejectionApplies(403, 'same', 'same'), isFalse);
    expect(backgroundCredentialRejectionApplies(503, 'same', 'same'), isFalse);
    expect(backgroundCredentialRejectionApplies(401, null, null), isFalse);
  });

  test('persisted rejection survives restart and permits a renewed token',
      () async {
    SharedPreferences.setMockInitialValues({});
    final rejected = jwt({'sub': '17', 'exp': seconds + 60});
    final renewed = jwt({'sub': '17', 'exp': seconds + 120});
    expect(
        await BackgroundNetworkBridge.isCredentialRejected(rejected), isFalse);
    await BackgroundNetworkBridge.rejectCredential(rejected);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(BackgroundNetworkBridge.rejectedCredentialHashKey),
        backgroundCredentialFingerprint(rejected));
    expect(prefs.getString(BackgroundNetworkBridge.rejectedCredentialHashKey),
        isNot(contains(rejected)));
    expect(
        await BackgroundNetworkBridge.isCredentialRejected(rejected), isTrue);
    expect(
        await BackgroundNetworkBridge.isCredentialRejected(renewed), isFalse);
  });
}
