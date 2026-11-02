import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_progress.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_screen.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import '../../../goldens/golden_harness.dart';

class _Auth extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(
      User(id: 'u', username: 'user', createdAt: DateTime(2026)));
  void logoutForTest() => state = const AuthUnauthenticated();
}

class _Wallets extends WalletNotifier {
  @override
  WalletState build() => const WalletInitial();
  @override
  Future<void> refresh() async {}
}

BitcoinAccount account(
        {String status = 'ACTIVE', String custody = 'CUSTODIAL_ONCHAIN'}) =>
    BitcoinAccount(
        id: 'a',
        type: 'ONCHAIN',
        custody: custody,
        status: status,
        label: 'Conta',
        riskTier: 'STANDARD');

class _Service implements BitcoinAccountsService {
  List<BitcoinAccount> accounts = [];
  int creates = 0;
  bool loseReply = false;
  bool pending = false;
  bool failRead = false;
  bool reject = false;
  bool failReadAfterCreate = false;
  Completer<BitcoinAccount>? delayed;
  @override
  Future<List<BitcoinAccount>> listAccounts() async {
    if (failRead) throw StateError('offline');
    return accounts;
  }

  @override
  Future<BitcoinAccount> createWallet(
      {required String label, required BitcoinAccountCustody custody}) async {
    creates++;
    if (reject) {
      throw const ServerException(message: 'Invalid label', statusCode: 422);
    }
    if (delayed != null) return delayed!.future;
    accounts = [account(status: pending ? 'PENDING' : 'ACTIVE')];
    failRead = failReadAfterCreate;
    if (loseReply) throw StateError('response lost');
    return accounts.single;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initializeGoldenHarness);
  late SharedPreferences prefs;
  late _Service service;
  late _Auth auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _Service();
    auth = _Auth();
  });
  Future<GoRouter> pump(WidgetTester tester,
      {double scale = 1, bool reduced = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const FirstAccessScreen()),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
          path: '/receive',
          builder: (_, __) => const Scaffold(body: Text('RECEIVE'))),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('LOGIN'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          sessionStorageScopeProvider.overrideWithValue('session-u'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          bitcoinAccountsServiceProvider.overrideWithValue(service),
          walletProvider.overrideWith(_Wallets.new),
        ],
        child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduced,
                    textScaler: TextScaler.linear(scale)),
                child: child!))));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('explore opens empty Home without creating financial data',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Conhecer o app primeiro');
    expect(find.text('HOME'), findsOneWidget);
    expect(service.creates, 0);
    expect(
        FirstAccessProgress.shouldShow(prefs, 'u', hasWallets: false), isFalse);
  });
  testWidgets(
      'creation requires server-active account before ready and receive',
      (tester) async {
    await pump(tester);
    await tap(tester, 'Conta on-chain');
    expect(service.creates, 1);
    expect(find.text('Sua conta está pronta'), findsOneWidget);
    await tap(tester, 'Receber');
    expect(find.text('RECEIVE'), findsOneWidget);
  });
  testWidgets('lost create reply reconciles without a duplicate POST',
      (tester) async {
    service.loseReply = true;
    await pump(tester);
    await tap(tester, 'Conta on-chain');
    expect(service.creates, 1);
    expect(find.text('Sua conta está pronta'), findsNothing);
    await tap(tester, 'Verificar disponibilidade');
    expect(service.creates, 1);
    expect(find.text('Sua conta está pronta'), findsOneWidget);
  });
  testWidgets('pending account never displays ready', (tester) async {
    service.pending = true;
    await pump(tester);
    await tap(tester, 'Conta on-chain');
    expect(find.text('Sua conta está pronta'), findsNothing);
    await tap(tester, 'Verificar disponibilidade');
    expect(service.creates, 1);
    expect(find.text('Sua conta está pronta'), findsNothing);
  });
  testWidgets('saved ready checkpoint is reconciled, never trusted locally',
      (tester) async {
    await FirstAccessProgress.ready(prefs, 'u');
    await pump(tester);
    expect(find.text('Sua conta está pronta'), findsNothing);
    await tap(tester, 'Verificar disponibilidade');
    expect(service.creates, 0);
    expect(find.text('Sua conta está pronta'), findsNothing);
  });
  testWidgets('late result after logout cannot persist ready or navigate',
      (tester) async {
    service.delayed = Completer();
    await pump(tester);
    await tester.tap(find.text('Conta on-chain'));
    await tester.pump();
    auth.logoutForTest();
    await tester.pump();
    service.delayed!.complete(account());
    await tester.pumpAndSettle();
    expect(FirstAccessProgress.isReady(prefs, 'u'), isFalse);
    expect(find.text('Ir para a Home'), findsNothing);
    expect(find.text('Entrar na conta'), findsOneWidget);
  });
  testWidgets('large text with motion remains scrollable and operable',
      (tester) async {
    await pump(tester, scale: 2, reduced: false);
    await tap(tester, 'Conhecer o app primeiro');
    expect(find.text('HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ready watch-only checkpoint resumes without creating onchain',
      (tester) async {
    service.accounts = [account(custody: 'WATCH_ONLY')];
    await FirstAccessProgress.ready(prefs, 'u');
    await pump(tester);
    await tap(tester, 'Verificar disponibilidade');
    expect(find.text('Sua conta está pronta'), findsOneWidget);
    expect(find.text('Receber'), findsNothing);
    expect(service.creates, 0);
  });
  testWidgets('failed inventory refresh never announces ready from stale data',
      (tester) async {
    service.failReadAfterCreate = true;
    await pump(tester);
    await tap(tester, 'Conta on-chain');
    expect(find.text('Sua conta está pronta'), findsNothing);
    service.failRead = false;
    await tap(tester, 'Verificar disponibilidade');
    expect(find.text('Sua conta está pronta'), findsOneWidget);
    expect(service.creates, 1);
  });
  testWidgets(
      'explicit rejection allows correction without automatic POST retry',
      (tester) async {
    service.reject = true;
    await pump(tester);
    await tap(tester, 'Conta on-chain');
    expect(find.text('Conta on-chain'), findsOneWidget);
    expect(service.creates, 1);
    expect(FirstAccessProgress.isPendingCreation(prefs, 'u'), isFalse);
    service.reject = false;
    await tap(tester, 'Conta on-chain');
    expect(service.creates, 2);
    expect(find.text('Sua conta está pronta'), findsOneWidget);
  });
  testWidgets('snapshot choice and ready use real widgets', (tester) async {
    await pump(tester);
    await expectLater(
        find.byType(FirstAccessScreen),
        matchesGoldenFile(
            '../../../goldens/goldens/first_access_choice_dark.png'));
    await tap(tester, 'Conta on-chain');
    await expectLater(
        find.byType(FirstAccessScreen),
        matchesGoldenFile(
            '../../../goldens/goldens/first_access_ready_dark.png'));
  });
  testWidgets('watch-only choice carries the optional name into public import',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Minha Ledger');
    await tap(tester, 'Conta de visualização');
    final field = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('public-wallet-label')),
        matching: find.byType(TextField)));
    expect(field.controller!.text, 'Minha Ledger');
    expect(service.creates, 0);
  });
}
