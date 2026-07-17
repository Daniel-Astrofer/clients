import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/presentation/widgets/tor_loading_dots.dart';
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
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Digite o PIN para acessar sua conta'), findsOneWidget);
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

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_testUser);
}

class _TorReadyColdStart extends AppColdStartNotifier {
  @override
  AppColdStartState build() {
    return const AppColdStartState(
      torSettled: true,
      minSplashElapsed: true,
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
