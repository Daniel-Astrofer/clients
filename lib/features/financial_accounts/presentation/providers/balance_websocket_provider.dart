import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/session_invalidation_provider.dart';
import 'package:kerosene/core/services/background_service.dart';
import 'package:kerosene/core/services/native_notification_presenter.dart';
import 'package:kerosene/core/services/notification_service.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import '../../../../core/services/balance_websocket_service.dart';
import '../../../../core/providers/tor_providers.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/providers/incoming_transfer_theater.dart';
import '../../../../core/utils/device_helper.dart';
import 'financial_dirty_provider.dart';
import 'financial_refresh.dart';
import 'wallet_provider.dart';

export 'financial_refresh.dart';
export 'financial_dirty_provider.dart';

const double _balanceChangeEpsilon = 0.000000001;
const financialRealtimeFallbackInterval = Duration(seconds: 30);

typedef FinancialRefreshCancel = void Function();
typedef FinancialRefreshScheduler = FinancialRefreshCancel Function(
  Duration delay,
  void Function() callback,
);

/// Schedules financial refreshes serially so a slow request cannot overlap the
/// next polling cycle.
class FinancialRealtimeRefreshLoop {
  FinancialRealtimeRefreshLoop({
    required Future<void> Function() refresh,
    this.interval = financialRealtimeFallbackInterval,
    FinancialRefreshScheduler scheduler = _scheduleFinancialRefresh,
  })  : _refresh = refresh,
        _scheduler = scheduler;

  final Future<void> Function() _refresh;
  final Duration interval;
  final FinancialRefreshScheduler _scheduler;

  FinancialRefreshCancel? _cancelScheduledRefresh;
  bool _started = false;
  bool _refreshInFlight = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_disposed) {
      return;
    }

    _cancelScheduledRefresh = _scheduler(interval, () {
      _cancelScheduledRefresh = null;
      unawaited(_runRefresh());
    });
  }

  Future<void> _runRefresh() async {
    if (_disposed || _refreshInFlight) {
      return;
    }

    _refreshInFlight = true;
    try {
      await _refresh();
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          'BalanceWebSocket: periodic financial refresh failed; retrying later.',
        );
      }
    } finally {
      _refreshInFlight = false;
      _scheduleNext();
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelScheduledRefresh?.call();
    _cancelScheduledRefresh = null;
  }
}

FinancialRefreshCancel _scheduleFinancialRefresh(
  Duration delay,
  void Function() callback,
) {
  final timer = Timer(delay, callback);
  return timer.cancel;
}

final financialRefreshSchedulerProvider = Provider<FinancialRefreshScheduler>(
  (ref) => _scheduleFinancialRefresh,
);

/// Provider do serviço WebSocket para atualizações de saldo em tempo real
final balanceWebSocketServiceProvider =
    FutureProvider.autoDispose<BalanceWebSocketService?>((
  ref,
) async {
  final authState = ref.watch(authControllerProvider);

  if (authState is! AuthAuthenticated) {
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: authenticated session required.');
    }
    return null;
  }

  // Watch the reactive Tor API URL
  final baseUrl = ref.watch(torApiUrlProvider);

  final userId = authState.user.id;
  if (kDebugMode) {
    debugPrint('BalanceWebSocket: preparing balance stream.');
  }

  // Obter token JWT do armazenamento seguro
  String? token;
  try {
    token = await ref.read(authLocalDataSourceProvider).getToken();
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: session credential lookup completed.');
    }
    token = _normalizeSessionToken(token);
    if (token != null && token.length < 10) {
      if (kDebugMode) {
        debugPrint('BalanceWebSocket: session credential was rejected locally.');
      }
    }
  } catch (_) {
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: session credential unavailable.');
    }
  }

  final deviceHash = await DeviceHelper.getDeviceHash();
  if (!ref.mounted) {
    return null;
  }

  final service = BalanceWebSocketService(
    baseUrl: baseUrl,
    userId: userId.toString(),
    authToken: token,
    deviceHash: deviceHash,
    onSessionInvalidated: () {
      if (kDebugMode) {
        debugPrint('BalanceWebSocket: session invalidated by realtime channel.');
      }
      ref.read(sessionInvalidationProvider.notifier).emit();
    },
    onBalanceUpdate: (update) {
      if (kDebugMode) {
        debugPrint('BalanceWebSocket: balance update received.');
      }

      // Match by KFE wallet UUID only (never name/label — collision risk).
      final currentWalletState = ref.read(walletProvider);
      if (currentWalletState is WalletLoaded) {
        final wallets = currentWalletState.wallets;
        final walletId = update.walletId.trim();
        final matched = walletId.isEmpty
            ? null
            : wallets.cast<Wallet?>().firstWhere(
                  (w) => w != null && w.id == walletId,
                  orElse: () => null,
                );

        final oldBalance = matched?.balance;
        final newBalance = update.newBalance;
        final hasMeaningfulChange = oldBalance == null
            ? update.amount.abs() > _balanceChangeEpsilon
            : (newBalance - oldBalance).abs() > _balanceChangeEpsilon;

        // Balance and extrato always move together (reactive parity).
        // Cold observe context may not change available balance but must refresh
        // confirmations / new observed spends.
        final isObservedContext =
            update.context.toLowerCase().contains('observ');
        if (hasMeaningfulChange || isObservedContext) {
          ref.read(financialDirtyProvider.notifier).markDirty();
          unawaited(refreshFinancialProjection(ref).then((_) {
            ref.read(financialDirtyProvider.notifier).clear();
          }));
        }
      } else {
        ref.read(financialDirtyProvider.notifier).markDirty();
        unawaited(refreshFinancialProjection(ref).then((_) {
          ref.read(financialDirtyProvider.notifier).clear();
        }));
      }

      // Apply only with a stable wallet UUID; name-only events force full refresh.
      final key = update.walletId.trim();
      if (key.isEmpty) {
        unawaited(ref.read(walletProvider.notifier).refresh());
      } else {
        ref.read(walletProvider.notifier).updateBalanceFromWebSocketUpdate(
              walletKey: key,
              newBalance: update.newBalance,
              kind: update.kind,
              availableSats: update.availableSats,
              observedSats: update.observedSats,
              primarySats: update.primarySats,
              bucket: update.bucket,
              context: update.context,
            );
      }

      // Fallback theater path: credits can land on /queue/balance without a
      // parallel /queue/notifications push (KFE→Auth notify is best-effort).
      final creditPayload = payloadFromBalanceCredit(
        walletId: update.walletId,
        walletName: update.walletName,
        amountBtc: update.amount,
        context: update.context,
        kind: update.kind,
        bucket: update.bucket,
      );
      if (creditPayload != null && ref.mounted) {
        presentIncomingTheater(
          ref.read(homeEducationQueueProvider.notifier),
          ref.read(homeBalanceReceivePulseProvider.notifier),
          creditPayload,
        );
      }
    },
    onNotification: (event) {
      final notification = SessionNotificationItem(
        id: event.id,
        title: event.title,
        body: event.body,
        timestamp: event.timestamp,
        kind: event.kind,
        severity: event.severity,
        deeplink: event.deeplink,
        entityType: event.entityType,
        entityId: event.entityId,
        metadata: event.metadata,
      );

      final alertPreferences = ref.read(alertPreferencesProvider);
      final keepForAlerts =
          _shouldKeepNotification(notification, alertPreferences);

      // In-app feed + financial refresh + theater must not depend on OS alert
      // preferences. Prefs only gate system notifications.
      if (keepForAlerts) {
        ref.read(sessionNotificationFeedProvider.notifier).add(notification);
      }

      // Single coordinator: balance + extrato + links.
      ref.read(financialDirtyProvider.notifier).markDirty();
      unawaited(refreshFinancialProjection(ref).then((_) {
        ref.read(financialDirtyProvider.notifier).clear();
      }));

      // Theater for receives (independent of OS alert prefs).
      if (isIncomingTransactionNotification(notification)) {
        final theater = payloadFromNotification(notification);
        if (theater != null) {
          presentIncomingTheater(
            ref.read(homeEducationQueueProvider.notifier),
            ref.read(homeBalanceReceivePulseProvider.notifier),
            theater,
          );
        }
      }

      // Native Android/iOS shade: financial + security when prefs allow.
      if (keepForAlerts &&
          NativeNotificationPresenter.isNativeAlertKind(notification.kind)) {
        unawaited(
          NotificationService().showSessionNotification(notification),
        );
        // Mark seen in BG isolate so the next REST poll does not re-alert.
        unawaited(markBackgroundNotificationsSeen([notification.id]));
      }
    },
    onHomeUiEvent: (event) {
      if (!ref.mounted) {
        return;
      }
      ref.read(homeSurfaceProvider.notifier).applyEventJson(event);
    },
  );

  // Conectar ao WebSocket
  await service.connect();
  if (!ref.mounted) {
    service.disconnect();
    return null;
  }

  // Core can keep this socket connected while KFE events travel through a
  // separate runtime. Polling remains active as a bounded consistency fallback.
  final refreshLoop = FinancialRealtimeRefreshLoop(
    refresh: () => refreshFinancialProjection(ref),
    scheduler: ref.read(financialRefreshSchedulerProvider),
  )..start();

  // Desconectar quando o provider for descartado
  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: disconnecting.');
    }
    refreshLoop.dispose();
    service.disconnect();
  });

  return service;
});

String? _normalizeSessionToken(String? token) {
  if (token == null) {
    return null;
  }

  var normalized = token.trim();
  if (normalized.startsWith('"') && normalized.endsWith('"')) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }
  if (normalized.startsWith('Bearer ')) {
    normalized = normalized.substring(7).trim();
  }
  if (normalized.contains('eyJ')) {
    normalized = normalized.substring(normalized.indexOf('eyJ'));
  }
  return normalized;
}

bool _shouldKeepNotification(
  SessionNotificationItem notification,
  AlertPreferencesState preferences,
) {
  if (NativeNotificationPresenter.isSecurityKind(notification.kind)) {
    return preferences.securityAlertsEnabled;
  }

  if (NativeNotificationPresenter.isFinancialKind(notification.kind)) {
    return preferences.transactionAlertsEnabled;
  }

  if (notification.kind == SessionNotificationItem.kindMarketAlert) {
    return preferences.marketAlertsEnabled;
  }

  // System / account — allow unless all alerts disabled (default on).
  return true;
}
