import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart'
    as domain;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite projection for on-device extrato rows (non-web).
///
/// Integrity MAC still lives in secure storage (see
/// [LocalTransactionHistoryStore]); this table only holds the payload.
class LocalTransactionSqlite {
  LocalTransactionSqlite._();

  static Database? _db;
  static const _dbName = 'kerosene_tx_history_v1.db';
  static const _table = 'tx_history';
  static const maxEntries = 500;

  static Future<Database?> _open() async {
    if (kIsWeb) return null;
    if (_db != null) return _db;
    try {
      if (defaultTargetPlatform == TargetPlatform.linux || 
          defaultTargetPlatform == TargetPlatform.windows || 
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final dir = await getDatabasesPath();
      final path = p.join(dir, _dbName);
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_table (
              scope TEXT NOT NULL,
              id TEXT NOT NULL,
              timestamp_ms INTEGER NOT NULL,
              payload TEXT NOT NULL,
              PRIMARY KEY (scope, id)
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_${_table}_scope_ts ON $_table (scope, timestamp_ms DESC)',
          );
        },
      );
      return _db;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionSqlite open failed: $e');
      }
      return null;
    }
  }

  static Future<List<domain.Transaction>?> load(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return null;
    final db = await _open();
    if (db == null) return null;
    try {
      final rows = await db.query(
        _table,
        where: 'scope = ?',
        whereArgs: [scope],
        orderBy: 'timestamp_ms DESC',
        limit: maxEntries,
      );
      if (rows.isEmpty) return null;
      final items = <domain.Transaction>[];
      for (final row in rows) {
        try {
          final raw = row['payload'] as String? ?? '';
          final map = jsonDecode(raw);
          if (map is Map) {
            items.add(
              domain.Transaction.fromJson(Map<String, dynamic>.from(map)),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('LocalTransactionSqlite skip row: $e');
          }
        }
      }
      return items;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionSqlite load failed: $e');
      }
      return null;
    }
  }

  static Future<bool> save(
    String sessionScope,
    List<domain.Transaction> transactions,
  ) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return false;
    final db = await _open();
    if (db == null) return false;
    final capped = List<domain.Transaction>.from(transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (capped.length > maxEntries) {
      capped.removeRange(maxEntries, capped.length);
    }
    try {
      await db.transaction((txn) async {
        await txn.delete(_table, where: 'scope = ?', whereArgs: [scope]);
        final batch = txn.batch();
        for (final tx in capped) {
          batch.insert(
            _table,
            {
              'scope': scope,
              'id': tx.id,
              'timestamp_ms': tx.timestamp.toUtc().millisecondsSinceEpoch,
              'payload': jsonEncode(tx.toJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionSqlite save failed: $e');
      }
      return false;
    }
  }

  static Future<void> clear(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return;
    final db = await _open();
    if (db == null) return;
    try {
      await db.delete(_table, where: 'scope = ?', whereArgs: [scope]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalTransactionSqlite clear failed: $e');
      }
    }
  }
}
