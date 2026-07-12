import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/core/providers/session_invalidation_provider.dart';
import 'package:kerosene/core/services/notification_service.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import '../../../../core/services/balance_websocket_service.dart';
import '../../../../core/providers/tor_providers.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import '../../../../core/utils/device_helper.dart';
import 'wallet_provider.dart';

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
      debugPrint(
        'BalanceWebSocket: periodic financial refresh failed; retrying later.',
      );
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
    debugPrint('BalanceWebSocket: authenticated session required.');
    return null;
  }

  // Watch the reactive Tor API URL
  final baseUrl = ref.watch(torApiUrlProvider);

  final userId = authState.user.id;
  debugPrint('BalanceWebSocket: preparing balance stream.');

  // Obter token JWT do armazenamento seguro
  String? token;
  try {
    token = await ref.read(authLocalDataSourceProvider).getToken();
    debugPrint('BalanceWebSocket: session credential lookup completed.');
    token = _normalizeSessionToken(token);
    if (token != null && token.length < 10) {
      debugPrint('BalanceWebSocket: session credential was rejected locally.');
    }
  } catch (_) {
    debugPrint('BalanceWebSocket: session credential unavailable.');
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
      debugPrint('BalanceWebSocket: session invalidated by realtime channel.');
      ref.read(sessionInvalidationProvider.notifier).emit();
    },
    onBalanceUpdate: (update) {
      debugPrint('BalanceWebSocket: balance update received.');

      // ── Detect balance increase and record synthetic transaction ──
      final currentWalletState = ref.read(walletProvider);
      if (currentWalletState is WalletLoaded) {
        final wallet = currentWalletState.wallets.firstWhere(
          (w) => w.name == update.walletName,
          orElse: () => currentWalletState.wallets.first,
        );

        final oldBalance = wallet.balance;
        final newBalance = update.newBalance;
        final delta = newBalance - oldBalance;
        final hasMeaningfulChange = delta.abs() > _balanceChangeEpsilon;

        if (hasMeaningfulChange) {
          ref.invalidate(transactionHistoryProvider);
          ref.invalidate(pagedTransactionHistoryProvider);
          ref.invalidate(depositsProvider);
          ref.invalidate(depositBalanceProvider);
          ref.invalidate(externalTransfersProvider);
        }

        // Notification title/body are backend-authored through onNotification.
        // Balance updates only refresh local state and cached financial data.
      }

      // Update wallet balance in state
      ref
          .read(walletProvider.notifier)
          .updateBalanceFromWebSocket(update.walletName, update.newBalance);
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
      if (!_shouldKeepNotification(notification, alertPreferences)) {
        return;
      }

      ref.read(sessionNotificationFeedProvider.notifier).add(notification);
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(pagedTransactionHistoryProvider);
      ref.invalidate(depositsProvider);
      ref.invalidate(depositBalanceProvider);
      unawaited(ref.read(walletProvider.notifier).refresh());

      if (_isTransactionNotification(notification)) {
        unawaited(
          NotificationService().showTransactionNotification(
            id: _notificationIdFrom(notification.dedupeKey),
            title: notification.title,
            body: notification.body,
            summary: 'Kerosene',
            payload: notification.deeplink,
            incoming: _isIncomingTransactionNotification(notification),
            dedupeKey: notification.dedupeKey,
          ),
        );
      } else if (alertPreferences.inAppBannersEnabled) {
        ref.read(notificationBannerProvider.notifier).show(notification);
      }
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
    refresh: () => _refreshFinancialState(ref, userId.toString()),
    scheduler: ref.read(financialRefreshSchedulerProvider),
  )..start();

  // Desconectar quando o provider for descartado
  ref.onDispose(() {
    debugPrint('BalanceWebSocket: disconnecting.');
    refreshLoop.dispose();
    service.disconnect();
  });

  return service;
});

Future<void> _refreshFinancialState(Ref ref, String sessionUserId) async {
  final authState = ref.read(authControllerProvider);
  if (authState is! AuthAuthenticated ||
      authState.user.id.toString() != sessionUserId) {
    return;
  }

  final walletNotifier = ref.read(walletProvider.notifier);

  // Invalidating the ledger repository also expires the session-scoped history
  // providers that sit behind the public history facades.
  ref.invalidate(ledgerRepositoryProvider);
  ref.invalidate(transactionHistoryProvider);
  ref.invalidate(pagedTransactionHistoryProvider);
  ref.invalidate(depositsProvider);
  ref.invalidate(depositBalanceProvider);
  ref.invalidate(depositDetailProvider);
  ref.invalidate(externalTransfersProvider);
  ref.invalidate(externalTransferDetailProvider);
  ref.invalidate(paymentLinksProvider);
  ref.invalidate(txStatusProvider);

  await walletNotifier.refresh();
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
  return normalized;
}

bool _isMockedBackendBitcoinEngagement(SessionNotificationItem notification) {
  final title = notification.title.toLowerCase();
  final entityType = notification.entityType?.toLowerCase();
  final source = notification.metadata['source']?.toLowerCase();

  return notification.kind == SessionNotificationItem.kindSystemInfo &&
      (title.contains('bitcoin em alta') || entityType == 'price_alert') &&
      source != 'pricetickerstream';
}

bool _shouldKeepNotification(
  SessionNotificationItem notification,
  AlertPreferencesState preferences,
) {
  if (_isMockedBackendBitcoinEngagement(notification)) {
    return false;
  }

  if (_isSecurityNotification(notification)) {
    return preferences.securityAlertsEnabled;
  }

  if (_isTransactionNotification(notification)) {
    return preferences.transactionAlertsEnabled;
  }

  if (notification.kind == SessionNotificationItem.kindMarketAlert) {
    return preferences.marketAlertsEnabled;
  }

  return true;
}

bool _isSecurityNotification(SessionNotificationItem notification) {
  return notification.kind ==
          SessionNotificationItem.kindSecurityLoginDetected ||
      notification.kind ==
          SessionNotificationItem.kindSecurityAdminAccessAttempt ||
      notification.kind ==
          SessionNotificationItem.kindSecurityRecoveryCompleted;
}

bool _isTransactionNotification(SessionNotificationItem notification) {
  return {
    SessionNotificationItem.kindTransferReceived,
    SessionNotificationItem.kindTransferSent,
    SessionNotificationItem.kindPaymentRequestCreated,
    SessionNotificationItem.kindPaymentRequestPaid,
    SessionNotificationItem.kindDepositDetected,
    SessionNotificationItem.kindDepositConfirmed,
    SessionNotificationItem.kindPaymentSent,
  }.contains(notification.kind);
}

bool _isIncomingTransactionNotification(SessionNotificationItem notification) {
  return {
    SessionNotificationItem.kindTransferReceived,
    SessionNotificationItem.kindPaymentRequestPaid,
    SessionNotificationItem.kindDepositDetected,
    SessionNotificationItem.kindDepositConfirmed,
  }.contains(notification.kind);
}

int _notificationIdFrom(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = 0x1fffffff & (hash + codeUnit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash == 0 ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : hash;
}
