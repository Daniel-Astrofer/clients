import 'package:kerosene/design_system/components/feedback/app_screen_feedback_host.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import 'package:kerosene/features/financial_accounts/presentation/financial_hub_flow/sheets/wallet_manage_bottom_sheet.dart';
import 'package:kerosene/features/security/presentation/screens/settings_wallets_pane.dart';

BitcoinAccount _wallet({int funds = 0, int pending = 0, bool watch = false}) =>
    BitcoinAccount.fromJson({
      'id': 'wallet-1',
      'cardId': 'wallet-1',
      'label': 'Reserva principal',
      'status': 'ACTIVE',
      'type': watch ? 'WATCH_ONLY_COLD_WALLET' : 'INTERNAL_CARD',
      'custody': watch ? 'WATCH_ONLY' : 'INTERNAL',
      'balanceAvailableSats': funds,
      'balancePendingSats': pending,
      'observedBalanceSats': funds,
      'updatedAt': '2026-10-10T10:00:00Z',
    });

class _Service implements BitcoinAccountsService {
  final bool fail;
  int calls = 0;
  Completer<BitcoinAccount>? delayed;
  _Service({this.fail = false});
  @override
  Future<List<BitcoinAccount>> listAccounts() async => [_wallet()];
  @override
  Future<BitcoinAccount> renameWallet(
      {required String accountId, required String label}) async {
    calls++;
    if (fail) throw const NetworkException();
    if (delayed != null) return delayed!.future;
    return BitcoinAccount.fromJson({
      ..._wallet().toJson(),
      'label': 'Nome confirmado',
      'updatedAt': '2026-10-10T10:01:00Z'
    });
  }

  @override
  Future<BitcoinAccount> archiveWallet(String accountId) async {
    calls++;
    if (fail) throw const NetworkException();
    return BitcoinAccount.fromJson({
      ..._wallet().toJson(),
      'status': 'ARCHIVED',
      'updatedAt': '2026-10-10T10:01:00Z'
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _material(Widget page) => MaterialApp(
      builder: (context, child) => AppScreenFeedbackHost(child: child!),
    locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: page)));
Widget _app(_Service service, {Widget page = const SettingsWalletsPane()}) =>
    ProviderScope(overrides: [
      sessionStorageScopeProvider.overrideWithValue('owner'),
      bitcoinAccountsServiceProvider.overrideWithValue(service),
    ], child: _material(page));

Future<void> _choose(WidgetTester tester, String action) async {
  await tester.tap(find.text('Reserva principal').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });
  for (final fail in [false, true]) {
    testWidgets(
        'rename reports real result and keeps the wallet visible: $fail',
        (tester) async {
      final service = _Service(fail: fail);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _choose(tester, 'Trocar nome');
      await tester.enterText(find.byType(TextField), 'Nome pedido');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      if (fail) {
        expect(find.text('Reserva principal'), findsOneWidget);
        expect(find.text('Nome atualizado'), findsNothing);
        expect(find.textContaining('últimos dados conhecidos'), findsOneWidget);
        expect(find.text('Alteração não confirmada'), findsOneWidget);
      } else {
        expect(find.text('Nome confirmado'), findsWidgets);
        expect(find.text('Nome pedido'), findsNothing);
      }
      await _finish(tester);
    });
    testWidgets(
        'archive reports real result and removes only confirmed archived wallet: $fail',
        (tester) async {
      final service = _Service(fail: fail);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await _choose(tester, 'Arquivar carteira');
      expect(find.text('Reserva principal'), findsWidgets);
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      if (fail) {
        expect(find.text('Carteira arquivada'), findsNothing);
        expect(find.text('Arquivamento não confirmado'), findsOneWidget);
        expect(find.text('Reserva principal'), findsOneWidget);
      } else {
        expect(find.text('Nenhuma carteira ativa'), findsOneWidget);
      }
      await _finish(tester);
    });
  }
  testWidgets('name dialog prevents an empty or unchanged update',
      (tester) async {
    await tester
        .pumpWidget(_material(const WalletNameDialog(initialName: 'Original')));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Novo nome');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await _finish(tester);
  });
  for (final pending in [0, 1000]) {
    testWidgets(
        'custodial funds or holds prevent archive confirmation: $pending',
        (tester) async {
      await tester.pumpWidget(_material(Builder(
          builder: (context) => TextButton(
              onPressed: () => confirmWalletArchive(context,
                  _wallet(funds: pending == 0 ? 1000 : 0, pending: pending)),
              child: const Text('Open')))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Há saldo ou movimentações'), findsOneWidget);
      expect(find.text('CONFIRMAR'), findsNothing);
      await _finish(tester);
    });
  }
  testWidgets(
      'watch-only archive preserves the explicit external-funds explanation',
      (tester) async {
    await tester.pumpWidget(_material(Builder(
        builder: (context) => TextButton(
            onPressed: () => confirmWalletArchive(
                context, _wallet(funds: 1000, watch: true)),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('fundos continuam'), findsOneWidget);
    expect(find.text('CONFIRMAR'), findsOneWidget);
    await _finish(tester);
  });
  testWidgets(
      'wallet management hides original actor data after a session change',
      (tester) async {
    final service = _Service();
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('owner'),
      bitcoinAccountsServiceProvider.overrideWithValue(service)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _material(WalletManageBottomSheet(account: _wallet()))));
    await tester.pumpAndSettle();
    expect(find.text('Reserva principal'), findsOneWidget);
    expect(find.text('wallet-1'), findsOneWidget);
    container.updateOverrides([
      sessionStorageScopeProvider.overrideWithValue('other'),
      bitcoinAccountsServiceProvider.overrideWithValue(service)
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Reserva principal'), findsNothing);
    expect(find.text('wallet-1'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    await _finish(tester);
  });
}
