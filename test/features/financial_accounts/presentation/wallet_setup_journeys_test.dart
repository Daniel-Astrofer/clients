import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/seed_word_entry_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/wallet_setup_hub_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/cold_wallet_success_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';

Widget app(Widget page, {double textScale = 1}) => ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('wallet-setup-test')
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: page,
        ));

void compact(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
      'view-only success can continue to receive with its registered wallet',
      (tester) async {
    ColdWalletFlowOutcome? received;
    final result = RegisterColdWalletResult(
        walletId: 'wallet',
        account: BitcoinAccount.fromJson(
            {'id': 'wallet', 'type': 'WATCH_ONLY', 'label': 'Reserve'}),
        material: const ColdWalletPublicMaterial(
            xpub: 'public-fixture', fingerprint: '00000000'),
        seedStored: false);
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () async {
                  received = await Navigator.of(context)
                      .push<ColdWalletFlowOutcome>(MaterialPageRoute(
                          builder: (_) => ColdWalletSuccessScreen(
                              result: result, walletLabel: 'Reserve')));
                },
                child: const Text('Open success'))))));
    await tester.tap(find.text('Open success'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receber'));
    await tester.pumpAndSettle();
    expect(received?.walletId, 'wallet');
    expect(received?.openReceive, isTrue);
    expect(received?.openSend, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native back from success returns the registered wallet outcome',
      (tester) async {
    ColdWalletFlowOutcome? received;
    final result = RegisterColdWalletResult(
        account: BitcoinAccount.fromJson(
            {'id': 'wallet', 'type': 'WATCH_ONLY', 'label': 'Reserve'}),
        walletId: 'wallet',
        material: const ColdWalletPublicMaterial(
            xpub: 'public-fixture', fingerprint: '00000000'),
        seedStored: false);
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () async {
                  received = await Navigator.of(context)
                      .push<ColdWalletFlowOutcome>(MaterialPageRoute(
                          builder: (_) => ColdWalletSuccessScreen(
                              result: result, walletLabel: 'Reserve')));
                },
                child: const Text('Open success'))))));
    await tester.tap(find.text('Open success'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(received?.walletId, 'wallet');
    expect(received?.openSend, isFalse);
    expect(find.byType(ColdWalletSuccessScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backgrounding conceals the phrase and requires explicit reveal after resume',
      (tester) async {
    await tester.pumpWidget(app(const SeedWordEntryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colar frase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,
        '${List.filled(11, 'abandon').join(' ')} about');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('Frase oculta'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Mostrar palavras'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        contains('about'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'registration blocks repeated actions and retains a validated phrase for retry',
      (tester) async {
    final requests = _RegistrationRequests();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('wallet-setup-test'),
          bitcoinAccountsByScopeProvider
              .overrideWith2((_) => _RegistrationAccounts(requests))
        ],
        child: app(Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                            builder: (_) => const WalletSetupHubScreen())),
                    child: const Text('Open setup')))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar carteira'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colar frase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first,
        '${List.filled(11, 'abandon').join(' ')} about');
    await tester.ensureVisible(find.text('Validar e continuar'));
    await tester.tap(find.text('Validar e continuar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Importar carteira').last);
    await tester.tap(find.text('Importar carteira').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests.calls, 1);
    // Native back must not dismiss an in-flight registration.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WalletSetupHubScreen), findsOneWidget);
    expect(requests.calls, 1);
    requests.pending.first.completeError(StateError('server unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Retomar importação'), findsOneWidget);
    await tester.tap(find.text('Retomar importação'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SeedWordEntryScreen), findsNothing);
    expect(requests.calls, 2);
    requests.pending.last.complete(BitcoinAccount.fromJson({
      'id': 'registered-wallet',
      'label': 'Carteira importada',
      'type': 'WATCH_ONLY',
      'status': 'ACTIVE'
    }));
    await tester.pumpAndSettle();
    expect(find.byType(ColdWalletSuccessScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'wallet setup choices remain readable on a compact phone with larger text',
      (tester) async {
    compact(tester);
    await tester.pumpWidget(app(const WalletSetupHubScreen(), textScale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'paste mode can validate a public test phrase without layout errors',
      (tester) async {
    compact(tester);
    await tester.pumpWidget(app(const SeedWordEntryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colar frase'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first,
        '${List.filled(11, 'abandon').join(' ')} about');
    await tester.ensureVisible(find.text('Validar e continuar'));
    await tester.tap(find.text('Validar e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Importar carteira'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RegistrationRequests {
  int calls = 0;
  final pending = <Completer<BitcoinAccount>>[];
}

class _RegistrationAccounts extends BitcoinAccountsNotifier {
  _RegistrationAccounts(this.requests);
  final _RegistrationRequests requests;
  @override
  Future<List<BitcoinAccount>> build() async => [];
  @override
  Future<BitcoinAccount> importColdWallet(
      {required String label,
      required String xpub,
      required String fingerprint,
      required String derivationPath,
      required String scriptPolicy}) {
    requests.calls++;
    final pending = Completer<BitcoinAccount>();
    requests.pending.add(pending);
    return pending.future;
  }
}
