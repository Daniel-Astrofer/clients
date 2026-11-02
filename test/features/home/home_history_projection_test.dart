import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_transactions.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart'
    show HomeGlassPanel;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../../goldens/golden_harness.dart';

class _Wallets extends WalletNotifier {
  @override
  WalletState build() => const WalletInitial();
}

class _Archive extends ActivityArchiveNotifier {
  @override
  Set<String> build() => {};
}

Transaction _row(String id, {bool confirmed = false, int debit = 100000}) =>
    Transaction(
      id: id,
      fromAddress: 'source',
      toAddress: 'destination',
      amountSatoshis: 100000,
      feeSatoshis: 1000,
      totalDebitedSatoshis: debit,
      status:
          confirmed ? TransactionStatus.confirmed : TransactionStatus.pending,
      type: TransactionType.send,
      confirmations: confirmed ? 3 : 0,
      timestamp: DateTime.utc(2026, 10, 16),
      updatedAt: DateTime.utc(2026, 10, confirmed ? 17 : 16),
      rail: 'ONCHAIN',
    );

void main() {
  setUpAll(initializeGoldenHarness);

  testWidgets('Home replaces a cached card when the recorded debit changes',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        Scaffold(
            body: SingleChildScrollView(
          child: HomeTransactionsList(
              onCreateWallet: () {}, onDepositWallet: (_) {}),
        )),
        size: const Size(390, 1000));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeTransactionsList)));
    container
        .read(lastTransactionHistoryProvider.notifier)
        .upsertFront(_row('live'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('0.00100000 BTC'), findsOneWidget);
    expect(find.byType(HomeGlassPanel), findsNothing,
        reason: 'Original Home cards are independent, without an outer panel.');
    container
        .read(lastTransactionHistoryProvider.notifier)
        .upsertFront(_row('live', debit: 110000));
    await tester.pump();
    expect(find.textContaining('0.00110000 BTC'), findsOneWidget);
    expect(find.textContaining('0.00100000 BTC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Home applies live confirmation and new rows while REST remains cached',
      () async {
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('user_home_fixture'),
      transactionHistoryProvider.overrideWith((ref) async => [_row('sent')]),
      walletProvider.overrideWith(_Wallets.new),
      bitcoinAccountsProvider.overrideWith((ref) => const AsyncData([])),
      activityArchiveProvider.overrideWith(_Archive.new),
    ]);
    addTearDown(container.dispose);
    await container.read(transactionHistoryProvider.future);
    expect(container.read(filteredHomeTransactionsProvider).single.status,
        TransactionStatus.pending);
    container.read(lastTransactionHistoryProvider.notifier)
      ..upsertFront(_row('sent', confirmed: true))
      ..upsertFront(_row('received', confirmed: true));
    final rows = container.read(filteredHomeTransactionsProvider);
    expect(rows, hasLength(2));
    final sent = rows.singleWhere((row) => row.id == 'sent');
    expect(sent.confirmations, 3);
    expect(sent.signedDisplaySatoshis, 100000);
    expect(sent.status, TransactionStatus.confirmed);

    container.read(homeActivityFilterProvider.notifier).state =
        HomeActivityFilter.pending;
    expect(container.read(filteredHomeTransactionsProvider), isEmpty);
  });
}
