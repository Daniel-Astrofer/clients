import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/background_alerts_runtime_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/services/background_service_status.dart';

class _Driver extends BackgroundAlertsDriver {
  @override
  bool get supported => true;
  bool permission = true;
  bool running = false;
  bool failStart = false;
  bool failStop = false;
  bool confirmStart = true;
  Object? startError;
  String nextOwner = '17';
  String? owner;
  int starts = 0;
  int stops = 0;
  int initializations = 0;
  Completer<void>? pendingStart;
  Completer<void>? pendingInitialize;
  final events = <String>[];
  @override
  Future<bool> permissionsEnabled() async => permission;
  @override
  Future<BackgroundServiceStatus> snapshot() async =>
      BackgroundServiceStatus(running: running, userId: owner);
  @override
  Future<void> initialize() async {
    initializations++;
    await pendingInitialize?.future;
  }

  @override
  Future<void> start() async {
    final requested = nextOwner;
    starts++;
    events.add('start:$requested');
    await pendingStart?.future;
    if (startError != null) throw startError!;
    if (failStart) throw StateError('fixture start rejected');
    running = confirmStart;
    owner = requested;
  }

  @override
  Future<void> stop() async {
    stops++;
    events.add('stop:${owner ?? '-'}');
    if (failStop) throw StateError('fixture stop rejected');
    running = false;
    owner = null;
  }
}

Future<ProviderContainer> _container(WidgetTester tester, _Driver driver,
    {bool enabled = true, bool foreground = true}) async {
  tester.binding.handleAppLifecycleStateChanged(
      foreground ? AppLifecycleState.resumed : AppLifecycleState.paused);
  SharedPreferences.setMockInitialValues({
    AlertPreferencesNotifier.backgroundAlertsKey: enabled,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    backgroundAlertsDriverProvider.overrideWithValue(driver),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'OS visibility rejection remains pending instead of escaping auth',
      (tester) async {
    final driver = _Driver()
      ..startError = const BackgroundServiceNeedsForeground();
    final c = await _container(tester, driver);
    await c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.waitingForForeground);
    expect(driver.running, isFalse);
    c.dispose();
  });
  testWidgets(
      'a failed stop stays visible rather than claiming the service is off',
      (tester) async {
    final driver = _Driver()
      ..running = true
      ..owner = '17';
    final c = await _container(tester, driver);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    await runtime.activateFor('17');
    driver.failStop = true;
    await runtime.deactivate();
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.failedStop);
    expect(driver.running, isTrue);
    c.dispose();
  });
  testWidgets('hidden startup waits without initiating a service',
      (tester) async {
    final driver = _Driver();
    final c = await _container(tester, driver, foreground: false);
    await c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.waitingForForeground);
    expect(driver.starts, 0);
    expect(driver.initializations, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await c.read(backgroundAlertsRuntimeProvider.notifier).retry();
    expect(driver.starts, 1);
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.running);
    c.dispose();
  });

  testWidgets('keeps an already confirmed service while the app is hidden',
      (tester) async {
    final driver = _Driver()
      ..running = true
      ..owner = '17';
    final c = await _container(tester, driver, foreground: false);
    await c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.running);
    expect(driver.starts, 0);
    expect(driver.stops, 0);
    c.dispose();
  });

  testWidgets('permission denial is visible and never reported as running',
      (tester) async {
    final driver = _Driver()..permission = false;
    final c = await _container(tester, driver);
    await c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.permissionRequired);
    expect(driver.starts, 0);
    c.dispose();
  });

  testWidgets('initialization returning after logout cannot start the service',
      (tester) async {
    final driver = _Driver()..pendingInitialize = Completer<void>();
    final c = await _container(tester, driver);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    final activating = runtime.activateFor('17');
    await tester.pump();
    expect(driver.initializations, 1);
    final logout = runtime.deactivate();
    driver.pendingInitialize!.complete();
    await activating;
    await logout;
    expect(driver.starts, 0);
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.signedOut);
    c.dispose();
  });

  testWidgets(
      'account changes stop a late start before starting the new account',
      (tester) async {
    final driver = _Driver()..pendingStart = Completer<void>();
    final c = await _container(tester, driver);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    final first = runtime.activateFor('17');
    await tester.pump();
    expect(driver.starts, 1);
    driver.nextOwner = '21';
    final next = runtime.activateFor('21');
    driver.pendingStart!.complete();
    await first;
    await next;
    expect(driver.events, ['start:17', 'stop:17', 'start:21']);
    expect(driver.owner, '21');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.running);
    c.dispose();
  });

  testWidgets('concurrent resumptions share one pending start', (tester) async {
    final driver = _Driver()..pendingStart = Completer<void>();
    final c = await _container(tester, driver);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    final first = runtime.activateFor('17');
    await tester.pump();
    final again = runtime.retry();
    driver.pendingStart!.complete();
    await Future.wait([first, again]);
    expect(driver.starts, 1);
    c.dispose();
  });

  testWidgets('an unconfirmed start exposes a failure and is cleaned up',
      (tester) async {
    final driver = _Driver()..confirmStart = false;
    final c = await _container(tester, driver);
    await c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    expect(c.read(backgroundAlertsRuntimeProvider).phase,
        BackgroundAlertsPhase.failedStart);
    expect(driver.running, isFalse);
    expect(driver.stops, 1);
    c.dispose();
  });

  testWidgets('explicit failed enabling restores the saved preference',
      (tester) async {
    final driver = _Driver()..failStart = true;
    final c = await _container(tester, driver, enabled: false);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    await runtime.activateFor('17');
    await expectLater(
        runtime.setEnabled(true, expectedSession: runtime.session),
        throwsStateError);
    await runtime.retry();
    expect(c.read(alertPreferencesProvider).backgroundAlertsEnabled, isFalse);
    expect(driver.running, isFalse);
    c.dispose();
  });

  testWidgets('a stale account cannot save a preference for the next account',
      (tester) async {
    final driver = _Driver();
    final c = await _container(tester, driver, enabled: false);
    final runtime = c.read(backgroundAlertsRuntimeProvider.notifier);
    await runtime.activateFor('17');
    final old = runtime.session;
    await runtime.activateFor('21');
    await expectLater(
        runtime.setEnabled(true, expectedSession: old), throwsStateError);
    expect(c.read(alertPreferencesProvider).backgroundAlertsEnabled, isFalse);
    c.dispose();
  });

  testWidgets(
      'disposing during a start cleans it up without using a disposed ref',
      (tester) async {
    final driver = _Driver()..pendingStart = Completer<void>();
    final c = await _container(tester, driver);
    final pending =
        c.read(backgroundAlertsRuntimeProvider.notifier).activateFor('17');
    await tester.pump();
    c.dispose();
    driver.pendingStart!.complete();
    await pending;
    expect(driver.running, isFalse);
    expect(driver.stops, 1);
    expect(tester.takeException(), isNull);
  });

  test('JWT subject fences separately stored user and token snapshots', () {
    String token(Object sub) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': sub,
              'exp': DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000
            })))}.signature';
    expect(backgroundTokenMatchesUser(token('17'), '17'), isTrue);
    expect(backgroundTokenMatchesUser('Bearer ${token('17')}', '17'), isTrue);
    expect(backgroundTokenMatchesUser(token('21'), '17'), isFalse);
    expect(backgroundTokenMatchesUser(token(17), '17'), isFalse);
    expect(backgroundTokenMatchesUser('malformed', '17'), isFalse);
  });
}
