import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';

void main() {
  group('FinancialRealtimeRefreshLoop', () {
    test('uses the bounded production interval', () {
      final scheduler = _ManualRefreshScheduler();
      final loop = FinancialRealtimeRefreshLoop(
        refresh: () async {},
        scheduler: scheduler.schedule,
      );

      loop.start();

      expect(scheduler.lastDelay, financialRealtimeFallbackInterval);
      expect(scheduler.scheduleCount, 1);

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
      scheduler.fire();

      expect(refreshCount, 1);
      expect(scheduler.scheduleCount, 1);
      expect(scheduler.hasPendingRefresh, isFalse);

      refreshCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.scheduleCount, 2);
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
      loop.dispose();
      scheduler.fire();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.cancelCount, 1);
      expect(refreshCount, 0);
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
      scheduler.fire();
      loop.dispose();
      refreshCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.scheduleCount, 1);
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
