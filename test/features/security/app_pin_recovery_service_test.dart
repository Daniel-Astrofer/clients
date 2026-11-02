import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/features/security/application/app_pin_recovery_service.dart';

class _RecoveryHarness {
  final events = <String>[];
  final usernames = <String>[];
  Map<String, dynamic>? body;
  bool current = true;
  Completer<void>? pendingChallenge;
  Completer<void>? pendingSign;
  Completer<void>? pendingRecover;
  Object? challengeError;
  Object? signError;
  Object? recoverError;
  Map<String, dynamic> response = {
    'enabled': true,
    'configured': true,
    'locked': false,
    'minPinLength': 4,
    'maxPinLength': 8,
  };

  late final service = AppPinRecoveryService(
    challenge: (username) async {
      events.add('challenge');
      usernames.add(username);
      await pendingChallenge?.future;
      if (challengeError case final error?) throw error;
      return {'challengeId': 'PUBLIC_FIXTURE_CHALLENGE'};
    },
    sign: (challenge, username) async {
      events.add('sign');
      usernames.add(username);
      expect(challenge['challengeId'], 'PUBLIC_FIXTURE_CHALLENGE');
      await pendingSign?.future;
      if (signError case final error?) throw error;
      return {'signature': 'PUBLIC_FIXTURE_ASSERTION'};
    },
    recover: (payload) async {
      events.add('recover');
      body = payload;
      await pendingRecover?.future;
      if (recoverError case final error?) throw error;
      return response;
    },
  );

  Future<void> replace(
      {String password = 'PUBLIC_FIXTURE_PASSWORD',
      String pin = '1234'}) async {
    await service.replace(
        username: 'fixture-user',
        password: password,
        newPin: pin,
        isCurrent: () => current);
  }
}

void main() {
  test(
      'password and signed challenge authorize exactly one four-digit replacement',
      () async {
    final harness = _RecoveryHarness();
    await harness.replace();
    expect(harness.events, ['challenge', 'sign', 'recover']);
    expect(harness.usernames, everyElement('fixture-user'));
    expect(harness.body, {
      'password': 'PUBLIC_FIXTURE_PASSWORD',
      'newPin': '1234',
      'deviceKey': {'signature': 'PUBLIC_FIXTURE_ASSERTION'},
    });
  });

  for (final pin in ['', '123', '12345', '12a4', '１２３４']) {
    test('invalid PIN cannot start passkey or recovery: $pin', () async {
      final harness = _RecoveryHarness();
      await expectLater(harness.replace(pin: pin), throwsFormatException);
      expect(harness.events, isEmpty);
    });
  }

  test('empty password cannot start passkey or recovery', () async {
    final harness = _RecoveryHarness();
    await expectLater(harness.replace(password: ''), throwsFormatException);
    expect(harness.events, isEmpty);
  });

  test('a stale session cannot even request a challenge', () async {
    final harness = _RecoveryHarness()..current = false;
    await expectLater(harness.replace(), throwsStateError);
    expect(harness.events, isEmpty);
  });

  test('session change during challenge does not invoke passkey or POST',
      () async {
    final harness = _RecoveryHarness()..pendingChallenge = Completer<void>();
    final result = harness.replace();
    await Future<void>.delayed(Duration.zero);
    harness.current = false;
    harness.pendingChallenge!.complete();
    await expectLater(result, throwsStateError);
    expect(harness.events, ['challenge']);
  });

  test('session change while confirming passkey cannot send recovery',
      () async {
    final harness = _RecoveryHarness()..pendingSign = Completer<void>();
    final result = harness.replace();
    await Future<void>.delayed(Duration.zero);
    harness.current = false;
    harness.pendingSign!.complete();
    await expectLater(result, throwsStateError);
    expect(harness.events, ['challenge', 'sign']);
    expect(harness.body, isNull);
  });

  test('cancelled passkey does not transmit password or new PIN', () async {
    final cancelled = const DeviceKeyException(
        'ERR_AUTH_PASSKEY_AUTH_CANCELLED', 'PUBLIC_FIXTURE_CANCELLED');
    final harness = _RecoveryHarness()..signError = cancelled;
    await expectLater(harness.replace(), throwsA(same(cancelled)));
    expect(harness.events, ['challenge', 'sign']);
    expect(harness.body, isNull);
  });

  test('failed challenge never invokes passkey or recovery', () async {
    final failure = const NetworkException();
    final harness = _RecoveryHarness()..challengeError = failure;
    await expectLater(harness.replace(), throwsA(same(failure)));
    expect(harness.events, ['challenge']);
  });

  for (final error in <Object>[
    const NetworkException(),
    const ServerException(message: 'PUBLIC_FIXTURE_DENIED', statusCode: 401),
    const ServerException(message: 'PUBLIC_FIXTURE_BUSY', statusCode: 503),
  ]) {
    test(
        'recovery failures are not retried or converted to success: ${error.runtimeType}',
        () async {
      final harness = _RecoveryHarness()..recoverError = error;
      await expectLater(harness.replace(), throwsA(same(error)));
      expect(harness.events, ['challenge', 'sign', 'recover']);
    });
  }

  for (final response in <Map<String, dynamic>>[
    {},
    {'enabled': false, 'configured': true},
    {'enabled': true, 'configured': false},
    {'enabled': 'true', 'configured': 'true'},
    {'enabled': true, 'configured': true, 'locked': true},
    {'enabled': true, 'configured': true, 'minPinLength': 6, 'maxPinLength': 8},
    {'enabled': true, 'configured': true, 'minPinLength': 0, 'maxPinLength': 8},
    {'enabled': true, 'configured': true, 'minPinLength': 4, 'maxPinLength': 3},
  ]) {
    test('malformed or incompatible result stays unconfirmed: $response',
        () async {
      final harness = _RecoveryHarness()..response = response;
      await expectLater(harness.replace(), throwsFormatException);
      expect(harness.events, ['challenge', 'sign', 'recover']);
    });
  }

  test('session change after POST ignores even a successful response',
      () async {
    final harness = _RecoveryHarness()..pendingRecover = Completer<void>();
    final result = harness.replace();
    await Future<void>.delayed(Duration.zero);
    harness.current = false;
    harness.pendingRecover!.complete();
    await expectLater(result, throwsStateError);
    expect(harness.events, ['challenge', 'sign', 'recover']);
  });
}
