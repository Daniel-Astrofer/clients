import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/domain/repositories/security_repository.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_pin_authorization.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';

final _owner = NotifierProvider<_Owner, String?>(_Owner.new);

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change(String? next) => state = next;
}

const _status = AppPinStatus(
  enabled: true,
  configured: true,
  minPinLength: 4,
  maxPinLength: 4,
);

class _Repository implements SecurityRepository {
  _Repository({this.expectedPin = '1234'});
  final String expectedPin;
  final pending = Completer<Either<Failure, AppPinStatus>>();
  int calls = 0;
  @override
  Future<Either<Failure, AppPinStatus>> verifyAppPin({required String pin}) {
    expect(pin, expectedPin);
    calls++;
    return pending.future;
  }

  @override
  Future<Either<Failure, AppPinStatus>> configureAppPin({
    required bool enabled,
    String? pin,
    String? currentPin,
    String? totpCode,
  }) {
    expect(enabled, isTrue);
    return verifyAppPin(pin: pin!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _open(WidgetTester tester, _Repository repository,
    GlobalKey<NavigatorState> nav, List<TransactionDeviceAuthOutcome?> outcomes,
    {required bool setup}) async {
  late BuildContext host;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
      securityRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold(body: Text('home'));
      }),
    ),
  ));
  final container = ProviderScope.containerOf(host);
  unawaited(nav.currentState!
      .push<TransactionDeviceAuthOutcome>(
        MaterialPageRoute(
            builder: (_) => setup
                ? const TransactionPinSetupScreen(status: _status)
                : const TransactionPinAuthorizationScreen(status: _status)),
      )
      .then(outcomes.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '1234');
  await tester.pump();
  if (setup) {
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
  }
  expect(repository.calls, 1);
  return container;
}

void main() {
  for (final length in [4, 6, 8]) {
    testWidgets('real payment gate verifies the complete $length digit PIN',
        (tester) async {
      final pin = '12345678'.substring(0, length);
      final repo = _Repository(expectedPin: pin);
      final results = <TransactionAuthResult>[];
      late BuildContext host;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
          securityRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            host = context;
            return const Scaffold(body: Text('review'));
          }),
        ),
      ));
      unawaited(TransactionAuthGate.show(host,
          profile: AccountSecurityProfile(
            mode: AccountSecurityMode.standard,
            requiredFactors: const ['PASSKEY'],
            appPin: _status.copyWith(maxPinLength: 8),
          )).then(results.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      expect(repo.calls, 0,
          reason: 'Policy minimum is not the stored PIN size');
      if (length > 4) {
        await tester.enterText(find.byType(TextField), pin);
        await tester.pump();
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repo.calls, 1);
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(results.single.isAuthenticated, isTrue);
      expect(results.single.appPin, pin);
      expect(find.text('review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final setup in [false, true]) {
    final flow = setup ? 'setup' : 'verification';
    testWidgets('$flow ignores completion during the closing animation',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      await _open(tester, repo, nav, outcomes, setup: setup);
      nav.currentState!.pop();
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(outcomes, [null]);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$flow keeps a rejected PIN in its own route for retry',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      await _open(tester, repo, nav, outcomes, setup: setup);
      repo.pending.complete(const Left(ServerFailure(message: 'AUTH_008')));
      await tester.pumpAndSettle();
      expect(outcomes, isEmpty);
      final pad =
          tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold));
      expect(pad.busy, isFalse);
      expect(pad.error, isNotNull);
      expect(repo.calls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$flow ignores success after closing the PIN route',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      await _open(tester, repo, nav, outcomes, setup: setup);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(outcomes, [null]);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$flow rejects a changed account before a late success',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      final container = await _open(tester, repo, nav, outcomes, setup: setup);
      container.read(_owner.notifier).change('owner-b');
      await tester.pumpAndSettle();
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(outcomes.single?.status, TransactionDeviceAuthStatus.rejected);
      expect(outcomes.single?.appPin, isNull);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$flow removes its own route without closing an overlaid route',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      final container = await _open(tester, repo, nav, outcomes, setup: setup);
      unawaited(nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('another route')),
      )));
      await tester.pumpAndSettle();
      container.read(_owner.notifier).change(null);
      await tester.pumpAndSettle();
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(find.text('another route'), findsOneWidget);
      expect(outcomes.single?.status, TransactionDeviceAuthStatus.rejected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$flow returns verified PIN only to its original account',
        (tester) async {
      final repo = _Repository();
      final nav = GlobalKey<NavigatorState>();
      final outcomes = <TransactionDeviceAuthOutcome?>[];
      await _open(tester, repo, nav, outcomes, setup: setup);
      expect(
          tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold)).busy,
          isTrue);
      repo.pending.complete(const Right(_status));
      await tester.pumpAndSettle();
      expect(
          outcomes.single?.status, TransactionDeviceAuthStatus.authenticated);
      expect(outcomes.single?.appPin, '1234');
      expect(repo.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
