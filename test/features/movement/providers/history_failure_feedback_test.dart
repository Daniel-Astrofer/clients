import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/domain/repositories/ledger_repository.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show ledgerRepositoryProvider;
import 'package:kerosene/features/movement/data/entities/external_transfer.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailableLedger implements LedgerRepository {
  Either<Failure, List<Transaction>> result =
      const Left(ServerFailure(message: 'history unavailable'));

  @override
  Future<Either<Failure, List<Transaction>>> getHistory(
          {int page = 0, int size = 50, DateTime? since}) async =>
      result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingExtras implements TransactionRepository {
  final transfers = Completer<List<ExternalTransfer>>();
  final links = Completer<List<PaymentLink>>();

  @override
  Future<List<ExternalTransfer>> getExternalTransfers() => transfers.future;
  @override
  Future<List<PaymentLink>> getPaymentLinks() => links.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _History extends LocalTransactionHistoryStore {
  _History(this.rows) : super(SecureStorageService());
  List<Transaction> rows;

  @override
  Future<List<Transaction>> load(String sessionScope) async => rows;

  @override
  Future<void> save(String sessionScope, List<Transaction> value) async {
    rows = List.of(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final cached in [false, true]) {
    test('primary history failure resolves with pending extras, cache=$cached',
        () async {
      final extras = _PendingExtras();
      final rows = cached
          ? [
              Transaction(
                id: 'known-history-row',
                fromAddress: 'source',
                toAddress: 'destination',
                amountSatoshis: 123,
                feeSatoshis: 0,
                status: TransactionStatus.confirmed,
                type: TransactionType.send,
                confirmations: 1,
                timestamp: DateTime.utc(2026, 10, 17),
                updatedAt: DateTime.utc(2026, 10, 17),
              ),
            ]
          : <Transaction>[];
      final container = ProviderContainer(overrides: [
        sessionStorageScopeProvider.overrideWithValue('user_fixture'),
        ledgerRepositoryProvider.overrideWithValue(_UnavailableLedger()),
        transactionRepositoryProvider.overrideWithValue(extras),
        localTransactionHistoryStoreProvider.overrideWithValue(_History(rows)),
      ]);
      addTearDown(() {
        extras.transfers.complete([]);
        extras.links.complete([]);
        container.dispose();
      });

      final result = container
          .read(transactionHistoryProvider.future)
          .timeout(const Duration(seconds: 1));
      if (cached) {
        expect(await result, rows);
        expect(container.read(lastTransactionHistoryProvider), rows);
      } else {
        await expectLater(
          result,
          throwsA(predicate((Object error) =>
              error is! TimeoutException &&
              error.toString().contains('history unavailable'))),
        );
      }
      expect(extras.transfers.isCompleted, isFalse);
      expect(extras.links.isCompleted, isFalse);
      expect(container.read(transactionHistoryLastSyncProvider), isNull);
      expect(
          container.read(transactionHistoryReadinessProvider).failed, isTrue);
    });
  }

  for (final page in [0, 1]) {
    test(
        'page $page exposes a primary failure without automatic provider retry',
        () async {
      final extras = _PendingExtras();
      final container = ProviderContainer(overrides: [
        sessionStorageScopeProvider.overrideWithValue('user_fixture'),
        ledgerRepositoryProvider.overrideWithValue(_UnavailableLedger()),
        transactionRepositoryProvider.overrideWithValue(extras),
        localTransactionHistoryStoreProvider.overrideWithValue(_History([])),
      ]);
      addTearDown(() {
        extras.transfers.complete([]);
        extras.links.complete([]);
        container.dispose();
      });
      await expectLater(
        container
            .read(
                pagedTransactionHistoryProvider((page: page, size: 50)).future)
            .timeout(const Duration(seconds: 1)),
        throwsA(predicate((Object error) =>
            error is! TimeoutException &&
            error.toString().contains('history unavailable'))),
      );
    });
  }

  test('failed refresh preserves a newer live row over the disk snapshot',
      () async {
    Transaction row(TransactionStatus status, DateTime updatedAt) =>
        Transaction(
          id: 'same-operation',
          fromAddress: 'source',
          toAddress: 'destination',
          amountSatoshis: 123,
          feeSatoshis: 0,
          status: status,
          type: TransactionType.receive,
          confirmations: status == TransactionStatus.confirmed ? 3 : 0,
          timestamp: DateTime.utc(2026, 10, 16),
          updatedAt: updatedAt,
        );
    final cached = row(TransactionStatus.pending, DateTime.utc(2026, 10, 16));
    final live = row(TransactionStatus.confirmed, DateTime.utc(2026, 10, 17));
    final extras = _PendingExtras()
      ..transfers.complete([])
      ..links.complete([]);
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('user_fixture'),
      ledgerRepositoryProvider.overrideWithValue(_UnavailableLedger()),
      transactionRepositoryProvider.overrideWithValue(extras),
      localTransactionHistoryStoreProvider
          .overrideWithValue(_History([cached])),
    ]);
    addTearDown(container.dispose);
    container.read(lastTransactionHistoryProvider.notifier).set([live]);
    final result = await container.read(transactionHistoryProvider.future);
    expect(result.single.status, TransactionStatus.confirmed);
    expect(result.single.confirmations, 3);
    expect(container.read(lastTransactionHistoryProvider).single.status,
        TransactionStatus.confirmed);
  });

  for (final empty in [false, true]) {
    test('primary history is visible before pending extras, empty=$empty',
        () async {
      final rows = empty
          ? <Transaction>[]
          : [
              Transaction(
                id: 'primary-row',
                fromAddress: 'source',
                toAddress: 'destination',
                amountSatoshis: 123,
                feeSatoshis: 0,
                status: TransactionStatus.confirmed,
                type: TransactionType.receive,
                confirmations: 1,
                timestamp: DateTime.utc(2026, 10, 17),
              )
            ];
      final extras = _PendingExtras();
      final container = ProviderContainer(overrides: [
        sessionStorageScopeProvider.overrideWithValue('user_fixture'),
        ledgerRepositoryProvider
            .overrideWithValue(_UnavailableLedger()..result = Right(rows)),
        transactionRepositoryProvider.overrideWithValue(extras),
        localTransactionHistoryStoreProvider.overrideWithValue(_History([])),
      ]);
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      container.listen(transactionHistoryReadinessProvider, (_, next) {
        if (next.primaryLoaded && !loaded.isCompleted) loaded.complete();
      });
      final completeHistory = container.read(transactionHistoryProvider.future);
      await loaded.future.timeout(const Duration(seconds: 1));
      expect(container.read(lastTransactionHistoryProvider), rows);
      expect(container.read(transactionHistoryLastSyncProvider), isNull);
      expect(container.read(transactionHistoryProvider).isLoading, isTrue);
      expect(extras.transfers.isCompleted, isFalse);
      extras.transfers.complete([]);
      extras.links.complete([]);
      expect((await completeHistory).map((row) => row.id),
          rows.map((row) => row.id));
      expect(container.read(transactionHistoryLastSyncProvider), isNotNull);
    });
  }

  test('failed refresh retains confirmed sync time and recovery clears warning',
      () async {
    final ledger = _UnavailableLedger()..result = const Right([]);
    final extras = _PendingExtras()
      ..transfers.complete([])
      ..links.complete([]);
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('user_fixture'),
      ledgerRepositoryProvider.overrideWithValue(ledger),
      transactionRepositoryProvider.overrideWithValue(extras),
      localTransactionHistoryStoreProvider.overrideWithValue(_History([])),
    ]);
    addTearDown(container.dispose);
    final failures = <bool>[];
    container.listen(transactionHistoryReadinessProvider,
        (_, next) => failures.add(next.failed));
    await container.read(transactionHistoryProvider.future);
    final lastSync = container.read(transactionHistoryLastSyncProvider);
    expect(lastSync, isNotNull);

    ledger.result = const Left(ServerFailure(message: 'upstream unavailable'));
    container
        .read(transactionHistoryRevisionProvider('user_fixture').notifier)
        .refresh();
    await expectLater(
        container.read(transactionHistoryProvider.future), throwsException);
    expect(container.read(transactionHistoryLastSyncProvider), lastSync);
    expect(container.read(transactionHistoryReadinessProvider).failed, isTrue);
    expect(failures, contains(true));

    ledger.result = const Right([]);
    container
        .read(transactionHistoryRevisionProvider('user_fixture').notifier)
        .refresh();
    await container.read(transactionHistoryProvider.future);
    expect(container.read(transactionHistoryReadinessProvider).failed, isFalse);
    expect(failures.last, isFalse);
  });
}
