import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:kerosene/core/utils/app_date_time.dart';

typedef BalanceStompClientFactory = StompClient Function(StompConfig config);

class BalanceWebSocketReconnectPolicy {
  BalanceWebSocketReconnectPolicy({
    this.maxAttempts = 8,
    // Snappy reconnect on mobile Tor drop (was 5s → felt like "15s lag").
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 20),
  })  : assert(maxAttempts >= 0),
        assert(baseDelay >= Duration.zero),
        assert(maxDelay >= Duration.zero);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  int _attemptCount = 0;

  int get attemptCount => _attemptCount;

  Duration? nextDelay() {
    if (_attemptCount >= maxAttempts) {
      return null;
    }

    final multiplier = 1 << _attemptCount;
    final delay = Duration(
      milliseconds: baseDelay.inMilliseconds * multiplier,
    );
    _attemptCount += 1;

    return delay > maxDelay ? maxDelay : delay;
  }

  void reset() {
    _attemptCount = 0;
  }
}

typedef BalanceAuthTokenResolver = Future<String?> Function();

/// Serviço para WebSocket de atualizações de saldo em tempo real
class BalanceWebSocketService {
  StompClient? _stompClient;
  final String baseUrl;
  final String userId;
  String? _authToken;
  final String? deviceHash;
  final Function(BalanceUpdate) onBalanceUpdate;
  final Function(RealtimeNotificationEvent)? onNotification;
  final Function(Map<String, dynamic> event)? onHomeUiEvent;
  final Function(Map<String, dynamic> json)? onTransaction;
  final Function(Map<String, dynamic> json)? onBtcPrice;
  final VoidCallback? onSessionInvalidated;

  /// Fired once when reconnect backoff gives up (Tor flap / broker down).
  final VoidCallback? onReconnectExhausted;
  final BalanceAuthTokenResolver? resolveAuthToken;
  final BalanceWebSocketReconnectPolicy _reconnectPolicy;
  final BalanceStompClientFactory _stompClientFactory;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _manualDisconnect = false;
  bool _sessionInvalidated = false;
  bool _reconnectExhausted = false;
  bool _connectInFlight = false;
  bool _ignoreCloseEvents = false;
  bool _closeHandling = false;

  /// Prefer raw STOMP (`/ws/raw-balance`) on IO; SockJS as fallback.
  bool _preferRawWebSocket = !kIsWeb;
  bool _triedSockJsFallback = false;

  final List<void Function(bool connected)> _connectionListeners =
      <void Function(bool connected)>[];

  BalanceWebSocketService({
    required this.baseUrl,
    required this.userId,
    String? authToken,
    this.deviceHash,
    required this.onBalanceUpdate,
    this.onNotification,
    this.onHomeUiEvent,
    this.onTransaction,
    this.onBtcPrice,
    this.onSessionInvalidated,
    this.onReconnectExhausted,
    this.resolveAuthToken,
    BalanceWebSocketReconnectPolicy? reconnectPolicy,
    BalanceStompClientFactory? stompClientFactory,
  })  : _authToken = authToken,
        _reconnectPolicy = reconnectPolicy ?? BalanceWebSocketReconnectPolicy(),
        _stompClientFactory =
            stompClientFactory ?? ((config) => StompClient(config: config));

  bool get isConnected => _isConnected;
  bool get stoppedReconnecting => _sessionInvalidated || _reconnectExhausted;

  /// True after max reconnect attempts — REST catch-up required until rearm.
  bool get reconnectExhausted => _reconnectExhausted;

  /// Last known access token (may be refreshed via [resolveAuthToken]).
  String? get authToken => _authToken;

  /// Replace the JWT used on the next handshake (e.g. after silent refresh).
  void updateAuthToken(String? token) {
    _authToken = normalizeAuthToken(token);
  }

  void addConnectionListener(void Function(bool connected) listener) {
    _connectionListeners.add(listener);
  }

  void removeConnectionListener(void Function(bool connected) listener) {
    _connectionListeners.remove(listener);
  }

  void _notifyConnectionListeners() {
    for (final listener
        in List<void Function(bool)>.from(_connectionListeners)) {
      try {
        listener(_isConnected);
      } catch (_) {}
    }
  }

  /// Builds a STOMP URL. Raw WS is much more reliable on Android over the local
  /// Tor HTTP relay than SockJS (which needs extra HTTP info/handshake hops).
  static String resolveConnectUrl(String baseUrl, {required bool useRaw}) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (!useRaw) {
      return '$normalized/ws/balance';
    }
    final uri = Uri.parse(normalized);
    final scheme = switch (uri.scheme.toLowerCase()) {
      'https' => 'wss',
      'wss' => 'wss',
      'ws' => 'ws',
      _ => 'ws',
    };
    final host = uri.host.isEmpty ? '127.0.0.1' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://$host$port/ws/raw-balance';
  }

  /// Conecta ao WebSocket do backend via ponte local SOCKS5 (Tor)
  Future<void> connect() async {
    if (_sessionInvalidated) {
      if (kDebugMode) {
        debugPrint('BalanceWebSocketService: session already invalidated.');
      }
      return;
    }

    if (_stompClient != null && (_isConnected || _stompClient!.isActive)) {
      if (kDebugMode) {
        debugPrint('BalanceWebSocketService: already connected.');
      }
      return;
    }

    _manualDisconnect = false;
    _reconnectExhausted = false;
    _reconnectPolicy.reset();
    await _connectOnce();
  }

  /// Rearm after background / exhausted backoff. Safe to call on every resume.
  Future<void> ensureConnected({bool force = false}) async {
    if (_sessionInvalidated || _manualDisconnect) {
      return;
    }
    if (!force && _isConnected && (_stompClient?.isActive ?? false)) {
      return;
    }
    if (!force && _connectInFlight) {
      return;
    }
    if (!force && (_reconnectTimer?.isActive ?? false) && !_reconnectExhausted) {
      return;
    }

    _manualDisconnect = false;
    _reconnectExhausted = false;
    _reconnectPolicy.reset();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _triedSockJsFallback = false;
    _preferRawWebSocket = !kIsWeb;

    if (force || _stompClient != null) {
      _closeCurrentClient();
    }
    await _connectOnce();
  }

  Future<void> _connectOnce() async {
    if (_manualDisconnect || _sessionInvalidated || _connectInFlight) {
      return;
    }

    _connectInFlight = true;
    try {
      final token = await _currentAuthToken();
      if (token == null) {
        // Soft fail: missing/transient storage must not log the user out.
        // Resume / credential bump will call [ensureConnected] again.
        if (kDebugMode) {
          debugPrint(
            'BalanceWebSocketService: credential unavailable — deferring connect.',
          );
        }
        return;
      }

      final useRaw = _preferRawWebSocket;
      final fullUrl = resolveConnectUrl(baseUrl, useRaw: useRaw);

      if (kDebugMode) {
        debugPrint(
          'BalanceWebSocketService: connecting '
          '(${useRaw ? "raw" : "sockjs"}) → $fullUrl',
        );
      }

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        if (deviceHash != null) 'X-Device-Hash': deviceHash!,
      };

      final config = useRaw
          ? StompConfig(
              url: fullUrl,
              onConnect: _onConnect,
              onWebSocketError: _handleWebSocketError,
              onStompError: _handleStompError,
              onDisconnect: (_) {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: disconnected.');
                }
                _handleConnectionClosed('stomp disconnect');
              },
              beforeConnect: () async {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: starting handshake.');
                }
              },
              onWebSocketDone: () {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: socket closed.');
                }
                _handleConnectionClosed('socket closed');
              },
              webSocketConnectHeaders: headers,
              stompConnectHeaders: {
                'Authorization': 'Bearer $token',
              },
              reconnectDelay: Duration.zero,
              connectionTimeout: const Duration(seconds: 12),
              heartbeatIncoming: const Duration(seconds: 10),
              heartbeatOutgoing: const Duration(seconds: 10),
            )
          : StompConfig.sockJS(
              url: fullUrl,
              onConnect: _onConnect,
              onWebSocketError: _handleWebSocketError,
              onStompError: _handleStompError,
              onDisconnect: (_) {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: disconnected.');
                }
                _handleConnectionClosed('stomp disconnect');
              },
              beforeConnect: () async {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: starting handshake.');
                }
              },
              onWebSocketDone: () {
                if (kDebugMode) {
                  debugPrint('BalanceWebSocketService: socket closed.');
                }
                _handleConnectionClosed('socket closed');
              },
              webSocketConnectHeaders: headers,
              stompConnectHeaders: {
                'Authorization': 'Bearer $token',
              },
              reconnectDelay: Duration.zero,
              connectionTimeout: const Duration(seconds: 12),
              heartbeatIncoming: const Duration(seconds: 10),
              heartbeatOutgoing: const Duration(seconds: 10),
            );

      _stompClient = _stompClientFactory(config);
      _stompClient?.activate();
    } finally {
      _connectInFlight = false;
    }
  }

  /// Callback quando conectado ao WebSocket
  void _onConnect(StompFrame frame) {
    _isConnected = true;
    _triedSockJsFallback = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectPolicy.reset();
    _notifyConnectionListeners();
    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: connected.');
      debugPrint('BalanceWebSocketService: subscribing to balance feed.');
    }

    _stompClient?.subscribe(
      destination: '/user/queue/balance',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!);
            final update = BalanceUpdate.fromJson(json);

            if (kDebugMode) {
              if (kDebugMode) {
                debugPrint('BalanceWebSocketService: balance event decoded.');
              }
            }
            onBalanceUpdate(update);
          } catch (_) {
            if (kDebugMode) {
              if (kDebugMode) {
                debugPrint('BalanceWebSocketService: balance event rejected.');
              }
            }
          }
        }
      },
    );

    _stompClient?.subscribe(
      destination: '/user/queue/notifications',
      callback: (StompFrame frame) {
        if (frame.body == null) {
          return;
        }

        try {
          final json = jsonDecode(frame.body!);
          if (json is Map<String, dynamic>) {
            onNotification?.call(RealtimeNotificationEvent.fromJson(json));
          } else if (json is Map) {
            onNotification?.call(
              RealtimeNotificationEvent.fromJson(
                Map<String, dynamic>.from(json),
              ),
            );
          }
        } catch (_) {
          if (kDebugMode) {
            debugPrint('BalanceWebSocketService: notification event rejected.');
          }
        }
      },
    );

    _stompClient?.subscribe(
      destination: '/user/queue/home-ui',
      callback: (StompFrame frame) {
        if (frame.body == null || onHomeUiEvent == null) {
          return;
        }
        try {
          final json = jsonDecode(frame.body!);
          if (json is Map<String, dynamic>) {
            onHomeUiEvent!(json);
          } else if (json is Map) {
            onHomeUiEvent!(Map<String, dynamic>.from(json));
          }
        } catch (_) {
          if (kDebugMode) {
            debugPrint('BalanceWebSocketService: home-ui event rejected.');
          }
        }
      },
    );

    _stompClient?.subscribe(
      destination: '/user/queue/transactions',
      callback: (StompFrame frame) {
        if (frame.body == null || onTransaction == null) {
          return;
        }
        try {
          final json = jsonDecode(frame.body!);
          if (json is Map<String, dynamic>) {
            onTransaction!(json);
          } else if (json is Map) {
            onTransaction!(Map<String, dynamic>.from(json));
          }
        } catch (_) {
          if (kDebugMode) {
            debugPrint('BalanceWebSocketService: transaction event rejected.');
          }
        }
      },
    );

    _stompClient?.subscribe(
      destination: '/topic/btc-price',
      callback: (StompFrame frame) {
        if (frame.body == null || onBtcPrice == null) {
          return;
        }
        try {
          final json = jsonDecode(frame.body!);
          if (json is Map<String, dynamic>) {
            onBtcPrice!(json);
          } else if (json is Map) {
            onBtcPrice!(Map<String, dynamic>.from(json));
          }
        } catch (_) {
          if (kDebugMode) {
            debugPrint('BalanceWebSocketService: btc-price event rejected.');
          }
        }
      },
    );

    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: subscriptions ready.');
    }
  }

  /// Desconecta do WebSocket
  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectPolicy.reset();
    _connectInFlight = false;

    if (_stompClient == null) {
      if (_isConnected) {
        _isConnected = false;
        _notifyConnectionListeners();
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: disconnecting.');
    }
    _closeCurrentClient();
    if (_isConnected) {
      _isConnected = false;
      _notifyConnectionListeners();
    }
  }

  void _handleWebSocketError(dynamic error) {
    if (_ignoreCloseEvents || _manualDisconnect || _sessionInvalidated) {
      return;
    }
    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: socket error.');
    }
    final wasConnected = _isConnected;
    _isConnected = false;
    if (wasConnected) _notifyConnectionListeners();

    if (isSessionFailureSignal(error)) {
      _stopForInvalidSession('socket rejected session');
      return;
    }

    _handleConnectionClosed('socket error');
  }

  void _handleStompError(StompFrame frame) {
    if (_ignoreCloseEvents || _manualDisconnect || _sessionInvalidated) {
      return;
    }
    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: protocol error.');
    }
    final wasConnected = _isConnected;
    _isConnected = false;
    if (wasConnected) _notifyConnectionListeners();

    if (isSessionFailureSignal(frame.body) ||
        isSessionFailureSignal(frame.command) ||
        frame.headers.values.any(isSessionFailureSignal)) {
      _stopForInvalidSession('protocol rejected session');
      return;
    }

    _handleConnectionClosed('protocol error');
  }

  void _handleConnectionClosed(String reason) {
    if (_ignoreCloseEvents || _manualDisconnect || _sessionInvalidated) {
      return;
    }
    // onDisconnect + onWebSocketDone often fire together — handle once.
    if (_closeHandling) {
      return;
    }
    _closeHandling = true;
    try {
      final wasConnected = _isConnected;
      _isConnected = false;
      if (wasConnected) {
        _notifyConnectionListeners();
      }
      // One-shot fallback: if raw WS fails on this network, try SockJS once.
      if (_preferRawWebSocket && !_triedSockJsFallback) {
        _triedSockJsFallback = true;
        _preferRawWebSocket = false;
        if (kDebugMode) {
          debugPrint(
            'BalanceWebSocketService: raw WS failed ($reason) — falling back to SockJS.',
          );
        }
        _closeCurrentClient();
        if (!_manualDisconnect && !_sessionInvalidated) {
          unawaited(_connectOnce());
        }
        return;
      }
      _scheduleReconnect(reason);
    } finally {
      _closeHandling = false;
    }
  }

  void _scheduleReconnect(String reason) {
    if (_manualDisconnect || _sessionInvalidated || _reconnectExhausted) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }

    final delay = _reconnectPolicy.nextDelay();
    if (delay == null) {
      _reconnectExhausted = true;
      _closeCurrentClient();
      if (_isConnected) {
        _isConnected = false;
        _notifyConnectionListeners();
      }
      if (kDebugMode) {
        debugPrint(
          'BalanceWebSocketService: max reconnect attempts reached after '
          '$reason. Stopping until ensureConnected/rearm.',
        );
      }
      try {
        onReconnectExhausted?.call();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'BalanceWebSocketService: onReconnectExhausted failed: $e',
          );
        }
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'BalanceWebSocketService: reconnecting in ${delay.inSeconds}s '
        'after $reason (attempt ${_reconnectPolicy.attemptCount}/'
        '${_reconnectPolicy.maxAttempts}).',
      );
    }

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!_manualDisconnect && !_sessionInvalidated && !_reconnectExhausted) {
        // After a few failures prefer raw again (mobile Tor may have recovered).
        if (_reconnectPolicy.attemptCount >= 3) {
          _preferRawWebSocket = !kIsWeb;
        }
        unawaited(_connectOnce());
      }
    });
    _closeCurrentClient();
  }

  void _stopForInvalidSession(String reason) {
    if (_sessionInvalidated) {
      return;
    }

    _sessionInvalidated = true;
    _manualDisconnect = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeCurrentClient();
    if (kDebugMode) {
      debugPrint('BalanceWebSocketService: $reason. Stopping reconnects.');
    }
    onSessionInvalidated?.call();
  }

  void _closeCurrentClient() {
    final client = _stompClient;
    _stompClient = null;
    if (client == null) {
      return;
    }
    _ignoreCloseEvents = true;
    try {
      client.deactivate();
    } catch (_) {
      // Client may already be torn down by the peer.
    } finally {
      scheduleMicrotask(() {
        _ignoreCloseEvents = false;
      });
    }
  }

  Future<String?> _currentAuthToken() async {
    final resolver = resolveAuthToken;
    if (resolver != null) {
      try {
        final fresh = normalizeAuthToken(await resolver());
        if (fresh != null) {
          _authToken = fresh;
          return fresh;
        }
      } catch (_) {
        // Transient secure-storage failure — fall through to cached token.
      }
    }
    return _normalizedAuthToken;
  }

  String? get _normalizedAuthToken => normalizeAuthToken(_authToken);

  @visibleForTesting
  static String? normalizeAuthToken(String? token) {
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

  @visibleForTesting
  static bool isSessionFailureSignal(Object? value) {
    final text = value?.toString().toLowerCase() ?? '';
    if (text.isEmpty) {
      return false;
    }

    return text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthor') ||
        text.contains('forbidden') ||
        text.contains('authentication') ||
        text.contains('invalid session') ||
        text.contains('session invalid') ||
        text.contains('session expired') ||
        text.contains('invalid token') ||
        text.contains('token expired') ||
        text.contains('jwt expired') ||
        text.contains('jwt invalid');
  }
}

class RealtimeNotificationEvent {
  final String id;
  final String kind;
  final String severity;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? deeplink;
  final String? entityType;
  final String? entityId;
  final Map<String, String> metadata;

  RealtimeNotificationEvent({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.body,
    required this.timestamp,
    this.deeplink,
    this.entityType,
    this.entityId,
    this.metadata = const {},
  });

  factory RealtimeNotificationEvent.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['createdAt'] ?? json['timestamp'];
    final parsedTimestamp = AppDateTime.parse(rawTimestamp) ?? DateTime.now();
    final normalizedTitle = _normalizeText(
      json['title']?.toString(),
      fallback: 'Atualização',
    );
    final normalizedBody = _normalizeText(json['body']?.toString());
    final inferredKind = _normalizeKind(
      json['kind']?.toString(),
      title: normalizedTitle,
      body: normalizedBody,
    );
    final inferredSeverity = _normalizeSeverity(
      json['severity']?.toString(),
      kind: inferredKind,
      title: normalizedTitle,
      body: normalizedBody,
    );
    final metadata = _normalizeMetadata(json['metadata']);
    final id = _normalizeNullableText(json['id']?.toString()) ??
        '${parsedTimestamp.millisecondsSinceEpoch}|$inferredKind|$normalizedTitle|$normalizedBody';

    return RealtimeNotificationEvent(
      id: id,
      kind: inferredKind,
      severity: inferredSeverity,
      title: normalizedTitle,
      body: normalizedBody,
      timestamp: parsedTimestamp,
      deeplink: _normalizeNullableText(json['deeplink']?.toString()),
      entityType: _normalizeNullableText(json['entityType']?.toString()),
      entityId: _normalizeNullableText(json['entityId']?.toString()),
      metadata: metadata,
    );
  }

  int get systemNotificationId => id.hashCode & 0x7fffffff;

  static String _normalizeKind(
    String? rawValue, {
    required String title,
    required String body,
  }) {
    final normalized = _normalizeNullableText(rawValue)?.toLowerCase();
    if (normalized != null) {
      return normalized;
    }

    final combined = '$title $body'.toLowerCase();
    if (combined.contains('acesso detectado') ||
        combined.contains('login') ||
        combined.contains('sess')) {
      return 'security_login_detected';
    }
    if (combined.contains('recovery')) {
      return 'security_recovery_completed';
    }
    if (combined.contains('conta criada') ||
        combined.contains('account created')) {
      return 'account_created';
    }
    if (combined.contains('solicitação de pagamento') ||
        combined.contains('solicitacao de pagamento')) {
      return combined.contains('liquidada')
          ? 'payment_request_paid'
          : 'payment_request_created';
    }
    if (combined.contains('depósito identificado') ||
        combined.contains('deposito identificado')) {
      return 'deposit_detected';
    }
    if (combined.contains('depósito confirmado') ||
        combined.contains('deposito confirmado')) {
      return 'deposit_confirmed';
    }
    if (combined.contains('transferência recebida') ||
        combined.contains('transferencia recebida')) {
      return 'transfer_received';
    }
    if (combined.contains('transferência enviada') ||
        combined.contains('transferencia enviada')) {
      return 'transfer_sent';
    }
    if (combined.contains('transação transmitida') ||
        combined.contains('transacao transmitida') ||
        combined.contains('pagamento')) {
      return 'payment_sent';
    }
    return 'system_info';
  }

  static String _normalizeSeverity(
    String? rawValue, {
    required String kind,
    required String title,
    required String body,
  }) {
    final normalized = _normalizeNullableText(rawValue)?.toLowerCase();
    if (normalized == 'success' ||
        normalized == 'warning' ||
        normalized == 'error' ||
        normalized == 'info') {
      return normalized!;
    }

    switch (kind) {
      case 'security_login_detected':
      case 'security_recovery_completed':
        return 'warning';
      case 'account_created':
      case 'transfer_received':
      case 'payment_request_paid':
      case 'deposit_confirmed':
        return 'success';
      case 'payment_request_created':
      case 'deposit_detected':
      case 'transfer_sent':
      case 'payment_sent':
        return 'info';
      default:
        final combined = '$title $body'.toLowerCase();
        if (combined.contains('erro') ||
            combined.contains('error') ||
            combined.contains('failed')) {
          return 'error';
        }
        if (combined.contains('confirmad') ||
            combined.contains('criada') ||
            combined.contains('created') ||
            combined.contains('sucesso')) {
          return 'success';
        }
        return 'info';
    }
  }

  static Map<String, String> _normalizeMetadata(Object? rawMetadata) {
    if (rawMetadata is! Map) {
      return const {};
    }

    final normalized = <String, String>{};
    rawMetadata.forEach((key, value) {
      final normalizedKey = _normalizeNullableText(key?.toString());
      final normalizedValue = _normalizeNullableText(value?.toString());
      if (normalizedKey != null && normalizedValue != null) {
        normalized[normalizedKey] = normalizedValue;
      }
    });
    return normalized;
  }

  static String _normalizeText(String? rawValue, {String fallback = ''}) {
    if (rawValue == null) {
      return fallback;
    }

    final collapsed = rawValue.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) {
      return fallback;
    }
    return collapsed;
  }

  static String? _normalizeNullableText(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    final collapsed = rawValue.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? null : collapsed;
  }
}

/// Modelo de atualização de saldo recebida via WebSocket
class BalanceUpdate {
  final String walletId;
  final String walletName;
  final int userId;
  final double newBalance;
  final double amount;
  final String context;
  final String timestamp;

  final String? sender;
  final String? receiver;

  /// Optional dual-ledger snapshot (backend PR2+).
  final String? kind;
  final int? availableSats;
  final int? lockedSats;
  final int? pendingSats;
  final int? observedSats;
  final int? primarySats;
  final String? bucket;

  BalanceUpdate({
    required this.walletId,
    required this.walletName,
    required this.userId,
    required this.newBalance,
    required this.amount,
    required this.context,
    required this.timestamp,
    this.sender,
    this.receiver,
    this.kind,
    this.availableSats,
    this.lockedSats,
    this.pendingSats,
    this.observedSats,
    this.primarySats,
    this.bucket,
  });

  bool get hasBucketSnapshot =>
      availableSats != null || observedSats != null || primarySats != null;

  bool get isObservedBucket {
    final b = (bucket ?? '').toUpperCase();
    if (b == 'OBSERVED') return true;
    final c = context.toLowerCase();
    return c.contains('observ');
  }

  factory BalanceUpdate.fromJson(Map<String, dynamic> json) {
    final senderField = [json['sender'], json['from'], json['fromAddress']]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

    final receiverField = [json['receiver'], json['to'], json['toAddress']]
        .map((e) => e?.toString())
        .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

    int? asSats(Object? value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse('$value');
    }

    return BalanceUpdate(
      walletId: (json['walletId'] ?? '').toString(),
      walletName: json['walletName']?.toString() ?? '',
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      newBalance: (json['newBalance'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      context:
          json['context']?.toString() ?? json['description']?.toString() ?? '',
      timestamp:
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      sender: senderField,
      receiver: receiverField,
      kind: json['kind']?.toString(),
      availableSats: asSats(json['availableSats']),
      lockedSats: asSats(json['lockedSats']),
      pendingSats: asSats(json['pendingSats']),
      observedSats: asSats(json['observedSats']),
      primarySats: asSats(json['primarySats']),
      bucket: json['bucket']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'walletName': walletName,
      'userId': userId,
      'newBalance': newBalance,
      'amount': amount,
      'context': context,
      'timestamp': timestamp,
      if (kind != null) 'kind': kind,
      if (availableSats != null) 'availableSats': availableSats,
      if (lockedSats != null) 'lockedSats': lockedSats,
      if (pendingSats != null) 'pendingSats': pendingSats,
      if (observedSats != null) 'observedSats': observedSats,
      if (primarySats != null) 'primarySats': primarySats,
      if (bucket != null) 'bucket': bucket,
    };
  }

  @override
  String toString() {
    return 'BalanceUpdate(wallet: $walletName, newBalance: $newBalance BTC, amount: $amount, context: $context, bucket: $bucket)';
  }
}
