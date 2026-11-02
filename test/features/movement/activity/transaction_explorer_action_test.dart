import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/blockchain_explorer.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_surface_provider.dart';
import '../../../goldens/golden_harness.dart';
import 'activity_actions_test.dart' show actionOwnerProvider;

Transaction explorerFixture(
        {String? address, String? hash, bool lightning = false}) =>
    Transaction(
      id: 'explorer-operation',
      fromAddress: 'Kerosene',
      toAddress: address ?? 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      amountSatoshis: 123,
      feeSatoshis: 0,
      status: TransactionStatus.confirmed,
      type: TransactionType.send,
      confirmations: 3,
      timestamp: DateTime(2020),
      blockchainTxid: hash ?? List.filled(4, 'abcdef0123456789').join(),
      isLightning: lightning,
    );

Future<ProviderContainer> pumpExplorer(WidgetTester tester, Transaction tx,
    BlockchainExplorerLauncher launcher) async {
  await pumpFullScreenGolden(
      tester,
      ProviderScope(overrides: [
        sessionStorageScopeProvider
            .overrideWith((ref) => ref.watch(actionOwnerProvider)),
        blockchainExplorerLauncherProvider.overrideWithValue(launcher),
      ], child: TransactionDetailScreen(transaction: tx)));
  return ProviderScope.containerOf(
      tester.element(find.byType(TransactionDetailScreen)));
}

Future<void> finishExplorer(WidgetTester tester) async {
  AppScreenFeedbackBus.clear();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final throws in [false, true]) {
    testWidgets('failed explorer launch is visible: exception=$throws',
        (tester) async {
      await pumpExplorer(tester, explorerFixture(), (_) async {
        if (throws) throw StateError('PRIVATE-LAUNCHER');
        return false;
      });
      await tester.tap(find.byKey(const ValueKey('transaction-explorer-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('transaction-explorer-error')),
          findsOneWidget);
      expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
      expect(AppScreenFeedbackBus.current.value?.message,
          contains('hash continua disponível'));
      expect(find.textContaining('PRIVATE-LAUNCHER'), findsNothing);
      await finishExplorer(tester);
    });
  }
  testWidgets('opening is single and success does not announce settlement',
      (tester) async {
    final gate = Completer<bool>();
    var calls = 0;
    await pumpExplorer(tester, explorerFixture(), (uri) {
      calls++;
      expect(uri.path, startsWith('/tx/'));
      return gate.future;
    });
    final callback = tester
        .widget<TextButton>(
            find.byKey(const ValueKey('transaction-explorer-open')))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(calls, 1);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(
        find.byKey(const ValueKey('transaction-explorer-error')), findsNothing);
    await finishExplorer(tester);
  });
  testWidgets(
      'old callbacks and late failures cannot act for a different account',
      (tester) async {
    final gate = Completer<bool>();
    var calls = 0;
    final container = await pumpExplorer(tester, explorerFixture(), (_) {
      calls++;
      return gate.future;
    });
    final callback = tester
        .widget<TextButton>(
            find.byKey(const ValueKey('transaction-explorer-open')))
        .onPressed!;
    callback();
    container.read(actionOwnerProvider.notifier).change('bob');
    await tester.pump();
    gate.complete(false);
    await tester.pumpAndSettle();
    callback();
    expect(calls, 1);
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(
        find.byKey(const ValueKey('transaction-explorer-error')), findsNothing);
    await finishExplorer(tester);
  });
  for (final address in [
    'tb1q${List.filled(32, 'q').join()}',
    'bcrt1q${List.filled(32, 'q').join()}',
    'unknown'
  ]) {
    testWidgets('unavailable explorer explains the reason: $address',
        (tester) async {
      var calls = 0;
      await pumpExplorer(tester, explorerFixture(address: address), (_) async {
        calls++;
        return true;
      });
      expect(
          tester
              .widget<TextButton>(
                  find.byKey(const ValueKey('transaction-explorer-open')))
              .onPressed,
          isNull);
      expect(find.byKey(const ValueKey('transaction-explorer-unavailable')),
          findsOneWidget);
      expect(calls, 0);
      await finishExplorer(tester);
    });
  }
  testWidgets('Lightning never exposes an on-chain explorer action',
      (tester) async {
    await pumpExplorer(
        tester, explorerFixture(lightning: true), (_) async => true);
    expect(
        find.byKey(const ValueKey('transaction-explorer-open')), findsNothing);
    await finishExplorer(tester);
  });
  testWidgets('an invalid hash stays visible but cannot open an external link',
      (tester) async {
    var calls = 0;
    await pumpExplorer(tester, explorerFixture(hash: 'not-a-bitcoin-hash'),
        (_) async {
      calls++;
      return true;
    });
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('transaction-explorer-open')))
            .onPressed,
        isNull);
    expect(find.textContaining('não é um hash Bitcoin válido'), findsOneWidget);
    expect(calls, 0);
    await finishExplorer(tester);
  });
  testWidgets('a captured action cannot open the explorer in background',
      (tester) async {
    var calls = 0;
    final container = await pumpExplorer(tester, explorerFixture(), (_) async {
      calls++;
      return true;
    });
    final callback = tester
        .widget<TextButton>(
            find.byKey(const ValueKey('transaction-explorer-open')))
        .onPressed!;
    container.read(appForegroundProvider.notifier).setForeground(false);
    callback();
    await tester.pump();
    expect(calls, 0);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('transaction-explorer-open')))
            .onPressed,
        isNull);
    container.read(appForegroundProvider.notifier).setForeground(true);
    await finishExplorer(tester);
  });
}
