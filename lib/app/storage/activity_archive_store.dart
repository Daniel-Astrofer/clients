import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;

/// Local "Arquivadas" set: visibility changes only after explicit archiving.
///
/// Persistence is per [sessionStorageScopeProvider] so accounts do not share archive.
class ActivityArchiveStore {
  ActivityArchiveStore(this._storage);

  final SecureStorageService _storage;

  String get _keyRoot => '${keroseneSecurePrefix()}activity_archive_v1';

  String _key(String scope) => '$_keyRoot:${scope.trim()}';

  final _writes = <String, Future<void>>{};

  String _scope(String value) {
    final scope = value.trim();
    if (scope.isEmpty) throw StateError('Archive session unavailable');
    return scope;
  }

  Future<Set<String>> load(String sessionScope) async {
    final scope = _scope(sessionScope);
    // A refresh observes acknowledged writes already in flight.
    await _writes[scope];
    return _readStored(scope);
  }

  Future<Set<String>> _readStored(String scope) async {
    final raw = await _storage.readCompatibleStrict(key: _key(scope));
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List ||
        decoded.any((id) => id is! String || id.trim().isEmpty)) {
      throw const FormatException('Invalid archive data');
    }
    return decoded.cast<String>().map((id) => id.trim()).toSet();
  }

  Future<void> save(String sessionScope, Set<String> ids) async {
    final scope = _scope(sessionScope);
    final list = ids.toList()..sort();
    await _storage.write(key: _key(scope), value: jsonEncode(list));
  }

  Future<Set<String>> archive(String sessionScope, String id) =>
      archiveMany(sessionScope, [id]);

  /// One acknowledged write covers every alias. Writes for the same account
  /// are serialized so simultaneous actions cannot discard each other's ids.
  Future<Set<String>> archiveMany(String sessionScope, Iterable<String> ids) {
    final scope = _scope(sessionScope);
    final additions =
        ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (additions.isEmpty) throw ArgumentError('Archive identifier missing');
    final previous = _writes[scope] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final stored = await _readStored(scope);
      final next = {...stored, ...additions};
      if (next.length != stored.length) await save(scope, next);
      return next;
    });
    // Recover only the queue's bookkeeping; callers retain the operation error.
    final tail =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[scope] = tail;
    tail.then((_) {
      if (identical(_writes[scope], tail)) _writes.remove(scope);
    });
    return operation;
  }
}

final activityArchiveStoreProvider = Provider<ActivityArchiveStore>((ref) {
  return ActivityArchiveStore(ref.watch(secureStorageServiceProvider));
});

/// Reactive set of archived activity ids (tx id or `pl:{paymentLinkId}`).
enum ActivityArchiveLoadState { loading, ready, unavailable }

class ActivityArchiveNotifier extends Notifier<Set<String>> {
  int _generation = 0;
  int _revision = 0;
  ActivityArchiveLoadState loadState = ActivityArchiveLoadState.loading;
  DateTime? checkedAt;
  String? _knownScope;
  Set<String> _known = {};
  Future<void>? _hydration;

  @override
  Set<String> build() {
    final scope = ref.watch(sessionStorageScopeProvider)?.trim();
    final generation = ++_generation;
    if (scope == null || scope.isEmpty) {
      _knownScope = null;
      _known = {};
      checkedAt = null;
      loadState = ActivityArchiveLoadState.ready;
      _hydration = null;
      return {};
    }
    if (_knownScope != scope) {
      _known = {};
      checkedAt = null;
    }
    _knownScope = scope;
    loadState = ActivityArchiveLoadState.loading;
    _hydration = Future.microtask(() => _hydrate(scope, generation));
    return Set.unmodifiable(_known);
  }

  bool _owns(String scope, int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(sessionStorageScopeProvider)?.trim() == scope;

  Future<void> _hydrate(String scope, int generation) async {
    final revision = _revision;
    try {
      final loaded = await ref.read(activityArchiveStoreProvider).load(scope);
      if (!_owns(scope, generation) || revision != _revision) return;
      _known = loaded;
      checkedAt = DateTime.now();
      loadState = ActivityArchiveLoadState.ready;
      state = Set.unmodifiable(loaded);
    } catch (_) {
      if (!_owns(scope, generation) || revision != _revision) return;
      loadState = ActivityArchiveLoadState.unavailable;
      state = Set.unmodifiable(_known);
    }
  }

  /// Rechecks local storage without discarding this account's last known ids.
  Future<void> reload() {
    if (loadState == ActivityArchiveLoadState.loading && _hydration != null) {
      return _hydration!;
    }
    final scope = ref.read(sessionStorageScopeProvider)?.trim();
    if (scope == null || scope.isEmpty) return Future<void>.value();
    loadState = ActivityArchiveLoadState.loading;
    state = Set.unmodifiable(_known);
    return _hydration = _hydrate(scope, _generation);
  }

  bool contains(String id) => state.contains(id.trim());

  Future<void> markArchived(String id) => markArchivedMany([id]);

  Future<void> markArchivedMany(Iterable<String> ids) async {
    final scope = ref.read(sessionStorageScopeProvider)?.trim();
    if (scope == null || scope.isEmpty) {
      throw StateError('Archive session unavailable');
    }
    final generation = _generation;
    await _hydration;
    if (!_owns(scope, generation)) throw StateError('Archive session changed');
    try {
      final next =
          await ref.read(activityArchiveStoreProvider).archiveMany(scope, ids);
      if (!_owns(scope, generation)) {
        throw StateError('Archive session changed');
      }
      ++_revision;
      _known = next;
      checkedAt = DateTime.now();
      loadState = ActivityArchiveLoadState.ready;
      state = Set.unmodifiable(next);
    } catch (_) {
      if (_owns(scope, generation)) {
        loadState = ActivityArchiveLoadState.unavailable;
        state = Set.unmodifiable(_known);
      }
      rethrow;
    }
  }
}

final activityArchiveProvider =
    NotifierProvider<ActivityArchiveNotifier, Set<String>>(
  ActivityArchiveNotifier.new,
);

/// Prefix for payment-link archive keys.
String paymentLinkArchiveId(String paymentLinkId) =>
    'pl:${paymentLinkId.trim()}';

/// Archive lookup metadata accompanies the compatible public set of ids.
final activityArchiveReadinessProvider =
    Provider<({ActivityArchiveLoadState state, DateTime? checkedAt})>((ref) {
  ref.watch(activityArchiveProvider);
  final archive = ref.read(activityArchiveProvider.notifier);
  return (state: archive.loadState, checkedAt: archive.checkedAt);
});
