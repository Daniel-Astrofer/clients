import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/application/activity_cancel.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

class _MemoryStorage extends SecureStorageService {
  final data = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  @override
  Future<String?> readCompatibleStrict({required String key}) async {
    if (failRead) throw StateError('storage unavailable');
    return data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    if (writeStarted?.isCompleted == false) writeStarted!.complete();
    await writeGate?.future;
    if (failWrite) throw StateError('write unavailable');
    data[key] = value;
  }
}

String _key(String scope) =>
    '${keroseneSecurePrefix()}activity_archive_v1:$scope';
final _owner = NotifierProvider<_Owner, String?>(_Owner.new);

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void change(String? value) => state = value;
}

class _GatedStore extends ActivityArchiveStore {
  _GatedStore(super.storage);
  final alice = Completer<Set<String>>();
  final started = Completer<void>();
  @override
  Future<Set<String>> load(String scope) async {
    if (scope == 'alice') {
      if (!started.isCompleted) started.complete();
      return alice.future;
    }
    return {'bob-only'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent archives preserve all ids without lost updates', () async {
    final storage = _MemoryStorage();
    final store = ActivityArchiveStore(storage);
    await Future.wait([
      store.archiveMany('alice', ['a', 'pl:a']),
      store.archive('alice', 'b'),
    ]);
    expect(await store.load('alice'), {'a', 'pl:a', 'b'});
    expect(storage.writes, 2);
  });
  test('failed alias write changes neither id and queue can retry', () async {
    final storage = _MemoryStorage()..failWrite = true;
    final store = ActivityArchiveStore(storage);
    await expectLater(
        store.archiveMany('alice', ['pl_link', 'pl:link']), throwsStateError);
    expect(storage.data, isEmpty);
    storage.failWrite = false;
    await store.archiveMany('alice', ['pl_link', 'pl:link']);
    expect(await store.load('alice'), {'pl_link', 'pl:link'});
  });
  test('unavailable read never overwrites a previous archive', () async {
    final storage = _MemoryStorage();
    storage.data[_key('alice')] = '["previous"]';
    storage.failRead = true;
    final store = ActivityArchiveStore(storage);
    await expectLater(store.archive('alice', 'new'), throwsStateError);
    expect(storage.data[_key('alice')], '["previous"]');
    expect(storage.writes, 0);
  });
  test('corrupt persisted data is an error rather than an empty archive',
      () async {
    final storage = _MemoryStorage();
    storage.data[_key('alice')] = '[123]';
    await expectLater(ActivityArchiveStore(storage).archive('alice', 'new'),
        throwsFormatException);
    expect(storage.writes, 0);
  });
  test('missing session cannot acknowledge an archive', () {
    final storage = _MemoryStorage();
    expect(() => ActivityArchiveStore(storage).archive('', 'id'),
        throwsStateError);
    expect(storage.writes, 0);
  });
  test('late hydration cannot disclose old account ids in a new session',
      () async {
    final store = _GatedStore(_MemoryStorage());
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
      activityArchiveStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    container.listen(activityArchiveProvider, (_, __) {});
    await store.started.future;
    container.read(_owner.notifier).change('bob');
    container.read(activityArchiveProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activityArchiveProvider), {'bob-only'});
    store.alice.complete({'alice-secret-id'});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activityArchiveProvider), {'bob-only'});
  });
  test('late save cannot update the new account state', () async {
    final storage = _MemoryStorage();
    storage.data[_key('bob')] = '["bob-only"]';
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
      activityArchiveStoreProvider
          .overrideWithValue(ActivityArchiveStore(storage)),
    ]);
    addTearDown(container.dispose);
    container.listen(activityArchiveProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    storage.writeGate = Completer<void>();
    storage.writeStarted = Completer<void>();
    final pending = container
        .read(activityArchiveProvider.notifier)
        .markArchived('alice-id');
    final failure = expectLater(pending, throwsStateError);
    await storage.writeStarted!.future;
    container.read(_owner.notifier).change('bob');
    container.read(activityArchiveProvider);
    await Future<void>.delayed(Duration.zero);
    storage.writeGate!.complete();
    await failure;
    expect(container.read(activityArchiveProvider), {'bob-only'});
  });
  test('payment request aliases persist atomically before notifying UI',
      () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('alice'),
      activityArchiveStoreProvider
          .overrideWithValue(ActivityArchiveStore(storage)),
    ]);
    addTearDown(container.dispose);
    final archive = container.read(activityArchiveProvider.notifier);
    await archiveActivity(
        archive,
        Transaction(
            id: 'pl_public',
            paymentRequestPublicId: 'public',
            fromAddress: 'a',
            toAddress: 'b',
            amountSatoshis: 1,
            feeSatoshis: 0,
            status: TransactionStatus.cancelled,
            type: TransactionType.receive,
            confirmations: 0,
            timestamp: DateTime(2020)));
    expect(storage.writes, 1);
    expect(
        jsonDecode(storage.data[_key('alice')]!), ['pl:public', 'pl_public']);
    expect(container.read(activityArchiveProvider), {'pl_public', 'pl:public'});
  });
  test('failed write retains known ids and reports stale lookup', () async {
    final storage = _MemoryStorage();
    storage.data[_key('alice')] = '["known"]';
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('alice'),
      activityArchiveStoreProvider
          .overrideWithValue(ActivityArchiveStore(storage)),
    ]);
    addTearDown(container.dispose);
    container.listen(activityArchiveProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    storage.failWrite = true;
    await expectLater(
        container.read(activityArchiveProvider.notifier).markArchived('new'),
        throwsStateError);
    expect(container.read(activityArchiveProvider), {'known'});
    final status = container.read(activityArchiveReadinessProvider);
    expect(status.state, ActivityArchiveLoadState.unavailable);
    expect(status.checkedAt, isNotNull);
  });
  test('explicit reload recovers known archive ids after a failed read',
      () async {
    final storage = _MemoryStorage();
    storage.data[_key('alice')] = '["known"]';
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('alice'),
      activityArchiveStoreProvider
          .overrideWithValue(ActivityArchiveStore(storage)),
    ]);
    addTearDown(container.dispose);
    container.listen(activityArchiveProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    final archive = container.read(activityArchiveProvider.notifier);
    final checked = container.read(activityArchiveReadinessProvider).checkedAt;
    storage.failRead = true;
    await archive.reload();
    expect(container.read(activityArchiveProvider), {'known'});
    expect(container.read(activityArchiveReadinessProvider).checkedAt, checked);
    expect(container.read(activityArchiveReadinessProvider).state,
        ActivityArchiveLoadState.unavailable);
    storage.failRead = false;
    storage.data[_key('alice')] = '["known","recovered"]';
    final first = archive.reload();
    expect(identical(first, archive.reload()), isTrue);
    await first;
    expect(container.read(activityArchiveProvider), {'known', 'recovered'});
    expect(container.read(activityArchiveReadinessProvider).state,
        ActivityArchiveLoadState.ready);
  });
  test(
      'reload overlapping a write observes its acknowledgement without losing ids',
      () async {
    final storage = _MemoryStorage();
    storage.data[_key('alice')] = '["known"]';
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('alice'),
      activityArchiveStoreProvider
          .overrideWithValue(ActivityArchiveStore(storage)),
    ]);
    addTearDown(container.dispose);
    container.listen(activityArchiveProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    storage.writeGate = Completer<void>();
    storage.writeStarted = Completer<void>();
    final archive = container.read(activityArchiveProvider.notifier);
    final write = archive.markArchived('new');
    await storage.writeStarted!.future;
    final reload = archive.reload();
    expect(container.read(activityArchiveProvider), {'known'});
    storage.writeGate!.complete();
    await Future.wait([write, reload]).timeout(const Duration(seconds: 1));
    expect(container.read(activityArchiveProvider), {'known', 'new'});
    expect(container.read(activityArchiveReadinessProvider).state,
        ActivityArchiveLoadState.ready);
  });
  test('store reads wait for already pending writes', () async {
    final storage = _MemoryStorage()
      ..writeGate = Completer<void>()
      ..writeStarted = Completer<void>();
    final store = ActivityArchiveStore(storage);
    final write = store.archive('alice', 'new');
    await storage.writeStarted!.future;
    var readFinished = false;
    final read = store.load('alice').then((ids) {
      readFinished = true;
      return ids;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readFinished, isFalse);
    storage.writeGate!.complete();
    await write;
    expect(await read, {'new'});
  });
}
