import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/services/tor_network_bootstrap.dart';
import 'package:kerosene/core/services/tor_service.dart';

class _RecordingTorService implements TorService {
  _RecordingTorService({this.startResult = true, this.startGate});

  final bool startResult;
  final Completer<void>? startGate;
  var startCalled = false;
  var startCallCount = 0;
  var relayStartCallCount = 0;
  String? relayTargetHost;
  int? relayTargetPort;

  @override
  bool get isRunning => startCalled && startResult;

  @override
  int get socksPort => 18792;

  @override
  Future<bool> start() async {
    startCalled = true;
    startCallCount++;
    await startGate?.future;
    return startResult;
  }

  @override
  Future<int> startRelay(String targetHost, int targetPort) async {
    relayStartCallCount++;
    relayTargetHost = targetHost;
    relayTargetPort = targetPort;
    return 43123;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(resetTorBootstrapStateForTesting);
  tearDown(resetTorBootstrapStateForTesting);

  group('resolveTorBootstrapTarget', () {
    test('marks local Kubernetes gateway URLs as non-onion', () {
      final target = resolveTorBootstrapTarget('http://10.0.2.2:30082');

      expect(target.requiresTor, isFalse);
      expect(target.apiUrl, 'http://10.0.2.2:30082');
      expect(target.targetHost, '10.0.2.2');
      expect(target.targetPort, 30082);
    });

    test('uses Tor relay target details for onion URLs', () {
      final target = resolveTorBootstrapTarget(
        'http://examplehiddenservice.onion',
      );

      expect(target.requiresTor, isTrue);
      expect(target.apiUrl, 'http://examplehiddenservice.onion');
      expect(target.targetHost, 'examplehiddenservice.onion');
      expect(target.targetPort, 80);
    });
  });

  test('bootstrapTorNetwork refuses non-onion mobile backend URLs', () async {
    final previousApiUrl = AppConfig.apiUrl;
    final previousActiveNodeUrl = AppConfig.activeNodeUrl;
    final previousTorEnabled = AppConfig.isTorEnabled;
    final torService = _RecordingTorService();
    final updates = <String>[];
    addTearDown(() {
      AppConfig.apiUrl = previousApiUrl;
      AppConfig.activeNodeUrl = previousActiveNodeUrl;
      AppConfig.isTorEnabled = previousTorEnabled;
    });

    AppConfig.activeNodeUrl = 'http://10.0.2.2:30082';
    AppConfig.apiUrl = 'http://10.0.2.2:30082';
    AppConfig.isTorEnabled = false;

    final bootstrapped = await bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updates.add,
    );

    expect(bootstrapped, isFalse);
    expect(torService.startCalled, isFalse);
    expect(AppConfig.isTorEnabled, isFalse);
    expect(updates, isEmpty);
  });

  test('bootstrapTorNetwork exposes onion backend through local Tor relay',
      () async {
    final previousApiUrl = AppConfig.apiUrl;
    final previousActiveNodeUrl = AppConfig.activeNodeUrl;
    final previousTorEnabled = AppConfig.isTorEnabled;
    final torService = _RecordingTorService();
    final updates = <String>[];
    addTearDown(() {
      AppConfig.apiUrl = previousApiUrl;
      AppConfig.activeNodeUrl = previousActiveNodeUrl;
      AppConfig.isTorEnabled = previousTorEnabled;
    });

    AppConfig.activeNodeUrl = 'http://examplehiddenservice.onion:8080';
    AppConfig.apiUrl = AppConfig.activeNodeUrl;
    AppConfig.isTorEnabled = false;

    final bootstrapped = await bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updates.add,
    );

    expect(bootstrapped, isTrue);
    expect(torService.startCalled, isTrue);
    expect(torService.relayTargetHost, 'examplehiddenservice.onion');
    expect(torService.relayTargetPort, 8080);
    expect(AppConfig.isTorEnabled, isTrue);
    expect(AppConfig.activeNodeUrl, 'http://examplehiddenservice.onion:8080');
    expect(AppConfig.apiUrl, 'http://127.0.0.1:43123');
    expect(updates, ['http://127.0.0.1:43123']);
  });

  test('bootstrapTorNetwork blocks requests when Tor cannot start', () async {
    final previousApiUrl = AppConfig.apiUrl;
    final previousActiveNodeUrl = AppConfig.activeNodeUrl;
    final previousTorEnabled = AppConfig.isTorEnabled;
    final torService = _RecordingTorService(startResult: false);
    final updates = <String>[];
    addTearDown(() {
      AppConfig.apiUrl = previousApiUrl;
      AppConfig.activeNodeUrl = previousActiveNodeUrl;
      AppConfig.isTorEnabled = previousTorEnabled;
    });

    AppConfig.activeNodeUrl = 'http://examplehiddenservice.onion';
    AppConfig.apiUrl = AppConfig.activeNodeUrl;
    AppConfig.isTorEnabled = false;

    final bootstrapped = await bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updates.add,
    );

    expect(bootstrapped, isFalse);
    expect(torService.startCalled, isTrue);
    expect(torService.relayTargetHost, isNull);
    expect(AppConfig.isTorEnabled, isFalse);
    expect(updates, isEmpty);
  });

  test('bootstrapTorNetwork cools down repeated failed attempts', () async {
    final previousApiUrl = AppConfig.apiUrl;
    final previousActiveNodeUrl = AppConfig.activeNodeUrl;
    final previousTorEnabled = AppConfig.isTorEnabled;
    final torService = _RecordingTorService(startResult: false);
    final updates = <String>[];
    addTearDown(() {
      AppConfig.apiUrl = previousApiUrl;
      AppConfig.activeNodeUrl = previousActiveNodeUrl;
      AppConfig.isTorEnabled = previousTorEnabled;
    });

    AppConfig.activeNodeUrl = 'http://examplehiddenservice.onion';
    AppConfig.apiUrl = AppConfig.activeNodeUrl;
    AppConfig.isTorEnabled = false;

    final first = await bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updates.add,
    );
    final second = await bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updates.add,
    );

    expect(first, isFalse);
    expect(second, isFalse);
    expect(torService.startCallCount, 1);
    expect(torService.relayStartCallCount, 0);
    expect(updates, isEmpty);
  });

  test('bootstrapTorNetwork shares concurrent mobile bootstrap attempts',
      () async {
    final previousApiUrl = AppConfig.apiUrl;
    final previousActiveNodeUrl = AppConfig.activeNodeUrl;
    final previousTorEnabled = AppConfig.isTorEnabled;
    final startGate = Completer<void>();
    final torService = _RecordingTorService(startGate: startGate);
    final updatesA = <String>[];
    final updatesB = <String>[];
    addTearDown(() {
      if (!startGate.isCompleted) {
        startGate.complete();
      }
      AppConfig.apiUrl = previousApiUrl;
      AppConfig.activeNodeUrl = previousActiveNodeUrl;
      AppConfig.isTorEnabled = previousTorEnabled;
    });

    AppConfig.activeNodeUrl = 'http://examplehiddenservice.onion';
    AppConfig.apiUrl = AppConfig.activeNodeUrl;
    AppConfig.isTorEnabled = false;

    final first = bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updatesA.add,
    );
    final second = bootstrapTorNetwork(
      torService: torService,
      updateApiUrl: updatesB.add,
    );

    await Future<void>.delayed(Duration.zero);

    expect(torService.startCallCount, 1);

    startGate.complete();
    final results = await Future.wait([first, second]);

    expect(results, [isTrue, isTrue]);
    expect(torService.startCallCount, 1);
    expect(torService.relayStartCallCount, 1);
    expect(updatesA, ['http://127.0.0.1:43123']);
    expect(updatesB, ['http://127.0.0.1:43123']);
  });
}
