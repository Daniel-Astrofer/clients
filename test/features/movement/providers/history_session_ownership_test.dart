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

final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'user_a';
  void change(String? value) => state = value;
}

Transaction _row(String account) => Transaction(
      id: 'transaction-$account',
      fromAddress: 'source-$account',
      toAddress: 'destination-$account',
      amountSatoshis: account == 'a' ? 1 : 2,
      feeSatoshis: 0,
      status: TransactionStatus.confirmed,
      type: TransactionType.receive,
      confirmations: 1,
      timestamp: DateTime.utc(2026, 10, account == 'a' ? 16 : 17),
      updatedAt: DateTime.utc(2026, 10, account == 'a' ? 16 : 17),
    );

class _Ledger implements LedgerRepository {
  late String Function() scope;
  final reads = <String>[];
  final Future<Either<Failure, List<Transaction>>> Function(String) respond;
  _Ledger(this.respond);

  @override
  Future<Either<Failure, List<Transaction>>> getHistory(
      {int page = 0, int size = 50, DateTime? since}) {
    final owner = scope();
    reads.add(owner);
    return respond(owner);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Extras implements TransactionRepository {
  @override
  Future<List<ExternalTransfer>> getExternalTransfers() async => [];
  @override
  Future<List<PaymentLink>> getPaymentLinks() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends LocalTransactionHistoryStore {
  _Store() : super(SecureStorageService());
  final saved = <String, List<Transaction>>{};
  Future<List<Transaction>> Function(String)? loadResult;
  Future<void> Function(String)? beforeSave;

  @override
  Future<List<Transaction>> load(String scope) async =>
      await loadResult?.call(scope) ?? saved[scope] ?? [];

  @override
  Future<void> save(String scope, List<Transaction> rows) async {
    await beforeSave?.call(scope);
    saved[scope] = List.of(rows);
  }
}

ProviderContainer _container(_Store store, _Ledger ledger) {
  final container = ProviderContainer(overrides: [
    sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_session)),
    ledgerRepositoryProvider.overrideWithValue(ledger),
    transactionRepositoryProvider.overrideWithValue(_Extras()),
    localTransactionHistoryStoreProvider.overrideWithValue(store),
  ]);
  ledger.scope = () => container.read(_session)!;
  addTearDown(container.dispose);
  return container;
}

Future<void> _flush(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final next in ['user_b', null]) {
    test('clears visible history and checkpoints on session change to $next',
        () async {
      final container =
          _container(_Store(), _Ledger((_) async => const Right([])));
      container.read(lastTransactionHistoryProvider.notifier).set([_row('a')]);
      container.read(transactionHistoryLastSyncProvider.notifier).touch();
      container.read(transactionHistoryLastSyncProvider.notifier).markFailed();
      container
          .read(transactionHistoryCursorProvider.notifier)
          .advance([_row('a')]);
      container.read(transactionHistoryForceFullProvider.notifier).arm();

      container.read(_session.notifier).change(next);

      expect(container.read(lastTransactionHistoryProvider), isEmpty);
      expect(container.read(transactionHistoryLastSyncProvider), isNull);
      expect(
          container.read(transactionHistoryReadinessProvider).failed, isFalse);
      expect(container.read(transactionHistoryReadinessProvider).primaryLoaded,
          isFalse);
      expect(container.read(transactionHistoryCursorProvider), isNull);
      expect(container.read(transactionHistoryForceFullProvider), isFalse);
    });
  }

  test('late cache cannot publish or start a query for the previous account',
      () async {
    final pending = Completer<List<Transaction>>();
    final started = Completer<void>();
    final store = _Store()
      ..loadResult = (scope) {
        if (scope == 'user_a') {
          if (!started.isCompleted) started.complete();
          return pending.future;
        }
        return Future.value([]);
      };
    final ledger = _Ledger((_) async => Right([_row('b')]));
    final container = _container(store, ledger);
    unawaited(container
        .read(transactionHistoryProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    await started.future;
    container.read(_session.notifier).change('user_b');
    expect(
        await container.read(transactionHistoryProvider.future), [_row('b')]);

    pending.complete([_row('a')]);
    await _flush(container);

    expect(ledger.reads, ['user_b']);
    expect(container.read(lastTransactionHistoryProvider), [_row('b')]);
    expect(store.saved['user_a'], isNull);
  });

  test('late remote history cannot overwrite the active account or its cursor',
      () async {
    final pending = Completer<Either<Failure, List<Transaction>>>();
    final started = Completer<void>();
    final store = _Store();
    final ledger = _Ledger((scope) {
      if (scope == 'user_a') {
        if (!started.isCompleted) started.complete();
        return pending.future;
      }
      return Future.value(Right([_row('b')]));
    });
    final container = _container(store, ledger);
    unawaited(container
        .read(transactionHistoryProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    await started.future;
    container.read(_session.notifier).change('user_b');
    expect(
        await container.read(transactionHistoryProvider.future), [_row('b')]);

    pending.complete(Right([_row('a')]));
    await _flush(container);

    expect(ledger.reads, ['user_a', 'user_b']);
    expect(container.read(lastTransactionHistoryProvider), [_row('b')]);
    expect(
        container.read(transactionHistoryCursorProvider), _row('b').timestamp);
    expect(store.saved['user_a'], isNull);
    expect(store.saved['user_b'], [_row('b')]);
  });

  test('a cache write already in flight stays scoped and cannot publish late',
      () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    final store = _Store()
      ..beforeSave = (scope) {
        if (scope == 'user_a') {
          if (!started.isCompleted) started.complete();
          return pending.future;
        }
        return Future.value();
      };
    final ledger =
        _Ledger((scope) async => Right([_row(scope == 'user_a' ? 'a' : 'b')]));
    final container = _container(store, ledger);
    unawaited(container
        .read(transactionHistoryProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    await started.future;
    container.read(_session.notifier).change('user_b');
    expect(
        await container.read(transactionHistoryProvider.future), [_row('b')]);

    pending.complete();
    await _flush(container);

    expect(container.read(lastTransactionHistoryProvider), [_row('b')]);
    expect(store.saved['user_a'], [_row('a')]);
    expect(store.saved['user_b'], [_row('b')]);
  });

  test('returning to the first account rejects its superseded response',
      () async {
    final pending = Completer<Either<Failure, List<Transaction>>>();
    final started = Completer<void>();
    var firstAccountReads = 0;
    final store = _Store();
    final ledger = _Ledger((scope) {
      if (scope == 'user_a' && firstAccountReads++ == 0) {
        started.complete();
        return pending.future;
      }
      return Future.value(Right([_row(scope == 'user_a' ? 'new-a' : 'b')]));
    });
    final container = _container(store, ledger);
    unawaited(container
        .read(transactionHistoryProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    await started.future;
    container.read(_session.notifier).change('user_b');
    expect(
        await container.read(transactionHistoryProvider.future), [_row('b')]);
    container.read(_session.notifier).change('user_a');
    expect(await container.read(transactionHistoryProvider.future),
        [_row('new-a')]);

    pending.complete(Right([_row('a')]));
    await _flush(container);

    expect(ledger.reads, ['user_a', 'user_b', 'user_a']);
    expect(container.read(lastTransactionHistoryProvider), [_row('new-a')]);
    expect(store.saved['user_a'], [_row('new-a')]);
    expect(store.saved['user_b'], [_row('b')]);
  });
}
