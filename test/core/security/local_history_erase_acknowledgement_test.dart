import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/app/security/local_transaction_sqlite.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

class _Storage extends SecureStorageService {
  final deleted = <String>[];
  @override
  Future<void> delete({required String key}) async => deleted.add(key);
}

Transaction _movement(String id) => Transaction(
    id: id,
    fromAddress: 'public-origin',
    toAddress: 'public-destination',
    amountSatoshis: 1,
    feeSatoshis: 0,
    status: TransactionStatus.confirmed,
    type: TransactionType.receive,
    confirmations: 1,
    timestamp: DateTime(2020));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late String originalPath;
  setUpAll(() async {
    sqfliteFfiInit();
    originalPath = await databaseFactoryFfi.getDatabasesPath();
    temporary =
        await Directory.systemTemp.createTemp('kerosene-local-history-ack-');
    await databaseFactoryFfi.setDatabasesPath(temporary.path);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  tearDownAll(() async {
    await databaseFactoryFfi.setDatabasesPath(originalPath);
    await temporary.delete(recursive: true);
  });
  test(
      'an unavailable database cannot acknowledge erasure or remove integrity keys',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.tekartik.sqflite');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (_) async => throw PlatformException(code: 'fixture_db_unavailable'));
    addTearDown(() =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final storage = _Storage();
    await expectLater(
        LocalTransactionHistoryStore(storage).clear('alice'), throwsStateError);
    expect(storage.deleted, isEmpty);
    await expectLater(
        LocalTransactionHistoryStore(storage).clear(''), throwsStateError);
    expect(storage.deleted, isEmpty);
  });
  test(
      'acknowledged erasure removes only its account before its integrity keys',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(
        await LocalTransactionSqlite.save(
            'alice', [_movement('alice-movement')]),
        isTrue);
    expect(
        await LocalTransactionSqlite.save('bob', [_movement('bob-movement')]),
        isTrue);
    final storage = _Storage();
    await LocalTransactionHistoryStore(storage).clear('alice');
    expect(await LocalTransactionSqlite.load('alice'), isNull);
    expect(
        (await LocalTransactionSqlite.load('bob'))!.single.id, 'bob-movement');
    expect(storage.deleted, hasLength(3));
    expect(storage.deleted.every((key) => key.endsWith(':alice')), isTrue);
  });
  test(
      'database delete errors reach the caller while integrity keys remain intact',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // The factory returns the shared connection already opened by the store.
    // Close that isolated fixture connection to exercise a real delete failure.
    final db = await databaseFactoryFfi
        .openDatabase('${temporary.path}/kerosene_tx_history_v1.db');
    await db.close();
    final storage = _Storage();
    await expectLater(LocalTransactionHistoryStore(storage).clear('bob'),
        throwsA(isA<DatabaseException>()));
    expect(storage.deleted, isEmpty);
  });
}
