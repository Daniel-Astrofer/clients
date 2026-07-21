import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/performance/frame_coalescer.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/domain/home_stage_fingerprint.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';

/// Live home surface state (HTTP snapshot + WebSocket patches).
final homeSurfaceProvider =
    NotifierProvider<HomeSurfaceNotifier, HomeSurface>(HomeSurfaceNotifier.new);

class HomeSurfaceNotifier extends Notifier<HomeSurface> {
  int _loadGeneration = 0;

  /// Batches high-frequency theater/scene WS tokens (~60Hz max).
  late final FrameCoalescer<HomeUiEvent> _theaterCoalescer;

  @override
  HomeSurface build() {
    _theaterCoalescer = FrameCoalescer<HomeUiEvent>(
      interval: const Duration(milliseconds: 16),
      onFlush: _applyEventNow,
    );
    ref.onDispose(_theaterCoalescer.dispose);

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated) {
        unawaitedRefresh();
      } else {
        state = HomeSurface.localDefaults();
      }
    });
    ref.listen<HomeLedgerBalanceView>(homeLedgerBalanceViewProvider,
        (prev, next) {
      if (prev != next) {
        unawaitedRefresh();
      }
    });
    ref.listen(appDisplayPreferencesProvider, (prev, next) {
      if (prev?.locale != next.locale ||
          prev?.timeZoneId != next.timeZoneId ||
          prev?.currency != next.currency) {
        unawaitedRefresh();
      }
    });

    // Kick initial load after first frame of provider creation.
    Future.microtask(unawaitedRefresh);
    return HomeSurface.localDefaults();
  }

  void unawaitedRefresh() {
    // ignore: discarded_futures
    refresh();
  }

  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      state = HomeSurface.localDefaults();
      return;
    }

    final generation = ++_loadGeneration;
    final view = ref.read(homeLedgerBalanceViewProvider);
    await ref
        .read(appDisplayPreferencesProvider.notifier)
        .refreshDeviceTimeZoneIfFollowing();
    if (!ref.mounted || generation != _loadGeneration) return;

    final displayPrefs = ref.read(appDisplayPreferencesProvider);
    final locale = displayPrefs.locale.languageCode;
    final timeZone = displayPrefs.timeZoneId;
    final balanceView = switch (view) {
      HomeLedgerBalanceView.platform => 'PLATFORM',
      HomeLedgerBalanceView.onChain => 'ONCHAIN',
      HomeLedgerBalanceView.cold => 'COLD',
      HomeLedgerBalanceView.total => 'TOTAL',
    };

    try {
      final client = ref.read(apiClientProvider);
      final cacheOpts = CacheOptions(
        store: null,
        policy: CachePolicy.refresh,
      ).toOptions();
      final response = await client.get(
        AppConfig.contentHomeSurface(
          balanceView: balanceView,
          locale: locale,
          timeZone: timeZone,
        ),
        options: cacheOpts.copyWith(
          responseType: ResponseType.json,
          extra: cacheOpts.extra,
        ),
      );
      if (!ref.mounted || generation != _loadGeneration) return;

      final payload = _extractSurfacePayload(response.data);
      if (payload == null) {
        debugPrint(
            '[homeSurface] unexpected payload type: ${response.data.runtimeType}');
        return;
      }
      var surface = HomeSurface.fromJson(payload);
      // Optimistic: hide ONCE stage already read locally (covers lag before BE filter).
      surface = _suppressLocallySeen(surface, auth.user);
      // Always keep an in-flight local theater piece across refresh.
      final prev = state.stage;
      if (prev.isActive && prev.id.startsWith('local-')) {
        surface = surface.withStage(prev);
      }
      state = surface;
      debugPrint(
        '[homeSurface] loaded version=${surface.version} '
        'feedItems=${surface.feed.items.length} '
        'stage=${surface.stage.kind.name}/${surface.stage.id}',
      );
    } catch (e, st) {
      debugPrint('[homeSurface] fetch failed: $e\n$st');
      // Keep last good state / local defaults — never wipe UX.
    }
  }

  /// Public ingress for realtime events. High-frequency stage/scene text
  /// tokens are coalesced to ~one UI update per frame; clears/snapshots are
  /// applied immediately so the stage never lags a structural change.
  void applyEvent(HomeUiEvent event) {
    if (_isCoalescableTheaterEvent(event)) {
      _theaterCoalescer.add(event);
      return;
    }
    // Structural / urgent: drain any pending tokens first (order preserved),
    // then apply this event immediately.
    _theaterCoalescer.flushPending();
    _applyEventNow(event);
  }

  bool _isCoalescableTheaterEvent(HomeUiEvent event) {
    return switch (event.type) {
      // Streaming theater text / atmosphere tokens (same id growth).
      HomeUiEventType.stage => _isSameStageStream(event),
      HomeUiEventType.scene => _isSameSceneStream(event),
      // Patch that only mutates stage/scene fields can storm during LLM stream.
      HomeUiEventType.patch => _patchIsTheaterOnly(event.payload),
      _ => false,
    };
  }

  /// Coalesce only while the same theater piece is streaming content.
  /// A brand-new stage id must open immediately (no 16ms lag).
  bool _isSameStageStream(HomeUiEvent event) {
    final currentId = state.stage.id;
    if (!state.stage.isActive || currentId.isEmpty) return false;
    final nextId = (event.payload['id'] ?? '').toString();
    return nextId.isNotEmpty && nextId == currentId;
  }

  bool _isSameSceneStream(HomeUiEvent event) {
    final current = ref.read(homeSceneProvider);
    if (!current.isActive || current.id.isEmpty) return false;
    final nextId = (event.payload['id'] ?? '').toString();
    return nextId.isNotEmpty && nextId == current.id;
  }

  bool _patchIsTheaterOnly(Map<String, dynamic> payload) {
    if (payload.isEmpty) return false;
    const theaterKeys = {
      'stage',
      'scene',
      'version',
      'schemaVersion',
      'atmosphere',
    };
    return payload.keys.every(theaterKeys.contains);
  }

  void _applyEventNow(HomeUiEvent event) {
    if (!ref.mounted) return;
    final auth = ref.read(authControllerProvider);
    final prevLocal = state.stage;
    var next = applyHomeUiEvent(state, event);
    if (auth is AuthAuthenticated) {
      next = _suppressLocallySeen(next, auth.user);
    }
    // Don't let WS snapshots wipe an active local theater tip/receive.
    if (prevLocal.isActive &&
        prevLocal.id.startsWith('local-') &&
        !next.stage.id.startsWith('local-')) {
      next = next.withStage(prevLocal);
    }
    if (!identical(next, state)) {
      state = next;
      debugPrint(
        '[homeSurface] event ${event.type.name} version=${event.version}',
      );
    }
    _bridgeSceneEvent(event);
  }

  void applyEventJson(Map<String, dynamic> json) {
    applyEvent(HomeUiEvent.fromJson(json));
  }

  void _bridgeSceneEvent(HomeUiEvent event) {
    // Scene-Driven path: pure scene payloads + clear, without SDUI widgets.
    try {
      switch (event.type) {
        case HomeUiEventType.scene:
          if (event.payload.isNotEmpty) {
            ref.read(homeSceneProvider.notifier).presentFromJson(event.payload);
          }
        case HomeUiEventType.sceneClear:
          ref.read(homeSceneProvider.notifier).clearOverride();
        case HomeUiEventType.stageClear:
          // Surface stage cleared — drop any pure-scene override too.
          ref.read(homeSceneProvider.notifier).clearOverride();
        case HomeUiEventType.snapshot:
        case HomeUiEventType.patch:
          // If snapshot/patch embeds a top-level `scene`, present it.
          final embedded = event.payload['scene'];
          if (embedded is Map) {
            ref
                .read(homeSceneProvider.notifier)
                .presentFromJson(Map<String, dynamic>.from(embedded));
          }
        default:
          break;
      }
    } catch (e, st) {
      debugPrint('[homeSurface] scene event bridge failed: $e\n$st');
    }
  }

  /// Hide stage immediately after the user finished reading (ONCE).
  void clearStage() {
    // Drop any queued tokens — clear must win over a late SSE fragment.
    _theaterCoalescer.cancelPending();
    if (!state.stage.isActive) return;
    state = state.clearStage();
    ref.read(homeSceneProvider.notifier).clearOverride();
  }

  /// Inject a client-built theater piece (education / receive). Does not hit BE.
  void presentLocalStage(HomeStage stage) {
    if (!stage.isActive) return;
    // Local pieces are user-facing now — never lag behind a pending WS token.
    _theaterCoalescer.flushPending();
    state = state.withStage(stage);
    debugPrint(
      '[homeSurface] local stage=${stage.id} kind=${stage.kind.name}',
    );
  }

  /// Persist + notify backend that this stage edition was received/read.
  Future<void> acknowledgeStageRead(HomeStage stage) async {
    if (!stage.isActive) return;
    if (stage.playPolicy != HomeStagePlayPolicy.once) return;

    // Local theater pieces (education / receive) never go to BE ack.
    final isLocal = stage.id.startsWith('local-');

    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      if (isLocal && state.stage.id == stage.id) {
        state = state.clearStage();
      }
      return;
    }

    final fingerprint = homeStageContentFingerprint(stage);
    await _rememberLocalSeen(auth.user, fingerprint);

    // Hide from surface so remounts/refreshes don't flash the same piece.
    if (state.stage.id == stage.id &&
        homeStageContentFingerprint(state.stage) == fingerprint) {
      state = state.clearStage();
    }

    if (isLocal) return;

    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        AppConfig.contentHomeStageAck,
        data: {
          'stageId': stage.id,
          'kind': stage.kind.name.toUpperCase(),
          'title': stage.content.title,
          'body': stage.content.body,
          'contentFingerprint': fingerprint,
          'status': 'READ',
        },
      );
      debugPrint(
        '[homeSurface] ack stage=${stage.id} fp=$fingerprint',
      );
    } catch (e, st) {
      debugPrint(
          '[homeSurface] ack failed (will retry via local cache): $e\n$st');
    }
  }

  HomeSurface _suppressLocallySeen(HomeSurface surface, User user) {
    final stage = surface.stage;
    if (!stage.isActive) return surface;
    // Never auto-clear client-injected theater (education / receive).
    if (stage.id.startsWith('local-')) return surface;
    if (stage.playPolicy != HomeStagePlayPolicy.once) return surface;
    final fp = homeStageContentFingerprint(stage);
    if (!_isLocallySeen(user, fp)) return surface;
    return surface.clearStage();
  }

  String _seenPrefsKey(User user) => 'home.stage.seen.${user.id}';

  bool _isLocallySeen(User user, String fingerprint) {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final raw = prefs.getStringList(_seenPrefsKey(user)) ?? const [];
      return raw.contains(fingerprint);
    } catch (_) {
      return false;
    }
  }

  Future<void> _rememberLocalSeen(User user, String fingerprint) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final key = _seenPrefsKey(user);
      final existing = List<String>.from(prefs.getStringList(key) ?? const []);
      if (existing.contains(fingerprint)) return;
      existing.add(fingerprint);
      // Cap growth — keep most recent 200 impressions.
      while (existing.length > 200) {
        existing.removeAt(0);
      }
      await prefs.setStringList(key, existing);
    } catch (e) {
      debugPrint('[homeSurface] local seen persist failed: $e');
    }
  }
}

/// Feed items projected from the surface (remote only; local fallback remains in UI).
final homeSurfaceFeedItemsProvider = Provider<List<HomeFeedItem>>((ref) {
  return ref.watch(homeSurfaceProvider).feed.items;
});

Map<String, dynamic>? _extractSurfacePayload(dynamic body) {
  dynamic current = body;

  for (var i = 0; i < 3; i++) {
    if (current is! String) break;
    final decoded = _tryDecodeJsonObject(current);
    if (decoded == null) return null;
    current = decoded;
  }

  if (current is! Map) return null;
  final root = Map<String, dynamic>.from(current);

  dynamic nested = root['data'];
  if (nested is String) {
    nested = _tryDecodeJsonObject(nested);
  }

  if (nested is Map &&
      (nested.containsKey('header') ||
          nested.containsKey('feed') ||
          nested.containsKey('schemaVersion'))) {
    return Map<String, dynamic>.from(nested);
  }

  if (root.containsKey('header') ||
      root.containsKey('feed') ||
      root.containsKey('schemaVersion')) {
    return root;
  }

  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return root;
}

dynamic _tryDecodeJsonObject(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1).trim();
  }
  final objStart = text.indexOf('{');
  final arrStart = text.indexOf('[');
  if (objStart >= 0 && (arrStart < 0 || objStart < arrStart)) {
    final end = text.lastIndexOf('}');
    if (end > objStart) text = text.substring(objStart, end + 1);
  } else if (arrStart >= 0) {
    final end = text.lastIndexOf(']');
    if (end > arrStart) text = text.substring(arrStart, end + 1);
  }
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}
