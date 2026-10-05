import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/session_invalidation_provider.dart';
import 'package:kerosene/core/services/background_service.dart';
import 'package:kerosene/app/notifications/native_notification_presenter.dart';
import 'package:kerosene/app/notifications/notification_service.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import '../../../../core/services/balance_websocket_service.dart';
import '../../../../core/providers/tor_providers.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/providers/incoming_transfer_theater.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../../../../core/utils/device_helper.dart';
import 'financial_dirty_provider.dart';
import 'financial_refresh.dart';
import 'financial_surface_provider.dart';
import 'wallet_provider.dart';

export 'financial_refresh.dart';
export 'financial_dirty_provider.dart';
export 'financial_surface_provider.dart';

const double _balanceChangeEpsilon = 0.000000001;

/// Backup poll when realtime WS is healthy and a financial screen is visible.
/// Assumes kfe→server fan-out can also be Tor-slow — keep a safety net even
/// while "connected".
const financialRealtimeFallbackInterval = Duration(seconds: 30);

/// Poll while WS is down / reconnecting (only on financial surfaces).
/// Aggressive under Tor flap so settle still lands via REST.
const financialRealtimeDisconnectedInterval = Duration(seconds: 6);

/// When user is off financial screens or app is backgrounded, only re-check
/// the gate this often (no network I/O when still idle).
const financialRealtimeIdleGateInterval = Duration(seconds: 60);

typedef FinancialRefreshCancel = void Function();
typedef FinancialRefreshScheduler = FinancialRefreshCancel Function(
  Duration delay,
  void Function() callback,
);

/// Schedules financial refreshes serially so a slow request cannot overlap the
/// next polling cycle. Interval adapts to WebSocket connectivity and whether a
/// financial surface is active in the foreground.
class FinancialRealtimeRefreshLoop {
  FinancialRealtimeRefreshLoop({
    required Future<void> Function() refresh,
    this.connectedInterval = financialRealtimeFallbackInterval,
    this.disconnectedInterval = financialRealtimeDisconnectedInterval,
    this.idleGateInterval = financialRealtimeIdleGateInterval,
    bool Function()? isRealtimeConnected,
    bool Function()? isPollAllowed,
    FinancialRefreshScheduler scheduler = _scheduleFinancialRefresh,
  })  : _refresh = refresh,
        _isRealtimeConnected = isRealtimeConnected,
        _isPollAllowed = isPollAllowed,
        _scheduler = scheduler;

  final Future<void> Function() _refresh;
  final Duration connectedInterval;
  final Duration disconnectedInterval;
  final Duration idleGateInterval;
  final bool Function()? _isRealtimeConnected;
  final bool Function()? _isPollAllowed;
  final FinancialRefreshScheduler _scheduler;

  FinancialRefreshCancel? _cancelScheduledRefresh;
  bool _started = false;
  bool _refreshInFlight = false;
  bool _disposed = false;

  bool get _pollAllowed => _isPollAllowed?.call() ?? true;

  Duration get _currentInterval {
    if (!_pollAllowed) {
      return idleGateInterval;
    }
    final connected = _isRealtimeConnected?.call() ?? false;
    return connected ? connectedInterval : disconnectedInterval;
  }

  void start() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    // Immediate kick only when a financial surface needs data.
    if (_pollAllowed) {
      unawaited(_runRefresh());
    } else {
      _scheduleNext();
    }
  }

  /// Call when WS connects/disconnects so the next wait uses the right interval.
  void onConnectivityChanged() {
    if (_disposed || !_started || _refreshInFlight) return;
    _cancelScheduledRefresh?.call();
    _cancelScheduledRefresh = null;
    _scheduleNext();
  }

  /// Call when financial surface / foreground gate flips so we can poll sooner.
  void onPollGateChanged() {
    if (_disposed || !_started || _refreshInFlight) return;
    _cancelScheduledRefresh?.call();
    _cancelScheduledRefresh = null;
    if (_pollAllowed) {
      unawaited(_runRefresh());
    } else {
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (_disposed) {
      return;
    }

    final interval = _currentInterval;
    _cancelScheduledRefresh = _scheduler(interval, () {
      _cancelScheduledRefresh = null;
      unawaited(_runRefresh());
    });
  }

  Future<void> _runRefresh() async {
    if (_disposed || _refreshInFlight) {
      return;
    }

    // Idle gate: no HTTP — just re-arm the timer.
    if (!_pollAllowed) {
      _scheduleNext();
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

/// Provider do serviço WebSocket para atualizações de saldo em tempo real.
/// KeepAlive: autoDispose was tearing down the socket on brief unwatch/rebuilds
/// (common on Android navigation), leaving only the 15–30s poll path.
final balanceWebSocketServiceProvider =
    FutureProvider<BalanceWebSocketService?>((
  ref,
) async {
  // Keep the provider alive for the authenticated session.
  final link = ref.keepAlive();
  ref.onDispose(link.close);

  final authState = ref.watch(authControllerProvider);

  if (authState is! AuthAuthenticated) {
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: authenticated session required.');
    }
    return null;
  }

  // Watch the reactive Tor API URL
  final baseUrl = ref.watch(torApiUrlProvider);
  // Rebuild socket when HTTP silently refreshes the access token.
  ref.watch(sessionCredentialVersionProvider);

  final userId = authState.user.id;
  if (kDebugMode) {
    debugPrint('BalanceWebSocket: preparing balance stream.');
  }

  // Obter token JWT do armazenamento seguro
  String? token;
  var credentialLookupFailed = false;
  try {
    token = await ref.read(authLocalDataSourceProvider).getToken();
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: session credential lookup completed.');
    }
    token = _normalizeSessionToken(token);
  } catch (_) {
    credentialLookupFailed = true;
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
    resolveAuthToken: () async {
      try {
        final fresh = await ref.read(authLocalDataSourceProvider).getToken();
        return _normalizeSessionToken(fresh);
      } catch (_) {
        return null;
      }
    },
    onSessionInvalidated: () {
      if (kDebugMode) {
        debugPrint(
            'BalanceWebSocket: session invalidated by realtime channel.');
      }
      ref.read(sessionInvalidationProvider.notifier).emit();
    },
    onReconnectExhausted: () {
      if (!ref.mounted) return;
      if (kDebugMode) {
        debugPrint(
          'BalanceWebSocket: reconnect exhausted — forcing Tor REST catch-up.',
        );
      }
      ref.read(financialDirtyProvider.notifier).markDirty();
      _scheduleFinancialRefreshForEvent(
        ref,
        scope: FinancialRefreshScope.full,
        forceFullHistory: true,
      );
    },
    onTransaction: (json) {
      if (!ref.mounted) return;
      try {
        final tx = Transaction.fromJson(json);
        ref.read(lastTransactionHistoryProvider.notifier).upsertFront(tx);
        final scope = ref.read(sessionStorageScopeProvider);
        if (scope != null) {
          unawaited(
            ref.read(localTransactionHistoryStoreProvider).mergeAndPersist(
                sessionScope: scope,
                incoming: [tx]).catchError((_) => <Transaction>[]),
          );
        }
        // Primary theater path — same id as extrato row.
        final theater = payloadFromTransaction(tx, read: ref.read);
        if (theater != null) {
          presentIncomingTheater(
            ref.read(homeEducationQueueProvider.notifier),
            ref.read(homeBalanceReceivePulseProvider.notifier),
            theater,
          );
        }
        // Eventual consistency only — row already on screen.
        // Full pull: fan-out may still be in flight over Tor-like latency.
        _scheduleFinancialRefreshForEvent(
          ref,
          scope: FinancialRefreshScope.full,
          forceFullHistory: true,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BalanceWebSocket: transaction upsert rejected: $e');
        }
      }
    },
    onBtcPrice: (json) {
      if (!ref.mounted) return;
      try {
        final rates = BackendBtcRates.fromJson(json);
        ref.read(liveBackendBtcRatesProvider.notifier).apply(rates);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BalanceWebSocket: btc-price rejected: $e');
        }
      }
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
          _scheduleFinancialRefreshForEvent(ref);
        }
      } else {
        _scheduleFinancialRefreshForEvent(ref);
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

      // Fallback theater only when notif/tx WS did not already announce.
      final queue = ref.read(homeEducationQueueProvider.notifier);
      if (!queue.hasRecentIncomingEnqueue) {
        final creditPayload = payloadFromBalanceCredit(
          walletId: update.walletId,
          walletName: update.walletName,
          amountBtc: update.amount,
          context: update.context,
          kind: update.kind,
          bucket: update.bucket,
          read: ref.read,
        );
        if (creditPayload != null && ref.mounted) {
          presentIncomingTheater(
            queue,
            ref.read(homeBalanceReceivePulseProvider.notifier),
            creditPayload,
          );
        }
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
      final isIncoming = isIncomingTransactionNotification(notification);
      final appInForeground = ref.read(appForegroundProvider);

      // In-app feed must always receive financial events. OS alert prefs only
      // gate native shade below — otherwise center stays empty when alerts off.
      final isFinancial =
          NativeNotificationPresenter.isFinancialKind(notification.kind);
      if (keepForAlerts || isFinancial || isIncoming) {
        ref.read(sessionNotificationFeedProvider.notifier).add(notification);
      }

      // The in-app banner is the foreground acknowledgement surface. Incoming
      // transfers already have a dedicated Home theater celebration, so they
      // stay out of the banner to avoid presenting the same event twice.
      if (appInForeground && !isIncoming && !notification.read) {
        ref.read(notificationBannerProvider.notifier).show(notification);
      }

      // Single coordinator: balance + extrato (full on financial surfaces).
      // Money notifs assume Tor-latent fan-out — always full history catch-up.
      _scheduleFinancialRefreshForEvent(
        ref,
        scope: FinancialRefreshScope.full,
        forceFullHistory: isIncoming,
      );

      // Theater for receives (independent of OS alert prefs).
      // When the user is in the app, theater is the primary surface — not shade.
      if (isIncoming) {
        final optimistic = optimisticTransactionFromNotification(notification);
        if (optimistic != null) {
          ref
              .read(lastTransactionHistoryProvider.notifier)
              .upsertFront(optimistic);
          final scope = ref.read(sessionStorageScopeProvider);
          if (scope != null) {
            unawaited(
              ref.read(localTransactionHistoryStoreProvider).mergeAndPersist(
                  sessionScope: scope,
                  incoming: [optimistic]).catchError((_) => <Transaction>[]),
            );
          }
        }
        final theater = payloadFromNotification(
          notification,
          read: ref.read,
        );
        if (theater != null) {
          presentIncomingTheater(
            ref.read(homeEducationQueueProvider.notifier),
            ref.read(homeBalanceReceivePulseProvider.notifier),
            theater,
          );
        }
      }

      // Native Android/iOS shade: financial + security when prefs allow.
      // Skip shade for incoming while foreground — home theater owns that UX.
      final suppressNativeShade = isIncoming && appInForeground;
      if (keepForAlerts &&
          !suppressNativeShade &&
          NativeNotificationPresenter.isNativeAlertKind(notification.kind)) {
        unawaited(
          NotificationService().showSessionNotification(notification),
        );
        // Mark seen in BG isolate so the next REST poll does not re-alert.
        unawaited(markBackgroundNotificationsSeen([notification.id]));
      } else if (suppressNativeShade) {
        // Still mark seen so a later poll does not re-fire shade after leave.
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

  // Conectar ao WebSocket (soft-defer if credential lookup failed).
  if (credentialLookupFailed && token == null) {
    if (kDebugMode) {
      debugPrint(
        'BalanceWebSocket: deferring first connect until credential is ready.',
      );
    }
  } else {
    await service.connect();
  }
  if (!ref.mounted) {
    service.disconnect();
    return null;
  }

  // Core keeps the socket connected; HTTP poll is a bounded fallback only while
  // a financial surface is foregrounded. Off-surface / background = no poll I/O.
  final refreshLoop = FinancialRealtimeRefreshLoop(
    refresh: () => refreshFinancialProjection(
      ref,
      scope: FinancialRefreshScope.light,
    ),
    isRealtimeConnected: () => service.isConnected,
    isPollAllowed: () {
      if (!ref.mounted) return false;
      return ref.read(financialPollAllowedProvider);
    },
    scheduler: ref.read(financialRefreshSchedulerProvider),
  )..start();

  void onWsConnectivity(bool connected) {
    refreshLoop.onConnectivityChanged();
    if (!ref.mounted) return;
    if (!connected) {
      // Frames during Tor flap / broker restart are not replayed.
      ref.read(financialDirtyProvider.notifier).markDirty();
      return;
    }
    // Just reconnected: force one full REST catch-up for anything missed
    // while the socket was down (treat kfe→server as Tor-latent too).
    _scheduleFinancialRefreshForEvent(
      ref,
      scope: FinancialRefreshScope.full,
      forceFullHistory: true,
    );
  }

  service.addConnectionListener(onWsConnectivity);

  // Re-arm when user opens home/extrato or app resumes.
  final gateSub = ref.listen<bool>(
    financialPollAllowedProvider,
    (previous, next) {
      if (previous == next) return;
      refreshLoop.onPollGateChanged();
    },
  );

  // Desconectar quando o provider for descartado
  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('BalanceWebSocket: disconnecting.');
    }
    gateSub.close();
    service.removeConnectionListener(onWsConnectivity);
    refreshLoop.dispose();
    service.disconnect();
  });

  return service;
});

/// WS / notification event: refresh immediately while the app is foregrounded
/// (not only on financial surfaces). Background still marks dirty for resume.
///
/// Clears dirty **only** when wallets+history both succeed — Tor timeouts must
/// not pretend the ledger is clean.
void _scheduleFinancialRefreshForEvent(
  Ref ref, {
  FinancialRefreshScope scope = FinancialRefreshScope.light,
  bool forceFullHistory = false,
}) {
  ref.read(financialDirtyProvider.notifier).markDirty();
  final foreground = ref.read(appForegroundProvider);
  if (!foreground) {
    return;
  }
  unawaited(
    refreshFinancialProjection(
      ref,
      scope: scope,
      forceFullHistory: forceFullHistory,
    ).then((ok) {
      if (ok && ref.mounted) {
        ref.read(financialDirtyProvider.notifier).clear();
      }
    }),
  );
}

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
  if (normalized.isEmpty || normalized.length < 10) {
    return null;
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

Transaction? optimisticTransactionFromNotification(
    SessionNotificationItem notification) {
  if (!isIncomingTransactionNotification(notification)) return null;

  final meta = notification.metadata;
  final id = (notification.entityId ?? '').trim().isNotEmpty
      ? notification.entityId!.trim()
      : (meta['transactionId'] ?? meta['transaction_id'] ?? '').trim();
  if (id.isEmpty) return null;

  final satsRaw = meta['creditedSats'] ??
      meta['credited_sats'] ??
      meta['amountSats'] ??
      meta['amount_sats'] ??
      '';
  final sats = int.tryParse(satsRaw) ?? 0;
  if (sats <= 0) return null;

  final confs = int.tryParse(meta['confirmations'] ?? '') ?? 0;
  final rail = (meta['rail'] ?? meta['network'] ?? 'ONCHAIN').toUpperCase();
  final walletId = (meta['walletId'] ?? meta['wallet_id'] ?? '').trim();
  final settled =
      notification.kind == SessionNotificationItem.kindDepositConfirmed ||
          notification.kind == SessionNotificationItem.kindTransferReceived ||
          notification.kind == SessionNotificationItem.kindPaymentRequestPaid ||
          confs >= 3;

  return Transaction(
    id: id,
    fromAddress: '',
    toAddress: meta['address'] ?? meta['externalReference'] ?? '',
    walletId: walletId.isEmpty ? null : walletId,
    destinationWalletId: walletId.isEmpty ? null : walletId,
    amountSatoshis: sats,
    feeSatoshis: 0,
    status: settled
        ? TransactionStatus.confirmed
        : (confs > 0
            ? TransactionStatus.confirming
            : TransactionStatus.pending),
    type: TransactionType.receive,
    confirmations: confs,
    timestamp: notification.timestamp,
    updatedAt: notification.timestamp,
    blockchainTxid: meta['txid'] ?? meta['blockchainTxid'],
    description: notification.body,
    isInternal: rail.contains('INTERNAL') || rail.contains('LEDGER'),
    isLightning: rail.contains('LIGHT'),
    rail: rail.contains('LIGHT')
        ? 'LIGHTNING'
        : rail.contains('INTERNAL')
            ? 'INTERNAL'
            : 'ONCHAIN',
    provider: meta['provider'],
  );
}
