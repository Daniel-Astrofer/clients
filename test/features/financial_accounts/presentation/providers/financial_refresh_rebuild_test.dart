import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/financial_accounts/domain/repositories/ledger_repository.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_refresh.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/external_transfer.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_data_providers.dart'
    as movement;
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show transactionHistoryCursorProvider;

final _signal = NotifierProvider<_Signal, int>(_Signal.new);

class _Signal extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

final _refreshDriver = FutureProvider<bool>((ref) async {
  if (ref.watch(_signal) == 0) return false;
  return refreshFinancialProjection(ref, scope: FinancialRefreshScope.light);
});
final _request = Provider((ref) => ({bool force = false}) =>
    refreshFinancialProjection(ref,
        scope: FinancialRefreshScope.light, forceFullHistory: force));

class _Auth extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(
      User(id: '42', username: 'fixture', createdAt: DateTime(2026)));
  void signOut() => state = const AuthUnauthenticated();
}

class _Wallet extends WalletNotifier {
  int refreshes = 0;
  Completer<void>? pending;
  @override
  WalletState build() => const WalletLoaded(wallets: [], btcToUsdRate: 0);
  @override
  Future<void> refresh() async {
    refreshes++;
    await pending?.future;
  }
}

class _Ledger implements LedgerRepository {
  int reads = 0;
  @override
  Future<Either<Failure, List<Transaction>>> getHistory(
      {int page = 0, int size = 50, DateTime? since}) async {
    reads++;
    return const Right([]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Movements implements TransactionRepository {
  @override
  Future<List<PaymentLink>> getPaymentLinks() async => [];
  @override
  Future<List<ExternalTransfer>> getExternalTransfers() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _History extends LocalTransactionHistoryStore {
  _History() : super(SecureStorageService());
  @override
  Future<List<Transaction>> load(String sessionScope) async => [];
  @override
  Future<void> save(String sessionScope, List<Transaction> rows) async {}
}

void main() {
  ProviderContainer scope(_Ledger ledger, _Wallet wallet) => ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_Auth.new),
          walletProvider.overrideWith(() => wallet),
          ledgerRepositoryProvider.overrideWithValue(ledger),
          movement.transactionRepositoryProvider
              .overrideWithValue(_Movements()),
          localTransactionHistoryStoreProvider.overrideWithValue(_History()),
        ],
      );

  test('same-turn refresh requests share one wallet and history pull',
      () async {
    final ledger = _Ledger(), wallet = _Wallet();
    final container = scope(ledger, wallet);
    addTearDown(container.dispose);
    final request = container.read(_request);
    final results = await Future.wait(List.generate(8, (_) => request()));
    expect(results, everyElement(isTrue));
    expect(wallet.refreshes, 1);
    expect(ledger.reads, 1);
  });

  test('events during I/O cause one follow-up without overlapping requests',
      () async {
    final ledger = _Ledger(), wallet = _Wallet()..pending = Completer<void>();
    final container = scope(ledger, wallet);
    addTearDown(container.dispose);
    final request = container.read(_request);
    final first = request();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(wallet.refreshes, 1);
    final later = List.generate(5, (_) => request());
    expect(wallet.refreshes, 1);
    wallet.pending!.complete();
    expect(await Future.wait([first, ...later]), everyElement(isTrue));
    expect(wallet.refreshes, 2);
    expect(ledger.reads, 2);
  });

  test('sign-out before scheduled refresh prevents all reads', () async {
    final ledger = _Ledger(), wallet = _Wallet();
    final container = scope(ledger, wallet);
    addTearDown(container.dispose);
    final pending = container.read(_request)();
    (container.read(authControllerProvider.notifier) as _Auth).signOut();
    expect(await pending, isFalse);
    expect(wallet.refreshes, 0);
    expect(ledger.reads, 0);
  });

  test('a forced refresh in the same burst resets the incremental checkpoint',
      () async {
    final ledger = _Ledger(), wallet = _Wallet();
    final container = scope(ledger, wallet);
    addTearDown(container.dispose);
    container.read(transactionHistoryCursorProvider.notifier).advance([
      Transaction(
          id: 'checkpoint',
          fromAddress: '',
          toAddress: '',
          amountSatoshis: 1,
          feeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.receive,
          confirmations: 6,
          timestamp: DateTime.utc(2026, 10, 10)),
    ]);
    expect(container.read(transactionHistoryCursorProvider), isNotNull);
    final request = container.read(_request);
    expect(await Future.wait([request(), request(force: true), request()]),
        everyElement(isTrue));
    expect(container.read(transactionHistoryCursorProvider), isNull);
    expect(ledger.reads, 1);
  });

  test('account changes during wallet I/O prevent history reads and success',
      () async {
    final ledger = _Ledger(), wallet = _Wallet()..pending = Completer<void>();
    final container = scope(ledger, wallet);
    addTearDown(container.dispose);
    final pending = container.read(_request)();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    (container.read(authControllerProvider.notifier) as _Auth).signOut();
    wallet.pending!.complete();
    expect(await pending, isFalse);
    expect(ledger.reads, 0);
  });

  testWidgets(
      'refresh triggered by a provider rebuild preserves repository and loads history',
      (tester) async {
    final ledger = _Ledger();
    var builds = 0;
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_Auth.new),
          walletProvider.overrideWith(_Wallet.new),
          ledgerRepositoryProvider.overrideWith((ref) {
            ref.watch(_signal);
            builds++;
            return ledger;
          }),
          movement.transactionRepositoryProvider
              .overrideWithValue(_Movements()),
          localTransactionHistoryStoreProvider.overrideWithValue(_History()),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          ref.watch(ledgerRepositoryProvider);
          final result = ref.watch(_refreshDriver);
          return Scaffold(
              body: Column(children: [
            Text('$result'),
            TextButton(
                onPressed: () => ref.read(_signal.notifier).trigger(),
                child: const Text('Abrir envio')),
          ]));
        }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir envio'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(_refreshDriver).requireValue, isTrue);
    expect(builds, 2, reason: 'One initial build and one dependency change');
    expect(ledger.reads, 1);
  });
}
