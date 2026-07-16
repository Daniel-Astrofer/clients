import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/balance_websocket_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';

void main() {
  group('BalanceWebSocketService.resolveConnectUrl', () {
    test('builds raw ws url for local tor relay', () {
      expect(
        BalanceWebSocketService.resolveConnectUrl(
          'http://127.0.0.1:19050',
          useRaw: true,
        ),
        'ws://127.0.0.1:19050/ws/raw-balance',
      );
    });

    test('builds sockjs http url', () {
      expect(
        BalanceWebSocketService.resolveConnectUrl(
          'http://127.0.0.1:19050/',
          useRaw: false,
        ),
        'http://127.0.0.1:19050/ws/balance',
      );
    });

    test('maps https to wss for raw', () {
      expect(
        BalanceWebSocketService.resolveConnectUrl(
          'https://api.example.com',
          useRaw: true,
        ),
        'wss://api.example.com/ws/raw-balance',
      );
    });
  });

  group('FinancialRealtimeRefreshLoop', () {
    test('uses disconnected interval when realtime is down', () async {
      final scheduler = _ManualRefreshScheduler();
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () async {},
        isRealtimeConnected: () => false,
        scheduler: scheduler.schedule,
      );

      loop.start();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.lastDelay, financialRealtimeDisconnectedInterval);
      expect(scheduler.scheduleCount, 1);

      loop.dispose();
    });

    test('uses connected interval when websocket is up', () async {
      final scheduler = _ManualRefreshScheduler();
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () async {},
        isRealtimeConnected: () => true,
        scheduler: scheduler.schedule,
      );

      loop.start();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.lastDelay, financialRealtimeFallbackInterval);

      loop.dispose();
    });

    test('schedules the next refresh only after the current one completes',
        () async {
      final scheduler = _ManualRefreshScheduler();
      final refreshCompleter = Completer<void>();
      var refreshCount = 0;
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () {
          refreshCount += 1;
          return refreshCompleter.future;
        },
        scheduler: scheduler.schedule,
      );

      loop.start();
      await Future<void>.delayed(Duration.zero);

      // start() kicks an immediate refresh; no schedule until it finishes.
      expect(refreshCount, 1);
      expect(scheduler.scheduleCount, 0);
      expect(scheduler.hasPendingRefresh, isFalse);

      refreshCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.scheduleCount, 1);
      expect(scheduler.hasPendingRefresh, isTrue);

      loop.dispose();
    });

    test('dispose cancels a pending refresh', () async {
      final scheduler = _ManualRefreshScheduler();
      var refreshCount = 0;
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () async => refreshCount += 1,
        scheduler: scheduler.schedule,
      );

      loop.start();
      await Future<void>.delayed(Duration.zero);
      // Immediate refresh already ran; one schedule is pending.
      expect(refreshCount, 1);
      loop.dispose();
      scheduler.fire();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
      expect(refreshCount, 1);
      expect(scheduler.hasPendingRefresh, isFalse);
    });

    test('dispose during refresh prevents a later reschedule', () async {
      final scheduler = _ManualRefreshScheduler();
      final refreshCompleter = Completer<void>();
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () => refreshCompleter.future,
        scheduler: scheduler.schedule,
      );

      loop.start();
      await Future<void>.delayed(Duration.zero);
      loop.dispose();
      refreshCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.scheduleCount, 0);
      expect(scheduler.hasPendingRefresh, isFalse);
    });
  });

  test('unauthenticated provider does not schedule financial refreshes',
      () async {
    var scheduleCount = 0;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_UnauthenticatedController.new),
        financialRefreshSchedulerProvider.overrideWithValue(
          (delay, callback) {
            scheduleCount += 1;
            return () {};
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(
      balanceWebSocketServiceProvider.future,
    );

    expect(service, isNull);
    expect(scheduleCount, 0);
  });
}

class _UnauthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _ManualRefreshScheduler {
  Duration? lastDelay;
  int scheduleCount = 0;
  int cancelCount = 0;
  void Function()? _pendingCallback;

  bool get hasPendingRefresh => _pendingCallback != null;

  FinancialRefreshCancel schedule(
    Duration delay,
    void Function() callback,
  ) {
    lastDelay = delay;
    scheduleCount += 1;
    var active = true;

    void runOnce() {
      if (!active) {
        return;
      }
      active = false;
      callback();
    }

    _pendingCallback = runOnce;
    return () {
      if (!active) {
        return;
      }
      active = false;
      cancelCount += 1;
      if (identical(_pendingCallback, runOnce)) {
        _pendingCallback = null;
      }
    };
  }

  void fire() {
    final callback = _pendingCallback;
    _pendingCallback = null;
    callback?.call();
  }
}
