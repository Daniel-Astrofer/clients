import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';

class _MemoryKv implements LocalHistoryKvStore {
  final Map<String, String> data = {};

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}

Transaction _tx(String id) {
  return Transaction(
    id: id,
    fromAddress: 'a',
    toAddress: 'b',
    amountSatoshis: 1000,
    feeSatoshis: 0,
    status: TransactionStatus.confirmed,
    type: TransactionType.receive,
    confirmations: 3,
    timestamp: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('save/load roundtrip with HMAC blob', () async {
    final kv = _MemoryKv();
    final store = LocalTransactionHistoryStore.withKv(kv);
    const scope = 'user_42';

    await store.save(scope, [_tx('tx-1')]);
    final loaded = await store.load(scope);
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'tx-1');

    final raw = kv.data['tx_history_v1:$scope'];
    expect(raw, isNotNull);
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    expect(map['v'], 2);
    expect(map['mac'], isNotEmpty);
    expect(map['payload'], contains('tx-1'));
  });

  test('tampered payload is discarded', () async {
    final kv = _MemoryKv();
    final store = LocalTransactionHistoryStore.withKv(kv);
    const scope = 'user_99';

    await store.save(scope, [_tx('tx-2')]);
    final key = 'tx_history_v1:$scope';
    final raw = kv.data[key]!;
    // Flip MAC hex so integrity fails.
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map['mac'] = '0' * 64;
    kv.data[key] = jsonEncode(map);

    final loaded = await store.load(scope);
    expect(loaded, isEmpty);
    // Blob deleted after mac failure.
    expect(kv.data.containsKey(key), isFalse);
  });

  test('legacy plain JSON list still loads and upgrades on next save',
      () async {
    final kv = _MemoryKv();
    final store = LocalTransactionHistoryStore.withKv(kv);
    const scope = 'user_7';
    final legacy = jsonEncode([_tx('legacy').toJson()]);
    kv.data['tx_history_v1:$scope'] = legacy;

    final loaded = await store.load(scope);
    expect(loaded.single.id, 'legacy');

    await store.save(scope, loaded);
    final upgraded = jsonDecode(kv.data['tx_history_v1:$scope']!) as Map;
    expect(upgraded['mac'], isNotEmpty);
  });
}
