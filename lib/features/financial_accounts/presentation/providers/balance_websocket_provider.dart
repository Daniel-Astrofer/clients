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
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
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
      // Single coordinator: balance + extrato + links.
      ref.read(financialDirtyProvider.notifier).markDirty();
      unawaited(refreshFinancialProjection(ref).then((_) {
        ref.read(financialDirtyProvider.notifier).clear();
      }));

      if (_isTransactionNotification(notification)) {
        String finalTitle = notification.title;
        String finalBody = notification.body;

        final isIncoming = _isIncomingTransactionNotification(notification);
        final isOutgoing = notification.kind ==
                SessionNotificationItem.kindPaymentSent ||
            notification.kind == SessionNotificationItem.kindTransferSent;
        if (isIncoming) {
          String rede = 'Interna';
          if (notification.kind == SessionNotificationItem.kindDepositDetected ||
              notification.kind == SessionNotificationItem.kindDepositConfirmed) {
            rede = 'Onchain';
          } else if (notification.kind ==
              SessionNotificationItem.kindPaymentRequestPaid) {
            rede = 'Lightning';
          }

          finalTitle = 'Transferência $rede recebida';

          String amount = notification.metadata['amount'] ??
              notification.metadata['amountSats'] ??
              '';
          String walletName = notification.metadata['walletName'] ??
              notification.metadata['wallet_name'] ??
              '';

          if (amount.isEmpty || walletName.isEmpty) {
            final btcMatch = RegExp(r'([\d\.]+)\s*BTC', caseSensitive: false)
                .firstMatch(notification.body);
            if (btcMatch != null) amount = btcMatch.group(1)!;

            final emMatch = RegExp(r'em\s+([\w\s]+)', caseSensitive: false)
                .firstMatch(notification.body);
            if (emMatch != null) walletName = emMatch.group(1)!.trim();
          }

          if (walletName.isEmpty) {
            walletName = 'Principal';
          }

          if (amount.isNotEmpty) {
            if (amount.contains('.')) {
              amount = amount.replaceAll(RegExp(r'0+$'), '');
              if (amount.endsWith('.')) {
                amount = amount.substring(0, amount.length - 1);
              }
            }
            finalBody = 'Sua carteira $walletName recebeu $amount BTC.';
          } else {
            finalBody = notification.body;
          }

          // In-app education dialog + balance pulse on the home surface.
          final amountLabel =
              amount.isNotEmpty ? '$amount BTC' : 'fundos';
          enqueueIncomingTransfer(
            ref.read(homeEducationQueueProvider.notifier),
            ref.read(homeBalanceReceivePulseProvider.notifier),
            id: notification.dedupeKey.isNotEmpty
                ? notification.dedupeKey
                : notification.id,
            amountLabel: amountLabel,
            walletName: walletName,
            networkLabel: rede,
            subtitle: notification.body,
          );
        } else if (isOutgoing) {
          // Prefer server copy (cold outbound uses specific pt-BR titles).
          finalTitle = notification.title.isNotEmpty
              ? notification.title
              : 'Envio on-chain detectado';
          finalBody = notification.body;
        }

        unawaited(
          NotificationService().showTransactionNotification(
            id: _notificationIdFrom(notification.dedupeKey),
            title: finalTitle,
            body: finalBody,
            summary: null,
            payload: notification.deeplink,
            incoming: isIncoming,
            dedupeKey: notification.dedupeKey,
          ),
        );
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
