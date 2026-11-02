import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:kerosene/core/motion/app_motion.dart';
import 'dart:convert';
import 'package:kerosene/core/utils/app_date_time.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/notifications/application/providers/notification_data_providers.dart';
import 'package:kerosene/features/home/domain/home_communication_adapters.dart';
import 'package:kerosene/features/home/domain/home_communication_coordinator.dart';
import 'session_notification_sync_provider.dart';
export 'session_notification_sync_provider.dart';
export 'package:kerosene/features/notifications/application/providers/notification_data_providers.dart';

class SessionNotificationFeedNotifier
    extends Notifier<List<SessionNotificationItem>> {
  static const int _maxItems = 50;
  static const String _storageKeyBase = 'session_notification_feed_v3';
  String? _activeStorageKey;
  int _generation = 0;
  Future<void>? _hydration;
  Future<bool>? _reloadFuture;
  bool _serverQueryStarted = false;

  @override
  List<SessionNotificationItem> build() {
    final userId = ref.watch(authControllerProvider
        .select((value) => value is AuthAuthenticated ? value.user.id : null));
    final generation = ++_generation;
    _reloadFuture = null;
    _serverQueryStarted = false;

    if (userId == null || userId.trim().isEmpty) {
      _activeStorageKey = null;
      return const [];
    }

    final nextStorageKey = '$_storageKeyBase-$userId';
    _activeStorageKey = nextStorageKey;
    _hydration = _hydrate(nextStorageKey, generation);

    return const [];
  }

  void add(SessionNotificationItem item) {
    final scope = _activeStorageKey;
    if (scope == null || !_ownsQuery(scope, _generation)) return;
    final current = state;
    final alreadyPresent =
        current.any((entry) => entry.dedupeKey == item.dedupeKey);
    final retained =
        alreadyPresent ? current : current.take(_maxItems - 1).toList();
    _replaceState(_merge([item], retained));
  }

  Future<bool> reloadFromServer() {
    final scope = _activeStorageKey;
    final generation = _generation;
    if (scope == null || !_ownsQuery(scope, generation)) {
      return Future.value(false);
    }
    final current = _reloadFuture;
    if (current != null) return current;
    _serverQueryStarted = true;
    final operation = _queryServer(scope, generation);
    _reloadFuture = operation;
    unawaited(operation.whenComplete(() {
      if (ref.mounted &&
          _generation == generation &&
          identical(_reloadFuture, operation)) {
        _reloadFuture = null;
      }
    }));
    return operation;
  }

  bool _ownsQuery(String scope, int generation) {
    if (!ref.mounted ||
        _activeStorageKey != scope ||
        _generation != generation) {
      return false;
    }
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated &&
        scope == '$_storageKeyBase-${auth.user.id}';
  }

  Future<bool> _queryServer(String scope, int generation) async {
    ref.read(sessionNotificationSyncProvider.notifier).begin();
    try {
      final result =
          await ref.read(notificationRepositoryProvider).getNotifications();
      if (!_ownsQuery(scope, generation)) return false;
      return result.fold(
        (_) {
          ref
              .read(sessionNotificationSyncProvider.notifier)
              .finish(success: false);
          return false;
        },
        (items) {
          ref
              .read(sessionNotificationSyncProvider.notifier)
              .finish(success: true);
          _replaceState(_merge(items, state, authoritative: true));
          return true;
        },
      );
    } catch (error) {
      if (_ownsQuery(scope, generation)) {
        ref
            .read(sessionNotificationSyncProvider.notifier)
            .finish(success: false);
      }
      debugPrint('Notification query failed (${error.runtimeType}).');
      return false;
    }
  }

  Future<void> markRead(String notificationId) async {
    final scope = _activeStorageKey;
    if (scope == null || !_ownsQuery(scope, _generation)) return;
    final current = state;
    final index = current.indexWhere((item) => item.id == notificationId);
    if (index == -1) {
      return;
    }

    final target = current[index];
    if (target.read) {
      return;
    }

    final updated = [...current];
    updated[index] = target.copyWith(read: true);
    _replaceState(updated);

    if (target.canSyncRead) {
      unawaited(
          ref.read(notificationRepositoryProvider).markAsRead(notificationId));
    }
  }

  Future<void> markAllRead() async {
    final scope = _activeStorageKey;
    if (scope == null || !_ownsQuery(scope, _generation)) return;
    final unreadIds =
        state.where((item) => !item.read).map((item) => item.id).toList();
    if (unreadIds.isEmpty) {
      return;
    }

    _replaceState(
      state.map((item) => item.copyWith(read: true)).toList(),
    );

    unawaited(_syncMarkAllRead(unreadIds, scope, _generation));
  }

  void clear() {
    final scope = _activeStorageKey;
    if (scope == null || !_ownsQuery(scope, _generation)) return;
    _replaceState(const []);
  }

  Future<void> _hydrate(String storageKey, int generation) async {
    DateTime? cachedQueryTime;
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList(storageKey) ?? const <String>[];
      cachedQueryTime =
          AppDateTime.parse(prefs.getString('$storageKey-last-query'));

      final localItems = persisted
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .map(SessionNotificationItem.fromJson)
          .toList();

      if (_ownsQuery(storageKey, generation)) {
        _replaceState(_merge(state, localItems), persist: false);
      }
    } catch (error) {
      // Keep the live feed if local storage is unavailable or corrupt.
      debugPrint('Notification cache read failed (${error.runtimeType}).');
    }
    if (_ownsQuery(storageKey, generation)) {
      ref
          .read(sessionNotificationSyncProvider.notifier)
          .finishHydration(cachedQueryTime);
      if (!_serverQueryStarted) unawaited(reloadFromServer());
    }
  }

  Future<void> _persist() async {
    final storageKey = _activeStorageKey;
    if (storageKey == null) {
      return;
    }

    final generation = _generation;
    try {
      await _hydration;
      if (!_ownsQuery(storageKey, generation)) {
        return;
      }
      final snapshot = state.map((item) => jsonEncode(item.toJson())).toList();
      final lastQuery = ref.read(sessionNotificationSyncProvider).lastSyncedAt;
      final prefs = await SharedPreferences.getInstance();
      if (!_ownsQuery(storageKey, generation)) {
        return;
      }
      if (!await prefs.setStringList(storageKey, snapshot)) {
        throw StateError('Notification cache was not saved.');
      }
      if (!_ownsQuery(storageKey, generation)) return;
      final saved = lastQuery == null
          ? await prefs.remove('$storageKey-last-query')
          : await prefs.setString(
              '$storageKey-last-query', lastQuery.toUtc().toIso8601String());
      if (!saved) throw StateError('Notification query time was not saved.');
    } catch (error) {
      debugPrint('Notification cache write failed (${error.runtimeType}).');
    }
  }

  Future<void> _syncMarkAllRead(
      List<String> ids, String scope, int generation) async {
    for (final id in ids) {
      if (!_ownsQuery(scope, generation)) {
        return;
      }
      if (int.tryParse(id) == null) {
        continue;
      }
      await ref.read(notificationRepositoryProvider).markAsRead(id);
    }
  }

  void _replaceState(
    List<SessionNotificationItem> nextState, {
    bool persist = true,
  }) {
    state = [
      ...nextState
    ]..sort((a, b) => AppDateTime.compareNewestFirst(a.timestamp, b.timestamp));
    if (state.length > _maxItems) {
      state = state.take(_maxItems).toList();
    }

    if (persist) {
      unawaited(_persist());
    }
  }

  List<SessionNotificationItem> _merge(
    List<SessionNotificationItem> incoming,
    List<SessionNotificationItem> current, {
    bool authoritative = false,
  }) {
    final merged = <String, SessionNotificationItem>{};
    final currentById = {for (final item in current) item.id: item};
    final incomingIds = incoming.map((item) => item.id).toSet();
    final retained = authoritative
        ? current.where((item) => !incomingIds.contains(item.id))
        : current;

    for (final raw in [...retained, ...incoming]) {
      final previous = authoritative ? currentById[raw.id] : null;
      final item = previous == null
          ? raw
          : raw.copyWith(read: raw.read || previous.read);
      final key = item.dedupeKey;
      final existing = merged[key];

      if (existing == null) {
        merged[key] = item;
        continue;
      }

      final latest =
          AppDateTime.compareNewestFirst(item.timestamp, existing.timestamp) <=
                  0
              ? item
              : existing;
      final older = identical(latest, item) ? existing : item;
      merged[key] = latest.copyWith(
        read: item.read || existing.read,
        metadata: {
          ...older.metadata,
          ...latest.metadata,
        },
      );
    }

    return merged.values.toList();
  }
}

class NotificationSidebarNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(sessionStorageScopeProvider);
    return false;
  }

  void toggle() {
    if (ref.read(sessionStorageScopeProvider) != null) state = !state;
  }

  void open() {
    if (ref.read(sessionStorageScopeProvider) != null) state = true;
  }

  void close() => state = false;
}

class NotificationBannerNotifier extends Notifier<SessionNotificationItem?> {
  Timer? _dismissTimer;
  final HomeCommunicationCoordinator _coordinator =
      HomeCommunicationCoordinator();
  final Map<String, SessionNotificationItem> _sourceByKey =
      <String, SessionNotificationItem>{};

  @override
  SessionNotificationItem? build() {
    ref.watch(sessionStorageScopeProvider);
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _coordinator.clear();
    _sourceByKey.clear();
    ref.onDispose(() {
      _dismissTimer?.cancel();
      _coordinator.clear();
      _sourceByKey.clear();
    });
    return null;
  }

  void show(SessionNotificationItem notification) {
    if (notification.read || ref.read(sessionStorageScopeProvider) == null) {
      return;
    }
    _dismissTimer?.cancel();
    final communication = communicationFromNotification(notification);
    _sourceByKey[communication.stableKey] = notification;
    _coordinator.enqueue(communication);
    _syncCurrentState();
    final current = state;
    if (current != null) _armDismissTimer(current);
  }

  void dismiss({SessionNotificationItem? expected}) {
    if (expected != null && !identical(state, expected)) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final key = _coordinator.current?.stableKey;
    if (key != null) _sourceByKey.remove(key);
    _coordinator.dismiss();
    _syncCurrentState();
    final current = state;
    if (current != null) _armDismissTimer(current);
  }

  void openSidebar() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _coordinator.clear();
    _sourceByKey.clear();
    _syncCurrentState();
    ref.read(notificationSidebarProvider.notifier).open();
  }

  void _armDismissTimer(SessionNotificationItem notification) {
    if (notification.presentationPolicy !=
        NotificationPresentationPolicy.autoDismiss) {
      return;
    }
    _dismissTimer = Timer(KeroseneMotion.notificationLongHold,
        () => dismiss(expected: notification));
  }

  void _syncCurrentState() {
    final current = _coordinator.current;
    state = current == null ? null : _sourceByKey[current.stableKey];
  }
}

final sessionNotificationFeedProvider = NotifierProvider<
    SessionNotificationFeedNotifier, List<SessionNotificationItem>>(
  SessionNotificationFeedNotifier.new,
);

final sessionNotificationUnreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(sessionNotificationFeedProvider);
  return notifications.where((item) => !item.read).length;
});

final notificationSidebarProvider =
    NotifierProvider<NotificationSidebarNotifier, bool>(
  NotificationSidebarNotifier.new,
);

final notificationBannerProvider =
    NotifierProvider<NotificationBannerNotifier, SessionNotificationItem?>(
  NotificationBannerNotifier.new,
);

final activeDeviceTokensProvider =
    FutureProvider.autoDispose<List<DeviceToken>>((ref) async {
  if (ref.watch(sessionStorageScopeProvider) == null) return const [];
  final result =
      await ref.read(notificationRepositoryProvider).activeDeviceTokens();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (tokens) => tokens,
  );
});
