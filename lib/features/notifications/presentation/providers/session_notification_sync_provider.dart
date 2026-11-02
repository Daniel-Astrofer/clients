import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

/// Query provenance shared by the inbox and sidebar; event dates are independent.
class SessionNotificationSyncState {
  final DateTime? lastSyncedAt;
  final bool loading;
  final bool failed;
  final bool hydrated;

  const SessionNotificationSyncState({
    this.lastSyncedAt,
    this.loading = false,
    this.failed = false,
    this.hydrated = false,
  });
}

class SessionNotificationSyncNotifier
    extends Notifier<SessionNotificationSyncState> {
  @override
  SessionNotificationSyncState build() {
    ref.watch(authControllerProvider
        .select((value) => value is AuthAuthenticated ? value.user.id : null));
    return const SessionNotificationSyncState();
  }

  void finishHydration(DateTime? cachedQueryTime) {
    state = SessionNotificationSyncState(
        lastSyncedAt: state.lastSyncedAt ?? cachedQueryTime,
        loading: state.loading,
        failed: state.failed,
        hydrated: true);
  }

  void begin() {
    state = SessionNotificationSyncState(
        lastSyncedAt: state.lastSyncedAt,
        loading: true,
        hydrated: state.hydrated);
  }

  void finish({required bool success}) {
    state = SessionNotificationSyncState(
        lastSyncedAt: success ? DateTime.now() : state.lastSyncedAt,
        failed: !success,
        hydrated: state.hydrated);
  }
}

final sessionNotificationSyncProvider = NotifierProvider<
    SessionNotificationSyncNotifier,
    SessionNotificationSyncState>(SessionNotificationSyncNotifier.new);
