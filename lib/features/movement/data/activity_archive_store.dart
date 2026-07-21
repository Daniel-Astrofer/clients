import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/security/local_transaction_history_store.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;

/// Local "Arquivadas" set: cancelled items stay global until the user opens them.
///
/// Persistence is per [sessionStorageScopeProvider] so accounts do not share archive.
class ActivityArchiveStore {
  ActivityArchiveStore(this._storage);

  final SecureStorageService _storage;

  String get _keyRoot => '${keroseneSecurePrefix()}activity_archive_v1';

  String _key(String scope) => '$_keyRoot:${scope.trim()}';

  Future<Set<String>> load(String sessionScope) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return {};
    final raw = await _storage.read(key: _key(scope));
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String sessionScope, Set<String> ids) async {
    final scope = sessionScope.trim();
    if (scope.isEmpty) return;
    final list = ids.toList()..sort();
    await _storage.write(key: _key(scope), value: jsonEncode(list));
  }

  Future<Set<String>> archive(String sessionScope, String id) async {
    final next = await load(sessionScope);
    final trimmed = id.trim();
    if (trimmed.isEmpty) return next;
    if (next.contains(trimmed)) return next;
    next.add(trimmed);
    await save(sessionScope, next);
    return next;
  }
}

final activityArchiveStoreProvider = Provider<ActivityArchiveStore>((ref) {
  return ActivityArchiveStore(ref.watch(secureStorageServiceProvider));
});

/// Reactive set of archived activity ids (tx id or `pl:{paymentLinkId}`).
class ActivityArchiveNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final scope = ref.watch(sessionStorageScopeProvider);
    if (scope == null || scope.trim().isEmpty) {
      return {};
    }
    // Fire-and-forget load; UI starts empty then hydrates.
    Future.microtask(() => _hydrate(scope));
    return {};
  }

  Future<void> _hydrate(String scope) async {
    final loaded = await ref.read(activityArchiveStoreProvider).load(scope);
    if (!ref.mounted) return;
    state = loaded;
  }

  bool contains(String id) => state.contains(id.trim());

  /// Marks item archived after user opens a cancelled activity.
  Future<void> markArchived(String id) async {
    final scope = ref.read(sessionStorageScopeProvider);
    if (scope == null || scope.trim().isEmpty) return;
    final trimmed = id.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final next =
        await ref.read(activityArchiveStoreProvider).archive(scope, trimmed);
    if (!ref.mounted) return;
    state = next;
  }
}

final activityArchiveProvider =
    NotifierProvider<ActivityArchiveNotifier, Set<String>>(
  ActivityArchiveNotifier.new,
);

/// Prefix for payment-link archive keys.
String paymentLinkArchiveId(String paymentLinkId) =>
    'pl:${paymentLinkId.trim()}';
