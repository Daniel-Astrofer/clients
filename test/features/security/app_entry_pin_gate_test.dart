import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/domain/repositories/security_repository.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/app_entry_pin_gate.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppEntryPinSession.clear();
    AppPinSetupHandoff.clear();
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('shows the requested PIN setup and unlock copy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _AuthenticatedAuthController(),
          ),
          appPinGateStatusProvider.overrideWithValue(
            const AppPinStatus(
              configured: false,
              minPinLength: 4,
              maxPinLength: 4,
            ),
          ),
          appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
          balanceWebSocketServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          locale: Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppEntryPinGate(
            child: Text('home ready'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Crie um PIN para acessar a conta'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(find.text('Confirme o PIN'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _AuthenticatedAuthController(),
          ),
          appPinGateStatusProvider.overrideWithValue(
            const AppPinStatus(
              enabled: true,
              configured: true,
              minPinLength: 4,
              maxPinLength: 4,
            ),
          ),
          appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
          balanceWebSocketServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          locale: Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppEntryPinGate(
            child: Text('home ready'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Digite o PIN para acessar sua conta'), findsOneWidget);
  });

  testWidgets('shows PIN pad immediately without waiting for network status',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _AuthenticatedAuthController(),
          ),
          appPinGateStatusProvider.overrideWithValue(
            const AppPinStatus(
              enabled: true,
              configured: true,
              minPinLength: 6,
              maxPinLength: 6,
            ),
          ),
          appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
          balanceWebSocketServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          locale: Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppEntryPinGate(
            child: Text('home ready'),
          ),
        ),
      ),
    );

    // First frame — pad must be ready (no Tor dots).
    await tester.pump();
    expect(find.text('Digite o PIN para acessar sua conta'), findsOneWidget);
    expect(find.byType(TorLoadingDots), findsNothing);
    expect(find.text('home ready'), findsNothing);
  });

  testWidgets('hides the numeric pad and shows loading while verifying PIN',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PendingPinSecurityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _AuthenticatedAuthController(),
          ),
          securityRepositoryProvider.overrideWithValue(repository),
          appPinGateStatusProvider.overrideWithValue(
            const AppPinStatus(
              enabled: true,
              configured: true,
              minPinLength: 4,
              maxPinLength: 4,
            ),
          ),
          appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
          balanceWebSocketServiceProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          locale: Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppEntryPinGate(
            child: Text('home ready'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.verifyCalls, 1);
    expect(repository.lastPin, '1234');
    final scaffoldFinder = find.byType(PinEntryScaffold);
    expect(scaffoldFinder, findsOneWidget);
    expect((tester.widget(scaffoldFinder) as PinEntryScaffold).busy, isTrue);
    expect(find.text('Verificando PIN…'), findsOneWidget);

    repository.completeVerify(
      const Left(
        AuthFailure(
          message: 'ERR_AUTH_APP_PIN_INVALID',
          errorCode: 'ERR_AUTH_APP_PIN_INVALID',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect((tester.widget(scaffoldFinder) as PinEntryScaffold).busy, isFalse);
    expect(find.text('Verificando PIN…'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Digite o PIN para acessar sua conta'), findsOneWidget);
  });

  for (final failureCode in ['SYS_500', 'ERR_NETWORK']) {
    testWidgets(
        'retains a full PIN and waits for manual retry after $failureCode',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      final repository = _SequencedPinVerifySecurityRepository([
        Left(
          AuthFailure(message: 'upstream unavailable', errorCode: failureCode),
        ),
        const Right(
          AppPinStatus(enabled: true, configured: true),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _AuthenticatedAuthController(),
            ),
            securityRepositoryProvider.overrideWithValue(repository),
            appPinGateStatusProvider.overrideWithValue(
              const AppPinStatus(
                enabled: true,
                configured: true,
                minPinLength: 4,
                maxPinLength: 4,
              ),
            ),
            appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            balanceWebSocketServiceProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            locale: Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppEntryPinGate(child: Text('home ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(repository.verifyCalls, 1);
      expect(
        (tester.widget(find.byType(PinEntryScaffold)) as PinEntryScaffold)
            .valueLength,
        4,
      );
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repository.verifyCalls, 2);
      expect(repository.pins, everyElement('1234'));
      expect(find.text('home ready'), findsOneWidget);
    });
  }

  for (final setup in [false, true]) {
    testWidgets('entry PIN clears input on account change, setup=$setup',
        (tester) async {
      final repo = _ScopedPinRepository();
      final container = await _pumpScopedGate(tester, repo, setup: setup);
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      (container.read(authControllerProvider.notifier)
              as _SwitchableAuthController)
          .setUser(_otherUser);
      await tester.pumpAndSettle();
      final scaffold =
          tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold));
      expect(scaffold.valueLength, 0);
      expect(repo.pending, isEmpty);
    });

    testWidgets('late PIN success cannot unlock another account, setup=$setup',
        (tester) async {
      final repo = _ScopedPinRepository();
      final container = await _pumpScopedGate(tester, repo, setup: setup);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      if (setup) {
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(find.byType(TextField))
                .focusNode!
                .hasFocus,
            isTrue);
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pump();
      }
      expect(repo.pending, hasLength(1));
      (container.read(authControllerProvider.notifier)
              as _SwitchableAuthController)
          .setUser(_otherUser);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      repo.pending.single
          .complete(const Right(AppPinStatus(enabled: true, configured: true)));
      await tester.pumpAndSettle();
      expect(container.read(appEntryPinUnlockedProvider), isFalse);
      expect(AppEntryPinSession.unlocked, isFalse);
      expect(find.text('home ready'), findsNothing);
      final scope = container.read(sessionStorageScopeProvider)!;
      expect(
          container
              .read(sharedPreferencesProvider)
              .getBool(appPinConfiguredPrefsKey(scope)),
          isNull);
    });
  }

  testWidgets('an earlier completion cannot clear a newer PIN request',
      (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    (container.read(authControllerProvider.notifier)
            as _SwitchableAuthController)
        .setUser(_otherUser);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(repo.pending, hasLength(2));
    repo.pending.first
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pump();
    expect(AppEntryPinSession.pinRequestInFlight, isTrue);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    repo.pending.last
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
    expect(AppEntryPinSession.pinRequestInFlight, isFalse);
  });

  testWidgets('a superseded response cannot unlock after A to B to A',
      (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    final auth = container.read(authControllerProvider.notifier)
        as _SwitchableAuthController;
    auth.setUser(_otherUser);
    auth.setUser(_testUser);
    await tester.pump();
    repo.pending.single
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(find.text('home ready'), findsNothing);
  });

  testWidgets('repository exceptions stop waiting and require explicit retry',
      (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    repo.pending.single.completeError(StateError('DioException: /api/private'));
    await tester.pumpAndSettle();
    expect(repo.pending, hasLength(1));
    expect(AppEntryPinSession.pinRequestInFlight, isFalse);
    expect(tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold)).busy,
        isFalse);
    expect(find.textContaining('/api/private'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repo.pending, hasLength(2));
    repo.pending.last
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new setup uses exactly four digits within the server bounds',
      (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo,
        setup: true,
        status: const AppPinStatus(minPinLength: 4, maxPinLength: 8));
    expect(
        tester
            .widget<PinEntryScaffold>(find.byType(PinEntryScaffold))
            .maxLength,
        4);
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pumpAndSettle();
    expect(find.text('Confirme o PIN'), findsOneWidget);
    expect(repo.pending, isEmpty);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(repo.configurePins, ['1234']);
    repo.pending.single
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
  });

  testWidgets('setup refuses an incompatible server policy', (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo,
        setup: true,
        status: const AppPinStatus(minPinLength: 6, maxPinLength: 8));
    final scaffold =
        tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold));
    expect(scaffold.enabled, isFalse);
    expect(scaffold.onConfirm, isNull);
    scaffold.onDigit('1');
    await tester.pump();
    expect(repo.pending, isEmpty);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
  });

  testWidgets('PIN mismatch returns to creation without configuring anything',
      (tester) async {
    final repo = _ScopedPinRepository();
    await _pumpScopedGate(tester, repo, setup: true);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1235');
    await tester.pumpAndSettle();
    expect(find.text('Crie um PIN para acessar a conta'), findsOneWidget);
    expect(
        tester
            .widget<PinEntryScaffold>(find.byType(PinEntryScaffold))
            .valueLength,
        0);
    expect(repo.pending, isEmpty);
    expect(tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold)).error,
        isNotNull);
  });

  testWidgets('back from pending setup ignores a late success', (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo, setup: true);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(repo.pending, hasLength(1));
    tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold)).onCancel!();
    await tester.pumpAndSettle();
    expect(find.text('Crie um PIN para acessar a conta'), findsOneWidget);
    repo.pending.single
        .complete(const Right(AppPinStatus(enabled: true, configured: true)));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(find.text('home ready'), findsNothing);
  });

  testWidgets('unconfirmed setup response cannot unlock the account',
      (tester) async {
    final repo = _ScopedPinRepository();
    final container = await _pumpScopedGate(tester, repo, setup: true);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    repo.pending.single.complete(const Right(AppPinStatus()));
    await tester.pumpAndSettle();
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(find.text('home ready'), findsNothing);
    expect(tester.widget<PinEntryScaffold>(find.byType(PinEntryScaffold)).error,
        isNotNull);
  });

  for (final setup in [false, true]) {
    testWidgets(
        'backgrounding clears secrets and ignores late PIN success, setup=$setup',
        (tester) async {
      final repo = _ScopedPinRepository();
      final container = await _pumpScopedGate(tester, repo, setup: setup);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      if (setup) {
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pump();
      }
      expect(repo.pending, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<PinEntryScaffold>(find.byType(PinEntryScaffold))
              .valueLength,
          0);
      repo.pending.single
          .complete(const Right(AppPinStatus(enabled: true, configured: true)));
      await tester.pumpAndSettle();
      expect(container.read(appEntryPinUnlockedProvider), isFalse);
      expect(find.text('home ready'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('unlocked PIN cannot cross accounts through AuthLoading', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider
          .overrideWith(() => _SwitchableAuthController(_testUser)),
    ]);
    addTearDown(container.dispose);
    container.read(appEntryPinUnlockedProvider.notifier).unlock();
    final auth = container.read(authControllerProvider.notifier)
        as _SwitchableAuthController;
    auth.setLoading();
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
    auth.setUser(_otherUser);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(AppEntryPinSession.unlocked, isFalse);
  });

  test('reloads app PIN status when the authenticated session changes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    final repository = _SequencedPinStatusSecurityRepository([
      const AppPinStatus(enabled: true, configured: true),
      const AppPinStatus(enabled: false, configured: false),
    ]);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        securityRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _SwitchableAuthController(_testUser),
        ),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(appPinStatusProvider.future);
    expect(first.configured, isTrue);

    (container.read(authControllerProvider.notifier)
            as _SwitchableAuthController)
        .setUser(
      User(
        id: 'user-2',
        username: 'hal',
        createdAt: DateTime(2026, 1, 2),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final second = await container.read(appPinStatusProvider.future);
    expect(second.configured, isFalse);
    expect(repository.statusCalls, 2);
  });

  test('unknown local PIN hint defaults to unlock pad (single verify)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authControllerProvider.overrideWith(
          () => _AuthenticatedAuthController(),
        ),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(container.dispose);

    final status = container.read(appPinGateStatusProvider);
    expect(status.requiresSetup, isFalse);
    expect(status.requiresVerification, isTrue);
    expect(status.configured, isTrue);
    // Flexible length until the real PIN length is known — no auto-submit at 4.
    expect(status.minPinLength, 4);
    expect(status.maxPinLength, 8);
  });

  test('known pin length uses fixed min=max for auto-submit', () async {
    SharedPreferences.setMockInitialValues({
      appPinConfiguredPrefsKey('user_user-1'): true,
      appPinLengthPrefsKey('user_user-1'): 6,
    });
    final sharedPreferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authControllerProvider.overrideWith(
          () => _AuthenticatedAuthController(),
        ),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(container.dispose);

    final status = container.read(appPinGateStatusProvider);
    expect(status.configured, isTrue);
    expect(status.minPinLength, 6);
    expect(status.maxPinLength, 6);
  });

  test('explicit configured=false still shows setup (create + confirm)',
      () async {
    // Scope for _testUser (id "user-1") is user_user-1.
    SharedPreferences.setMockInitialValues({
      appPinConfiguredPrefsKey('user_user-1'): false,
    });
    final sharedPreferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authControllerProvider.overrideWith(
          () => _AuthenticatedAuthController(),
        ),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(container.dispose);

    final scope = container.read(sessionStorageScopeProvider);
    expect(scope, 'user_user-1');
    final status = container.read(appPinGateStatusProvider);
    expect(status.requiresSetup, isTrue);
    expect(status.configured, isFalse);
  });

  test('PIN unlock survives AuthLoading session probe (no double PIN)',
      () async {
    AppEntryPinSession.clear();
    final controller = _SwitchableAuthController(_testUser);
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(container.dispose);

    container.read(appEntryPinUnlockedProvider.notifier).unlock();
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
    expect(AppEntryPinSession.unlocked, isTrue);

    // Simulate retrySessionCheck-style transient loading.
    controller.setLoading();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appEntryPinUnlockedProvider), isTrue);

    controller.setUser(_testUser);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appEntryPinUnlockedProvider), isTrue);

    controller.setUnauthenticated();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(AppEntryPinSession.unlocked, isFalse);
  });

  test('static session survives notifier rebuild (no double PIN)', () async {
    AppEntryPinSession.clear();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _AuthenticatedAuthController(),
        ),
        appColdStartProvider.overrideWith(() => _TorReadyColdStart()),
      ],
    );
    addTearDown(() {
      AppEntryPinSession.clear();
      container.dispose();
    });

    container.read(appEntryPinUnlockedProvider.notifier).unlock();
    expect(AppEntryPinSession.unlocked, isTrue);

    // Force notifier rebuild by invalidating — static session must restore true.
    container.invalidate(appEntryPinUnlockedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(AppEntryPinSession.unlocked, isTrue);
    expect(container.read(appEntryPinUnlockedProvider), isTrue);
  });
}

Future<ProviderContainer> _pumpScopedGate(
    WidgetTester tester, _ScopedPinRepository repository,
    {bool setup = false, AppPinStatus? status}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider
            .overrideWith(() => _SwitchableAuthController(_testUser)),
        securityRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appPinGateStatusProvider.overrideWithValue(status ??
            AppPinStatus(
              enabled: !setup,
              configured: !setup,
              minPinLength: 4,
              maxPinLength: 4,
            )),
        appColdStartProvider.overrideWith(_TorReadyColdStart.new),
        balanceWebSocketServiceProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(
          locale: Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppEntryPinGate(child: Text('home ready')))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
      tester.element(find.byType(AppEntryPinGate)));
}

class _ScopedPinRepository implements SecurityRepository {
  @override
  Future<Either<Failure, AppPinStatus>> getAppPinStatus() async =>
      const Left(NetworkFailure());

  final configurePins = <String?>[];
  final pending = <Completer<Either<Failure, AppPinStatus>>>[];
  Future<Either<Failure, AppPinStatus>> _request() {
    final request = Completer<Either<Failure, AppPinStatus>>();
    pending.add(request);
    return request.future;
  }

  @override
  Future<Either<Failure, AppPinStatus>> verifyAppPin({required String pin}) =>
      _request();
  @override
  Future<Either<Failure, AppPinStatus>> configureAppPin(
      {required bool enabled,
      String? pin,
      String? currentPin,
      String? totpCode}) {
    configurePins.add(pin);
    return _request();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _otherUser =
    User(id: 'user-2', username: 'hal', createdAt: DateTime(2026, 1, 2));

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_testUser);
}

class _TorReadyColdStart extends AppColdStartNotifier {
  @override
  AppColdStartState build() {
    return const AppColdStartState(
      torSettled: true,
    );
  }

  @override
  Future<bool> waitUntilTorReadyForApi({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return true;
  }
}

class _SwitchableAuthController extends AuthController {
  final User initialUser;

  _SwitchableAuthController(this.initialUser);

  @override
  AuthState build() => AuthAuthenticated(initialUser);

  void setUser(User user) {
    state = AuthAuthenticated(user);
  }

  void setLoading() {
    state = const AuthLoading();
  }

  void setUnauthenticated() {
    state = const AuthUnauthenticated();
  }
}

class _PendingPinSecurityRepository implements SecurityRepository {
  final Completer<Either<Failure, AppPinStatus>> _verifyCompleter =
      Completer<Either<Failure, AppPinStatus>>();
  int verifyCalls = 0;
  String? lastPin;

  @override
  Future<Either<Failure, AppPinStatus>> verifyAppPin({
    required String pin,
  }) {
    verifyCalls += 1;
    lastPin = pin;
    return _verifyCompleter.future;
  }

  void completeVerify(Either<Failure, AppPinStatus> result) {
    _verifyCompleter.complete(result);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequencedPinVerifySecurityRepository implements SecurityRepository {
  final List<Either<Failure, AppPinStatus>> results;
  final List<String> pins = [];

  _SequencedPinVerifySecurityRepository(this.results);

  int get verifyCalls => pins.length;

  @override
  Future<Either<Failure, AppPinStatus>> verifyAppPin({
    required String pin,
  }) async {
    pins.add(pin);
    return results[pins.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SequencedPinStatusSecurityRepository implements SecurityRepository {
  final List<AppPinStatus> statuses;
  int statusCalls = 0;

  _SequencedPinStatusSecurityRepository(this.statuses);

  @override
  Future<Either<Failure, AppPinStatus>> getAppPinStatus() async {
    final index = statusCalls.clamp(0, statuses.length - 1);
    statusCalls += 1;
    return Right(statuses[index]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _testUser = User(
  id: 'user-1',
  username: 'satoshi',
  createdAt: DateTime(2026, 1, 1),
);
