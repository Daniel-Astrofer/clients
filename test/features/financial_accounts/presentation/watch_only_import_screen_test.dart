import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/app/security/payment_security_guards.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/cold_wallet_success_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/watch_only_import_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/wallet_setup_hub_screen.dart';

const _publicKey =
    'xpub6CatWdiZiodmUeTDp8LT5or8nmbKNcuyvz7WyksVFkKB4RHwCD3XyuvPEbvqAQY3rAPshWcMLoP2fMFMKHPJ4ZeZXYVUhLv1VMrjPC7PW6V';
BitcoinAccount _account() => BitcoinAccount.fromJson({
      'id': 'registered-public-wallet',
      'type': 'WATCH_ONLY',
      'status': 'ACTIVE',
      'label': 'Hardware wallet'
    });

class _ImportNotifier extends BitcoinAccountsNotifier {
  int calls = 0;
  int refreshCalls = 0;
  Map<String, String>? payload;
  final Completer<BitcoinAccount>? pending;
  final bool fail;
  final bool capacity;
  _ImportNotifier({this.pending, this.fail = false, this.capacity = false});
  @override
  Future<List<BitcoinAccount>> build() async => [];
  @override
  Future<void> refresh() async {
    refreshCalls++;
    state = AsyncData(await build());
  }

  @override
  Future<BitcoinAccount> importColdWallet(
      {required String label,
      required String xpub,
      required String fingerprint,
      required String derivationPath,
      required String scriptPolicy}) async {
    calls++;
    payload = {
      'label': label,
      'xpub': xpub,
      'fingerprint': fingerprint,
      'path': derivationPath,
      'policy': scriptPolicy
    };
    if (capacity) {
      throw const ValidationException(
          message: 'Local limit',
          errorCode: 'ERR_WALLET_CUSTODY_ALREADY_EXISTS');
    }
    if (fail) throw const NetworkException();
    if (pending != null) return pending!.future;
    return _account();
  }
}

Widget _app(_ImportNotifier notifier,
        {Widget page = const WatchOnlyImportScreen()}) =>
    ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('public-import-test'),
          bitcoinAccountsByScopeProvider.overrideWith2((_) => notifier)
        ],
        child: MaterialApp(
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page));

Future<void> _fill(WidgetTester tester, {String key = _publicKey}) async {
  await tester.enterText(
      find.byKey(const ValueKey('public-wallet-label')), 'Hardware wallet');
  await tester.enterText(find.byKey(const ValueKey('public-wallet-key')), key);
  await tester.enterText(
      find.byKey(const ValueKey('public-wallet-fingerprint')), '73C5DA0A');
  await tester.enterText(
      find.byKey(const ValueKey('public-wallet-path')), "m/84'/0'/0'");
  await tester.ensureVisible(find.text('Importar para consulta'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });
  setUp(() => expectedBitcoinNetworkOverride = BitcoinNetworkKind.mainnet);
  tearDown(() => expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet);

  testWidgets('private keys are rejected before any registration call',
      (tester) async {
    final notifier = _ImportNotifier();
    await tester.pumpWidget(_app(notifier));
    await _fill(tester, key: 'xprvprivate-fixture');
    await tester.tap(find.text('Importar para consulta'));
    await tester.pump();
    expect(notifier.calls, 0);
    expect(
        find.textContaining('Foi inserida uma chave privada'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('public-wallet-key')))
            .controller
            ?.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration blocks repeated taps and native back while pending',
      (tester) async {
    final pending = Completer<BitcoinAccount>();
    final notifier = _ImportNotifier(pending: pending);
    await tester.pumpWidget(_app(notifier));
    expect(
        ProviderScope.containerOf(
                tester.element(find.byType(WatchOnlyImportScreen)))
            .read(bitcoinAccountsControllerProvider),
        same(notifier));
    await _fill(tester);
    await tester.tap(find.text('Importar para consulta'));
    await tester.tap(find.text('Importar para consulta'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(notifier.calls, 1);
    expect(find.byType(WatchOnlyImportScreen), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(notifier.payload?['xpub'], _publicKey);
    expect(notifier.payload?['fingerprint'], '73c5da0a');
    expect(notifier.payload?['policy'],
        'wpkh([73c5da0a/84h/0h/0h]$_publicKey/0/*)');
    pending.complete(_account());
    await tester.pumpAndSettle();
    expect(find.byType(ColdWalletSuccessScreen), findsOneWidget);
    expect(find.textContaining('somente com dados públicos'), findsOneWidget);
    expect(find.textContaining('não foi salva'), findsNothing);
    expect(find.text('Enviar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final capacity in [false, true]) {
    testWidgets(
        'failed registration keeps data and offers checking wallets: $capacity',
        (tester) async {
      final notifier = _ImportNotifier(fail: !capacity, capacity: capacity);
      await tester.pumpWidget(_app(notifier));
      await _fill(tester);
      await tester.tap(find.text('Importar para consulta'));
      await tester.pumpAndSettle();
      expect(notifier.calls, 1);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('public-wallet-key')))
              .controller
              ?.text,
          _publicKey);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(find.text('Ver minhas carteiras'), findsOneWidget);
      expect(
          find.textContaining(
              capacity ? 'no máximo duas' : 'pode ter sido concluído'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'hub public import can finish receiving with the registered wallet',
      (tester) async {
    final notifier = _ImportNotifier();
    final router = GoRouter(initialLocation: '/setup', routes: [
      GoRoute(path: '/setup', builder: (_, __) => const WalletSetupHubScreen()),
      GoRoute(
          path: '/receive',
          builder: (_, state) => Scaffold(
              body:
                  Text('Receiving ${state.uri.queryParameters['walletId']}'))),
      GoRoute(
          path: '/accounts',
          builder: (_, __) => const Scaffold(body: Text('Accounts'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('public-import-test'),
          bitcoinAccountsByScopeProvider.overrideWith2((_) => notifier)
        ],
        child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.text('Receber e consultar com a chave pública da conta'));
    await tester
        .tap(find.text('Receber e consultar com a chave pública da conta'));
    await tester.pumpAndSettle();
    await _fill(tester);
    await tester.tap(find.text('Importar para consulta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Receber'));
    await tester.tap(find.text('Receber'));
    await tester.pumpAndSettle();
    expect(find.text('Receiving registered-public-wallet'), findsOneWidget);
    expect(notifier.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'an uncertain registration can navigate to the owned wallet list without resubmitting',
      (tester) async {
    final notifier = _ImportNotifier(fail: true);
    final router = GoRouter(initialLocation: '/import', routes: [
      GoRoute(
          path: '/import', builder: (_, __) => const WatchOnlyImportScreen()),
      GoRoute(
          path: '/accounts',
          builder: (_, __) => const Scaffold(body: Text('Owned wallet list'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('public-import-test'),
          bitcoinAccountsByScopeProvider.overrideWith2((_) => notifier)
        ],
        child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales)));
    await _fill(tester);
    await tester.tap(find.text('Importar para consulta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver minhas carteiras'));
    await tester.tap(find.text('Ver minhas carteiras'));
    await tester.pumpAndSettle();
    expect(find.text('Owned wallet list'), findsOneWidget);
    expect(notifier.refreshCalls, 1);
    expect(notifier.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form remains scrollable on a compact phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _ImportNotifier();
    await tester.pumpWidget(_app(notifier,
        page: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(1.5)),
            child: const WatchOnlyImportScreen())));
    await tester.ensureVisible(find.text('Importar para consulta'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(notifier.calls, 0);
  });
}
