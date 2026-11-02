import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_progress.dart';
import 'package:kerosene/features/home/presentation/screens/home_loading_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import '../../goldens/golden_harness.dart';

void main() {
  setUpAll(initializeGoldenHarness);
  late SharedPreferences prefs;
  late _TrackingAuthController auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = _TrackingAuthController();
  });

  Future<void> pump(WidgetTester tester, WalletState result) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeLoadingScreen()),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
          path: '/onboarding/first-access',
          builder: (_, __) => const Scaffold(body: Text('CHOOSE_ACCOUNT'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(() => auth),
          sessionStorageScopeProvider.overrideWithValue('session-user-1'),
          authLocalDataSourceProvider.overrideWithValue(_Local()),
          appColdStartProvider.overrideWith(_TorReady.new),
          walletProvider.overrideWith(() => _Wallets(result)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        )));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('wallet loading failure reaches Home without logging out',
      (tester) async {
    await pump(tester, const WalletError('Unavailable', statusCode: 503));
    expect(find.text('HOME'), findsOneWidget);
    expect(auth.logoutCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new user without accounts reaches the first account choice',
      (tester) async {
    await pump(tester, const WalletLoaded(wallets: [], btcToUsdRate: 0));
    expect(find.text('CHOOSE_ACCOUNT'), findsOneWidget);
    expect(auth.logoutCalls, 0);
  });
  testWidgets('explore completion keeps the real empty Home accessible',
      (tester) async {
    await FirstAccessProgress.complete(prefs, 'user-1');
    await pump(tester, const WalletLoaded(wallets: [], btcToUsdRate: 0));
    expect(find.text('HOME'), findsOneWidget);
  });
  testWidgets(
      'wallet network failure cannot skip a pending first-access checkpoint',
      (tester) async {
    await FirstAccessProgress.markPending(prefs, 'user-1');
    await pump(tester, const WalletError('Unavailable', statusCode: 503));
    expect(find.text('CHOOSE_ACCOUNT'), findsOneWidget);
    expect(auth.logoutCalls, 0);
  });
}

class _Local implements AuthLocalDataSource {
  @override
  Future<String?> getToken() async => 'public.fixture.jwt';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TorReady extends AppColdStartNotifier {
  @override
  AppColdStartState build() => const AppColdStartState(torSettled: true);
}

class _TrackingAuthController extends AuthController {
  int logoutCalls = 0;
  @override
  AuthState build() => AuthAuthenticated(_testUser);
  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthUnauthenticated();
  }
}

class _Wallets extends WalletNotifier {
  _Wallets(this.result);
  final WalletState result;
  @override
  WalletState build() => const WalletInitial();
  @override
  Future<void> refresh() async {
    // Match the real refresh lifecycle so every failed attempt is observable.
    state = const WalletLoading();
    await Future<void>.value();
    state = result;
  }
}

final _testUser =
    User(id: 'user-1', username: 'satoshi', createdAt: DateTime(2026, 1, 1));
