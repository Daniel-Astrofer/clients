import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/components/generic/app_primary_navigation.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_stage_playback_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeFontSize, homeSize;
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';
import 'package:kerosene/features/home/scene/renderer/action_layer.dart';
import 'package:kerosene/features/home/scene/renderer/content_layer.dart';
import 'package:kerosene/features/home/scene/renderer/media_layer.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';

/// Home theater host: curve-driven open/close + mid-screen content.
///
/// **Performance (cache):**
/// - Theater bodies are built once per scene id and kept behind [RepaintBoundary].
/// - [AnimatedBuilder] only rebuilds opacity/transform wrappers — not the body.
/// - After open+swap settle, drops the animated wrapper entirely (zero tick cost).
class HomeSceneHost extends ConsumerStatefulWidget {
  final String userName;
  final GlobalKey? notificationButtonKey;

  const HomeSceneHost({
    super.key,
    required this.userName,
    this.notificationButtonKey,
  });

  @override
  ConsumerState<HomeSceneHost> createState() => _HomeSceneHostState();
}

class _HomeSceneHostState extends ConsumerState<HomeSceneHost>
    with TickerProviderStateMixin {
  static const _openMs = 720;
  static const _swapMs = 520;

  Timer? _lifecycleTimer;
  String _sessionId = '';
  bool _finished = false;
  late final GlobalKey _localNotifKey = GlobalKey();

  late final AnimationController _openCtrl;
  late final AnimationController _swapCtrl;
  late final Animation<double> _openT;
  late final Animation<double> _swapT;

  HomeScene? _displayScene;
  HomeScene? _previousScene;
  bool _listenAttached = false;

  /// Cached theater bodies — rebuilt only when scene identity changes.
  final Map<String, Widget> _bodyCache = <String, Widget>{};
  String? _currentCacheKey;
  String? _previousCacheKey;

  /// True while any open/swap controller is mid-flight.
  bool get _animating =>
      _openCtrl.isAnimating ||
      _swapCtrl.isAnimating ||
      (_openCtrl.value > 0 && _openCtrl.value < 1) ||
      (_swapCtrl.value > 0 && _swapCtrl.value < 1 && _previousScene != null);

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _openMs),
    );
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _swapMs),
    )..value = 1;

    _openT = CurvedAnimation(
      parent: _openCtrl,
      curve: Curves.easeOutQuart,
      // Curve-out on dismiss so copy settles away (no ease-in snap at end).
      reverseCurve: Curves.easeOutCubic,
    );
    _swapT = CurvedAnimation(
      parent: _swapCtrl,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeOutCubic,
    );

    void onAnimTick() {
      // When both settle, rebuild once into the static (cached) path.
      if (!_animating && mounted) {
        setState(() {
          _previousScene = null;
          _previousCacheKey = null;
          _pruneBodyCache();
        });
      }
    }

    _openCtrl.addListener(onAnimTick);
    _swapCtrl.addListener(onAnimTick);

    _openCtrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {
          _displayScene = null;
          _previousScene = null;
          _currentCacheKey = null;
          _previousCacheKey = null;
          _bodyCache.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _lifecycleTimer?.cancel();
    _openCtrl.dispose();
    _swapCtrl.dispose();
    _bodyCache.clear();
    super.dispose();
  }

  void _pruneBodyCache() {
    final keep = <String>{
      if (_currentCacheKey != null) _currentCacheKey!,
      if (_previousCacheKey != null) _previousCacheKey!,
    };
    _bodyCache.removeWhere((k, _) => !keep.contains(k));
  }

  /// Structural cache key — **never** include streaming title/body text.
  /// Text lives in [_TheaterBody] via a selective provider watch.
  String _sceneCacheKey(HomeScene scene) =>
      '${scene.id}|${scene.layout.name}|${scene.media.type.name}|'
      '${scene.media.asset}|${scene.media.url}|${scene.cta.label}|'
      '${scene.cta.action}|${scene.content.textMode.name}|'
      '${scene.lifecycle.showDurationMs}';

  /// Open/swap identity — ignores token-by-token text growth.
  String _structuralSessionId(HomeScene scene) =>
      '${scene.id}|${scene.layout.name}|${scene.media.type.name}|'
      '${scene.media.asset}|${scene.cta.action}|${scene.hasForegroundContent}';

  /// Build once, reuse under [RepaintBoundary] for the whole open/swap.
  Widget _cachedBody(
    HomeScene scene, {
    required bool interactive,
    required bool liveContent,
  }) {
    final key = '${_sceneCacheKey(scene)}|live=$liveContent|i=$interactive';
    final hit = _bodyCache[key];
    if (hit != null) return hit;

    final built = RepaintBoundary(
      child: _TheaterBody(
        scene: scene,
        userName: widget.userName,
        liveContent: liveContent,
        onAction: interactive ? _onAction : null,
      ),
    );
    _bodyCache[key] = built;
    return built;
  }

  double get _midShift {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.18).clamp(72.0, 168.0);
  }

  void _applyBodyShift({required bool open}) {
    final playback = ref.read(homeStagePlaybackProvider.notifier);
    if (!open) {
      playback.close(
        durationMs: _openMs,
        curve: HomeStageCurveToken.easeOutCubic,
      );
      return;
    }
    final scene = _displayScene;
    if (scene == null) return;
    final stage = ref.read(homeSurfaceProvider).stage;
    final shift = HomeStageBodyShift(
      enabled: true,
      offsetPx: _midShift,
      durationMs: _openMs,
      curve: HomeStageCurveToken.easeOutCubic,
    );

    if (stage.isActive && stage.id == scene.id) {
      playback.play(
        HomeStage(
          id: stage.id,
          kind: stage.kind,
          playPolicy: stage.playPolicy,
          priority: stage.priority,
          content: stage.content,
          media: stage.media,
          layout: stage.layout,
          motion: HomeStageMotion(
            enter: stage.motion.enter,
            exit: stage.motion.exit,
            content: stage.motion.content,
            bodyShift: shift,
          ),
          lifecycle: stage.lifecycle,
          atmosphere: stage.atmosphere,
        ),
      );
    } else {
      playback.play(
        HomeStage(
          id: scene.id,
          kind: HomeStageKind.feature,
          playPolicy: scene.lifecycle.once
              ? HomeStagePlayPolicy.once
              : HomeStagePlayPolicy.loop,
          content: HomeStageContent(
            title: scene.content.title,
            body: scene.content.body,
          ),
          motion: HomeStageMotion(bodyShift: shift),
          lifecycle: HomeStageLifecycle(
            showDurationMs: scene.lifecycle.showDurationMs,
            restoreOnComplete: scene.lifecycle.restoreOnComplete,
          ),
        ),
      );
    }
  }

  void _armLifecycle(HomeScene scene, HomeStage stage) {
    _lifecycleTimer?.cancel();
    if (!scene.lifecycle.once || scene.media.type == SceneMediaType.video) {
      return;
    }
    final showMs = scene.lifecycle.showDurationMs.clamp(4000, 60000);
    _lifecycleTimer = Timer(Duration(milliseconds: showMs), () {
      if (!mounted) return;
      _complete(scene, stage);
    });
  }

  void _onSceneChanged(HomeScene scene) {
    final stage = ref.read(homeSurfaceProvider).stage;
    final id = _structuralSessionId(scene);
    final wantsOpen = scene.hasForegroundContent && !_finished;
    final reduce = KeroseneMotion.reduceMotion(context);

    if (wantsOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _precacheSceneMedia(scene);
      });
    }

    if (!wantsOpen) {
      if (_sessionId.isEmpty && _displayScene == null) return;
      _sessionId = id;
      _lifecycleTimer?.cancel();
      _applyBodyShift(open: false);
      final snapClose = reduce || !TickerMode.of(context);
      if (snapClose) {
        _openCtrl.value = 0;
        setState(() {
          _displayScene = null;
          _previousScene = null;
          _currentCacheKey = null;
          _previousCacheKey = null;
          _bodyCache.clear();
        });
      } else {
        _openCtrl.reverse();
      }
      return;
    }

    final wasOpen =
        _openCtrl.value > 0.05 || _openCtrl.status == AnimationStatus.completed;
    final isNewPiece = id != _sessionId;

    // Same theater piece with growing SSE text: content layer watches the
    // provider live — skip host setState / re-open / cache thrash.
    if (!isNewPiece && wasOpen && _displayScene != null) {
      _displayScene = scene;
      return;
    }

    _sessionId = id;
    _finished = false;

    // If an ancestor muted tickers (scroll-busy TickerMode, etc.), forward()
    // never advances — snap open so copy is visible immediately.
    final tickersEnabled = TickerMode.of(context);
    final snapOpen = reduce || !tickersEnabled;

    if (isNewPiece && wasOpen && _displayScene != null) {
      final prev = _displayScene!;
      final prevKey = _sceneCacheKey(prev);
      final nextKey = _sceneCacheKey(scene);
      // Warm both cache entries before the swap ticks.
      _cachedBody(prev, interactive: false, liveContent: false);
      _cachedBody(scene, interactive: true, liveContent: true);
      setState(() {
        _previousScene = prev;
        _previousCacheKey = prevKey;
        _displayScene = scene;
        _currentCacheKey = nextKey;
      });
      _applyBodyShift(open: true);
      _armLifecycle(scene, stage);
      if (snapOpen) {
        _swapCtrl.value = 1;
      } else {
        _swapCtrl.forward(from: 0);
      }
      return;
    }

    final key = _sceneCacheKey(scene);
    _cachedBody(scene, interactive: true, liveContent: true);
    setState(() {
      _previousScene = null;
      _previousCacheKey = null;
      _displayScene = scene;
      _currentCacheKey = key;
    });
    _applyBodyShift(open: true);
    _armLifecycle(scene, stage);
    if (snapOpen) {
      _openCtrl.value = 1;
      _swapCtrl.value = 1;
    } else {
      _swapCtrl.value = 1;
      _openCtrl.forward(from: 0);
    }
  }

  void _precacheSceneMedia(HomeScene scene) {
    final media = scene.media;
    if (!media.hasVisual) return;

    // Target: reduce Raster spikes by moving image decode/upload off the
    // critical frame where the theater opens/swaps.
    if (media.type != SceneMediaType.image) return;

    final url = media.url?.trim() ?? '';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheHeight = (homeSize(100) * dpr).round().clamp(1, 4096);

    ImageProvider provider;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      provider = ResizeImage(NetworkImage(url), height: cacheHeight);
    } else {
      final paths = SceneAssetCatalog.pathsFor(media);
      if (paths.isEmpty) return;
      provider = ResizeImage(AssetImage(paths.first), height: cacheHeight);
    }

    // ignore: discarded_futures
    precacheImage(provider, context);
  }

  void _complete(HomeScene scene, HomeStage stage) {
    if (_finished) return;
    _finished = true;
    _lifecycleTimer?.cancel();

    if (scene.lifecycle.restoreOnComplete) {
      ref.read(homeStagePlaybackProvider.notifier).close(
            durationMs: _openMs,
            curve: HomeStageCurveToken.easeOutCubic,
          );
    }

    if (stage.isActive &&
        (stage.id == scene.id ||
            scene.local == stage.id.startsWith('local-'))) {
      // ignore: discarded_futures
      ref.read(homeSurfaceProvider.notifier).acknowledgeStageRead(stage);
    } else if (scene.local) {
      ref.read(homeSceneProvider.notifier).clearOverride();
    }

    if (!mounted) return;
    final reduce = KeroseneMotion.reduceMotion(context);
    final snapClose = reduce || !TickerMode.of(context);
    if (snapClose) {
      _openCtrl.value = 0;
      setState(() {
        _displayScene = null;
        _previousScene = null;
        _currentCacheKey = null;
        _previousCacheKey = null;
        _bodyCache.clear();
      });
    } else {
      _openCtrl.reverse();
    }
  }

  void _onAction(String action) {
    final target = action.trim();
    if (target.isEmpty) return;
    if (target.startsWith('/')) {
      Navigator.of(context).pushNamed(target);
      return;
    }
    switch (target.toLowerCase()) {
      case 'open_lightning' || 'lightning':
        Navigator.of(context).pushNamed('/receive');
      case 'open_wallet' || 'wallet':
        Navigator.of(context).pushNamed('/wallets');
      case 'open_settings' || 'settings':
        AppPrimaryNavigationBar.navigateTo(
          context,
          AppPrimaryDestination.settings,
        );
      default:
        if (target.contains('_')) {
          Navigator.of(context).pushNamed('/$target');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Structural only — streaming title/body must not rebuild the host shell.
    ref.watch(
      homeSceneProvider.select(
        (s) =>
            '${s.id}|${s.layout.name}|${s.hasForegroundContent}|${s.media.type.name}',
      ),
    );
    final resting =
        ref.watch(homeSurfaceProvider.select((s) => s.restingHeader));
    final screenH = MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top;

    ref.listen<HomeScene>(homeSceneProvider, (prev, next) {
      _onSceneChanged(next);
    });
    if (!_listenAttached) {
      _listenAttached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onSceneChanged(ref.read(homeSceneProvider));
      });
    }

    final notifKey = widget.notificationButtonKey ?? _localNotifKey;
    final chrome = _HeaderChrome(notificationButtonKey: notifKey);
    // Keep copy under chrome, not mid-viewport — long pad buried receive text
    // into the balance/glow band on short phones.
    final midTopPad =
        (screenH * 0.04 - topInset * 0.1).clamp(10.0, 28.0);

    final greeting = _RestingGreetingText(
      userName: widget.userName,
      resting: resting,
    );

    final current = _displayScene;
    final previous = _previousScene;

    // Settled open — no AnimatedBuilder, only cached body (zero tick cost).
    if (current != null &&
        _openCtrl.value >= 0.999 &&
        (_previousScene == null || _swapCtrl.value >= 0.999) &&
        !_openCtrl.isAnimating &&
        !_swapCtrl.isAnimating) {
      final body = _cachedBody(current, interactive: true, liveContent: true);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              chrome,
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: midTopPad),
            child: body,
          ),
        ],
      );
    }

    // Settled closed.
    if (current == null && _openCtrl.value <= 0.001 && !_openCtrl.isAnimating) {
      return Row(
        children: [
          Expanded(child: greeting),
          chrome,
        ],
      );
    }

    // Warm cache for active scenes before ticks start painting.
    if (current != null) {
      _currentCacheKey = _sceneCacheKey(current);
      _cachedBody(current, interactive: true, liveContent: true);
    }
    if (previous != null) {
      _previousCacheKey = _sceneCacheKey(previous);
      _cachedBody(previous, interactive: false, liveContent: false);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_openCtrl, _swapCtrl]),
      // Static chrome/greeting don't rebuild every frame.
      child: chrome,
      builder: (context, chromeChild) {
        final open = _openT.value;
        final swap = _swapT.value;
        final showShell = open > 0.001 && current != null;

        final currentBody = current != null
            ? _bodyCache['${_sceneCacheKey(current)}|live=true|i=true'] ??
                _cachedBody(current, interactive: true, liveContent: true)
            : null;
        final previousBody = previous != null
            ? _bodyCache['${_sceneCacheKey(previous)}|live=false|i=false'] ??
                _cachedBody(previous, interactive: false, liveContent: false)
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: (1.0 - open).clamp(0.0, 1.0),
                    child: IgnorePointer(
                      ignoring: open > 0.35,
                      child: greeting,
                    ),
                  ),
                ),
                chromeChild!,
              ],
            ),
            if (showShell && currentBody != null)
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: open.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: open.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1.0 - open) * -18),
                      child: Padding(
                        padding: EdgeInsets.only(top: midTopPad * open),
                        child: _CrossfadeCached(
                          previous: previousBody,
                          current: currentBody,
                          progress: swap,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cross-fade only wrappers — [previous]/[current] are already cached bodies.
class _CrossfadeCached extends StatelessWidget {
  final Widget? previous;
  final Widget current;
  final double progress;

  const _CrossfadeCached({
    required this.previous,
    required this.current,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    if (previous == null || p >= 0.999) {
      return current;
    }

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: (1.0 - p).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -12 * p),
            child: previous,
          ),
        ),
        Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - p)),
            child: current,
          ),
        ),
      ],
    );
  }
}

/// Theater body shell. When [liveContent] is true, title/body stream from
/// [homeSceneProvider] so SSE tokens never rebuild the host or media/CTA.
class _TheaterBody extends ConsumerWidget {
  final HomeScene scene;
  final String userName;
  final bool liveContent;
  final SceneActionHandler? onAction;

  const _TheaterBody({
    required this.scene,
    required this.userName,
    this.liveContent = true,
    this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = liveContent
        ? ref.watch(
            homeSceneProvider.select((s) {
              if (s.id != scene.id) return scene.content;
              return s.content;
            }),
          )
        : scene.content;
    final media = liveContent
        ? ref.watch(
            homeSceneProvider.select((s) {
              if (s.id != scene.id) return scene.media;
              return s.media;
            }),
          )
        : scene.media;
    final cta = liveContent
        ? ref.watch(
            homeSceneProvider.select((s) {
              if (s.id != scene.id) return scene.cta;
              return s.cta;
            }),
          )
        : scene.cta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (media.hasVisual) ...[
          SceneMediaLayer(media: media, maxHeight: 100),
          SizedBox(height: homeSize(12)),
        ],
        SceneContentLayer(
          content: content,
          userName: userName,
          showDurationMs: scene.lifecycle.showDurationMs,
        ),
        if (cta.isActive) ...[
          SizedBox(height: homeSize(14)),
          Align(
            alignment: Alignment.centerLeft,
            child: SceneActionLayer(cta: cta, onAction: onAction),
          ),
        ],
      ],
    );
  }
}

class _HeaderChrome extends ConsumerWidget {
  final GlobalKey notificationButtonKey;

  const _HeaderChrome({required this.notificationButtonKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final notificationCount = ref.watch(sessionNotificationUnreadCountProvider);
    final gap = homeSize(8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomeHeaderIconButton(
          icon: balanceSettings.isHidden
              ? KeroseneIcons.eyeOff
              : KeroseneIcons.eye,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(balanceSettingsProvider.notifier).toggleVisibility();
          },
        ),
        SizedBox(width: gap),
        HomeHeaderIconButton(
          key: notificationButtonKey,
          icon: KeroseneIcons.notifications,
          hasBadge: notificationCount > 0,
          onTap: () async {
            HapticFeedback.selectionClick();
            await openNotificationCenter(
              context,
              originKey: notificationButtonKey,
            );
          },
        ),
        SizedBox(width: gap),
        HomeHeaderIconButton(
          icon: KeroseneIcons.settings,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/settings');
          },
        ),
      ],
    );
  }
}

class _RestingGreetingText extends StatelessWidget {
  final String userName;
  final HomeRestingHeader resting;

  const _RestingGreetingText({
    required this.userName,
    required this.resting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final hour = DateTime.now().hour;
    final text = !resting.includeName
        ? (hour < 12
            ? context.tr.homeGreetingMorning('').trim()
            : hour < 18
                ? context.tr.homeGreetingAfternoon('').trim()
                : context.tr.homeGreetingEvening('').trim())
        : hour < 12
            ? context.tr.homeGreetingMorning(userName)
            : hour < 18
                ? context.tr.homeGreetingAfternoon(userName)
                : context.tr.homeGreetingEvening(userName);

    final fontSize = responsive.compactFontSize(
      tiny: homeFontSize(22),
      compact: homeFontSize(24),
      regular: homeFontSize(25),
    );

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.newsreader(
        textStyle: theme.textTheme.titleLarge,
        color: theme.colorScheme.onSurface,
        fontSize: fontSize,
        fontWeight: FontWeight.w200,
        height: 1.1,
      ),
    );
  }
}
