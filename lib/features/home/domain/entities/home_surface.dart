// architecture-allow-large-file: server-driven home schema and compatibility
// decoding stay together to preserve backend payload contracts.
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';

/// Server-driven home surface composition.
/// schemaVersion 2 adds Communication Stage (theater); v1 greeting is adapted.

const int kHomeSurfaceSchemaVersion = 2;

const double kHomeSpacingMin = 0;
const double kHomeSpacingMax = 48;

enum HomeGreetingMode { staticMode, overrideMode, ticker, ephemeral, unknown }

enum HomeGreetingPlayPolicy { once, loop, unknown }

enum HomeGreetingAnimation { none, fade, slide, marquee, unknown }

enum HomeFeedHeightToken { compact, regular, expanded, unknown }

enum HomeFeedAnimationToken { none, fade, slide, pulse, unknown }

double clampHomeSpacing(num? value, {double fallback = 0}) {
  if (value == null) return fallback;
  final v = value.toDouble();
  if (v.isNaN) return fallback;
  return v.clamp(kHomeSpacingMin, kHomeSpacingMax).toDouble();
}

double resolveFeedHeightPx(HomeFeedHeightToken token, {double? heightPx}) {
  if (heightPx != null && heightPx > 0) {
    return heightPx.clamp(80, 320).toDouble();
  }
  return switch (token) {
    HomeFeedHeightToken.compact => 120,
    HomeFeedHeightToken.regular => 154,
    HomeFeedHeightToken.expanded => 200,
    HomeFeedHeightToken.unknown => 154,
  };
}

HomeGreetingMode parseGreetingMode(String? raw) {
  return switch ((raw ?? '').toUpperCase()) {
    'STATIC' => HomeGreetingMode.staticMode,
    'OVERRIDE' => HomeGreetingMode.overrideMode,
    'TICKER' => HomeGreetingMode.ticker,
    'EPHEMERAL' => HomeGreetingMode.ephemeral,
    _ => HomeGreetingMode.unknown,
  };
}

HomeGreetingPlayPolicy parsePlayPolicy(String? raw) {
  return switch ((raw ?? '').toUpperCase()) {
    'ONCE' => HomeGreetingPlayPolicy.once,
    'LOOP' => HomeGreetingPlayPolicy.loop,
    _ => HomeGreetingPlayPolicy.unknown,
  };
}

HomeGreetingAnimation parseGreetingAnimation(String? raw) {
  return switch ((raw ?? '').toUpperCase()) {
    'NONE' => HomeGreetingAnimation.none,
    'FADE' => HomeGreetingAnimation.fade,
    'SLIDE' => HomeGreetingAnimation.slide,
    'MARQUEE' => HomeGreetingAnimation.marquee,
    _ => HomeGreetingAnimation.unknown,
  };
}

HomeFeedHeightToken parseFeedHeightToken(String? raw) {
  return switch ((raw ?? '').toLowerCase()) {
    'compact' => HomeFeedHeightToken.compact,
    'regular' => HomeFeedHeightToken.regular,
    'expanded' => HomeFeedHeightToken.expanded,
    _ => HomeFeedHeightToken.unknown,
  };
}

HomeFeedAnimationToken parseFeedAnimationToken(String? raw) {
  return switch ((raw ?? '').toUpperCase()) {
    'NONE' => HomeFeedAnimationToken.none,
    'FADE' => HomeFeedAnimationToken.fade,
    'SLIDE' => HomeFeedAnimationToken.slide,
    'PULSE' => HomeFeedAnimationToken.pulse,
    _ => HomeFeedAnimationToken.unknown,
  };
}

class HomeStyleTokens {
  final String colorToken;
  final String fontWeight;

  const HomeStyleTokens({
    this.colorToken = 'white',
    this.fontWeight = 'w300',
  });

  factory HomeStyleTokens.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStyleTokens();
    return HomeStyleTokens(
      colorToken: (json['colorToken'] ?? 'white').toString(),
      fontWeight: (json['fontWeight'] ?? 'w300').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'colorToken': colorToken,
        'fontWeight': fontWeight,
      };

  HomeStyleTokens merge(HomeStyleTokens? other) {
    if (other == null) return this;
    return HomeStyleTokens(
      colorToken: other.colorToken.isNotEmpty ? other.colorToken : colorToken,
      fontWeight: other.fontWeight.isNotEmpty ? other.fontWeight : fontWeight,
    );
  }
}

class HomeActionVisibility {
  final bool visible;

  const HomeActionVisibility({this.visible = true});

  factory HomeActionVisibility.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeActionVisibility();
    final raw = json['visible'];
    if (raw is bool) return HomeActionVisibility(visible: raw);
    if (raw == null) return const HomeActionVisibility();
    return HomeActionVisibility(
        visible: raw.toString().toLowerCase() != 'false');
  }

  Map<String, dynamic> toJson() => {'visible': visible};

  HomeActionVisibility merge(HomeActionVisibility? other) => other ?? this;
}

class HomeHeaderActions {
  final HomeActionVisibility balanceVisibility;
  final HomeActionVisibility notifications;
  final HomeActionVisibility settings;

  const HomeHeaderActions({
    this.balanceVisibility = const HomeActionVisibility(),
    this.notifications = const HomeActionVisibility(),
    this.settings = const HomeActionVisibility(),
  });

  factory HomeHeaderActions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeHeaderActions();
    return HomeHeaderActions(
      balanceVisibility: HomeActionVisibility.fromJson(
        _asMap(json['balanceVisibility']),
      ),
      notifications: HomeActionVisibility.fromJson(
        _asMap(json['notifications']),
      ),
      settings: HomeActionVisibility.fromJson(_asMap(json['settings'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'balanceVisibility': balanceVisibility.toJson(),
        'notifications': notifications.toJson(),
        'settings': settings.toJson(),
      };

  HomeHeaderActions merge(HomeHeaderActions? other) {
    if (other == null) return this;
    return HomeHeaderActions(
      balanceVisibility: balanceVisibility.merge(other.balanceVisibility),
      notifications: notifications.merge(other.notifications),
      settings: settings.merge(other.settings),
    );
  }
}

class HomeHeaderSpacing {
  final double betweenActions;
  final double afterGreeting;

  const HomeHeaderSpacing({
    this.betweenActions = 8,
    this.afterGreeting = 12,
  });

  factory HomeHeaderSpacing.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeHeaderSpacing();
    return HomeHeaderSpacing(
      betweenActions: clampHomeSpacing(
        json['betweenActions'] is num
            ? json['betweenActions'] as num
            : num.tryParse('${json['betweenActions']}'),
        fallback: 8,
      ),
      afterGreeting: clampHomeSpacing(
        json['afterGreeting'] is num
            ? json['afterGreeting'] as num
            : num.tryParse('${json['afterGreeting']}'),
        fallback: 12,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'betweenActions': betweenActions,
        'afterGreeting': afterGreeting,
      };

  HomeHeaderSpacing merge(HomeHeaderSpacing? other) {
    if (other == null) return this;
    return HomeHeaderSpacing(
      betweenActions: other.betweenActions,
      afterGreeting: other.afterGreeting,
    );
  }
}

class HomeGreetingFallback {
  final String template;
  final bool includeName;

  const HomeGreetingFallback({
    this.template = 'TIME_OF_DAY',
    this.includeName = true,
  });

  factory HomeGreetingFallback.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeGreetingFallback();
    final include = json['includeName'];
    return HomeGreetingFallback(
      template: (json['template'] ?? 'TIME_OF_DAY').toString(),
      includeName: include is bool ? include : include?.toString() != 'false',
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template,
        'includeName': includeName,
      };
}

class HomeGreetingMessage {
  final String id;
  final String text;
  final int durationMs;
  final int priority;
  final HomeGreetingAnimation animation;
  final HomeStyleTokens style;
  final DateTime? expiresAt;

  const HomeGreetingMessage({
    required this.id,
    required this.text,
    this.durationMs = 4000,
    this.priority = 0,
    this.animation = HomeGreetingAnimation.fade,
    this.style = const HomeStyleTokens(),
    this.expiresAt,
  });

  factory HomeGreetingMessage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HomeGreetingMessage(id: '', text: '');
    }
    final durationRaw = json['durationMs'];
    final priorityRaw = json['priority'];
    final expiresRaw = json['expiresAt']?.toString();
    DateTime? expires;
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      expires = DateTime.tryParse(expiresRaw);
    }
    return HomeGreetingMessage(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      durationMs: durationRaw is num
          ? durationRaw.toInt()
          : int.tryParse(durationRaw?.toString() ?? '') ?? 4000,
      priority: priorityRaw is num
          ? priorityRaw.toInt()
          : int.tryParse(priorityRaw?.toString() ?? '') ?? 0,
      animation: parseGreetingAnimation(json['animation']?.toString()),
      style: HomeStyleTokens.fromJson(_asMap(json['style'])),
      expiresAt: expires,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'durationMs': durationMs,
        'priority': priority,
        'animation': switch (animation) {
          HomeGreetingAnimation.none => 'NONE',
          HomeGreetingAnimation.fade => 'FADE',
          HomeGreetingAnimation.slide => 'SLIDE',
          HomeGreetingAnimation.marquee => 'MARQUEE',
          HomeGreetingAnimation.unknown => 'FADE',
        },
        'style': style.toJson(),
        if (expiresAt != null)
          'expiresAt': expiresAt!.toUtc().toIso8601String(),
      };

  bool get isExpired {
    if (expiresAt == null) return false;
    return !expiresAt!.isAfter(DateTime.now().toUtc());
  }

  String resolveText(String userName) {
    return text.replaceAll('{name}', userName);
  }
}

class HomeGreetingRotation {
  final int intervalMs;
  final bool loop;

  const HomeGreetingRotation({
    this.intervalMs = 5000,
    this.loop = true,
  });

  factory HomeGreetingRotation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeGreetingRotation();
    final intervalRaw = json['intervalMs'];
    final loopRaw = json['loop'];
    return HomeGreetingRotation(
      intervalMs: intervalRaw is num
          ? intervalRaw.toInt().clamp(1000, 60000)
          : int.tryParse(intervalRaw?.toString() ?? '')?.clamp(1000, 60000) ??
              5000,
      // Default true only when key missing; explicit false means ONCE.
      loop: loopRaw is bool
          ? loopRaw
          : loopRaw == null
              ? true
              : loopRaw.toString().toLowerCase() != 'false',
    );
  }

  Map<String, dynamic> toJson() => {
        'intervalMs': intervalMs,
        'loop': loop,
      };
}

/// Server-driven playback while market lines are showing.
class HomeGreetingPresentation {
  final HomeGreetingPlayPolicy playPolicy;
  final bool hideActionsWhilePlaying;
  final bool restoreActionsAfterPlay;
  final bool pushDownBalanceWhilePlaying;
  final double pushDownBalancePx;
  final bool compressLayoutWhilePlaying;

  const HomeGreetingPresentation({
    this.playPolicy = HomeGreetingPlayPolicy.once,
    this.hideActionsWhilePlaying = true,
    this.restoreActionsAfterPlay = true,
    this.pushDownBalanceWhilePlaying = true,
    this.pushDownBalancePx = 28,
    this.compressLayoutWhilePlaying = true,
  });

  factory HomeGreetingPresentation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeGreetingPresentation();
    final pushRaw = json['pushDownBalancePx'];
    final policy = parsePlayPolicy(json['playPolicy']?.toString());
    return HomeGreetingPresentation(
      playPolicy: policy == HomeGreetingPlayPolicy.unknown
          ? HomeGreetingPlayPolicy.once
          : policy,
      hideActionsWhilePlaying: _bool(json['hideActionsWhilePlaying'], true),
      restoreActionsAfterPlay: _bool(json['restoreActionsAfterPlay'], true),
      pushDownBalanceWhilePlaying:
          _bool(json['pushDownBalanceWhilePlaying'], true),
      pushDownBalancePx: clampHomeSpacing(
        pushRaw is num ? pushRaw : num.tryParse('$pushRaw'),
        fallback: 28,
      ),
      compressLayoutWhilePlaying:
          _bool(json['compressLayoutWhilePlaying'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'playPolicy': switch (playPolicy) {
          HomeGreetingPlayPolicy.once => 'ONCE',
          HomeGreetingPlayPolicy.loop => 'LOOP',
          HomeGreetingPlayPolicy.unknown => 'ONCE',
        },
        'hideActionsWhilePlaying': hideActionsWhilePlaying,
        'restoreActionsAfterPlay': restoreActionsAfterPlay,
        'pushDownBalanceWhilePlaying': pushDownBalanceWhilePlaying,
        'pushDownBalancePx': pushDownBalancePx,
        'compressLayoutWhilePlaying': compressLayoutWhilePlaying,
      };

  HomeGreetingPresentation merge(HomeGreetingPresentation? other) {
    if (other == null) return this;
    return other;
  }

  static bool _bool(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw == null) return fallback;
    final s = raw.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }
}

class HomeGreetingConfig {
  final HomeGreetingMode mode;
  final HomeGreetingFallback fallback;
  final List<HomeGreetingMessage> messages;
  final HomeGreetingRotation rotation;
  final HomeStyleTokens style;
  final HomeGreetingPresentation presentation;

  const HomeGreetingConfig({
    this.mode = HomeGreetingMode.staticMode,
    this.fallback = const HomeGreetingFallback(),
    this.messages = const [],
    this.rotation = const HomeGreetingRotation(),
    this.style = const HomeStyleTokens(),
    this.presentation = const HomeGreetingPresentation(),
  });

  factory HomeGreetingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeGreetingConfig();
    final rawMessages = json['messages'];
    final rotation = HomeGreetingRotation.fromJson(_asMap(json['rotation']));
    var presentation =
        HomeGreetingPresentation.fromJson(_asMap(json['presentation']));
    // Infer ONCE when rotation.loop is false and policy omitted.
    if (_asMap(json['presentation']) == null && !rotation.loop) {
      presentation = const HomeGreetingPresentation(
        playPolicy: HomeGreetingPlayPolicy.once,
      );
    }
    return HomeGreetingConfig(
      mode: parseGreetingMode(json['mode']?.toString()),
      fallback: HomeGreetingFallback.fromJson(_asMap(json['fallback'])),
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((e) =>
                  HomeGreetingMessage.fromJson(Map<String, dynamic>.from(e)))
              .where((m) => m.text.isNotEmpty)
              .toList(growable: false)
          : const [],
      rotation: rotation,
      style: HomeStyleTokens.fromJson(_asMap(json['style'])),
      presentation: presentation,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': switch (mode) {
          HomeGreetingMode.staticMode => 'STATIC',
          HomeGreetingMode.overrideMode => 'OVERRIDE',
          HomeGreetingMode.ticker => 'TICKER',
          HomeGreetingMode.ephemeral => 'EPHEMERAL',
          HomeGreetingMode.unknown => 'STATIC',
        },
        'fallback': fallback.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(growable: false),
        'rotation': rotation.toJson(),
        'style': style.toJson(),
        'presentation': presentation.toJson(),
      };

  List<HomeGreetingMessage> get activeMessages {
    final active = messages
        .where((m) => !m.isExpired && m.text.isNotEmpty)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return active;
  }

  bool get isEphemeralOnce =>
      mode == HomeGreetingMode.ephemeral ||
      presentation.playPolicy == HomeGreetingPlayPolicy.once ||
      !rotation.loop;

  HomeGreetingConfig copyWith({
    HomeGreetingMode? mode,
    HomeGreetingFallback? fallback,
    List<HomeGreetingMessage>? messages,
    HomeGreetingRotation? rotation,
    HomeStyleTokens? style,
    HomeGreetingPresentation? presentation,
  }) {
    return HomeGreetingConfig(
      mode: mode ?? this.mode,
      fallback: fallback ?? this.fallback,
      messages: messages ?? this.messages,
      rotation: rotation ?? this.rotation,
      style: style ?? this.style,
      presentation: presentation ?? this.presentation,
    );
  }

  HomeGreetingConfig merge(HomeGreetingConfig? other) {
    if (other == null) return this;
    return HomeGreetingConfig(
      mode: other.mode == HomeGreetingMode.unknown ? mode : other.mode,
      fallback: other.fallback,
      messages: other.messages.isNotEmpty ? other.messages : messages,
      rotation: other.rotation,
      style: style.merge(other.style),
      presentation: presentation.merge(other.presentation),
    );
  }
}

class HomeHeaderConfig {
  final HomeGreetingConfig greeting;
  final HomeHeaderActions actions;
  final HomeHeaderSpacing spacing;

  const HomeHeaderConfig({
    this.greeting = const HomeGreetingConfig(),
    this.actions = const HomeHeaderActions(),
    this.spacing = const HomeHeaderSpacing(),
  });

  factory HomeHeaderConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeHeaderConfig();
    return HomeHeaderConfig(
      greeting: HomeGreetingConfig.fromJson(_asMap(json['greeting'])),
      actions: HomeHeaderActions.fromJson(_asMap(json['actions'])),
      spacing: HomeHeaderSpacing.fromJson(_asMap(json['spacing'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'greeting': greeting.toJson(),
        'actions': actions.toJson(),
        'spacing': spacing.toJson(),
      };

  HomeHeaderConfig merge(HomeHeaderConfig? other) {
    if (other == null) return this;
    return HomeHeaderConfig(
      greeting: greeting.merge(other.greeting),
      actions: actions.merge(other.actions),
      spacing: spacing.merge(other.spacing),
    );
  }
}

class HomeLayoutConfig {
  final double sectionGapAfterHeader;
  final double sectionGapAfterBalance;
  final double sectionGapBeforeFeed;
  final double? horizontalPadding;

  const HomeLayoutConfig({
    this.sectionGapAfterHeader = 18,
    this.sectionGapAfterBalance = 18,
    this.sectionGapBeforeFeed = 24,
    this.horizontalPadding,
  });

  factory HomeLayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeLayoutConfig();
    final padRaw = json['horizontalPadding'];
    final pad = padRaw == null
        ? null
        : clampHomeSpacing(
            padRaw is num ? padRaw : num.tryParse('$padRaw'),
          );
    return HomeLayoutConfig(
      sectionGapAfterHeader: clampHomeSpacing(
        json['sectionGapAfterHeader'] is num
            ? json['sectionGapAfterHeader'] as num
            : num.tryParse('${json['sectionGapAfterHeader']}'),
        fallback: 18,
      ),
      sectionGapAfterBalance: clampHomeSpacing(
        json['sectionGapAfterBalance'] is num
            ? json['sectionGapAfterBalance'] as num
            : num.tryParse('${json['sectionGapAfterBalance']}'),
        fallback: 18,
      ),
      sectionGapBeforeFeed: clampHomeSpacing(
        json['sectionGapBeforeFeed'] is num
            ? json['sectionGapBeforeFeed'] as num
            : num.tryParse('${json['sectionGapBeforeFeed']}'),
        fallback: 24,
      ),
      horizontalPadding: pad,
    );
  }

  Map<String, dynamic> toJson() => {
        'sectionGapAfterHeader': sectionGapAfterHeader,
        'sectionGapAfterBalance': sectionGapAfterBalance,
        'sectionGapBeforeFeed': sectionGapBeforeFeed,
        if (horizontalPadding != null) 'horizontalPadding': horizontalPadding,
      };

  HomeLayoutConfig merge(HomeLayoutConfig? other) {
    if (other == null) return this;
    return HomeLayoutConfig(
      sectionGapAfterHeader: other.sectionGapAfterHeader,
      sectionGapAfterBalance: other.sectionGapAfterBalance,
      sectionGapBeforeFeed: other.sectionGapBeforeFeed,
      horizontalPadding: other.horizontalPadding ?? horizontalPadding,
    );
  }
}

class HomeFeedSurface {
  final HomeFeedHeightToken heightToken;
  final double? heightPx;
  final double cardPadding;
  final double gap;
  final HomeFeedAnimationToken defaultAnimation;
  final List<HomeFeedItem> items;

  const HomeFeedSurface({
    this.heightToken = HomeFeedHeightToken.regular,
    this.heightPx,
    this.cardPadding = 18,
    this.gap = 8,
    this.defaultAnimation = HomeFeedAnimationToken.none,
    this.items = const [],
  });

  factory HomeFeedSurface.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeFeedSurface();
    final rawItems = json['items'];
    final heightPxRaw = json['heightPx'];
    return HomeFeedSurface(
      heightToken: parseFeedHeightToken(json['heightToken']?.toString()),
      heightPx: heightPxRaw is num
          ? heightPxRaw.toDouble()
          : double.tryParse(heightPxRaw?.toString() ?? ''),
      cardPadding: clampHomeSpacing(
        json['cardPadding'] is num
            ? json['cardPadding'] as num
            : num.tryParse('${json['cardPadding']}'),
        fallback: 18,
      ),
      gap: clampHomeSpacing(
        json['gap'] is num
            ? json['gap'] as num
            : num.tryParse('${json['gap']}'),
        fallback: 8,
      ),
      defaultAnimation:
          parseFeedAnimationToken(json['defaultAnimation']?.toString()),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => HomeFeedItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'heightToken': switch (heightToken) {
          HomeFeedHeightToken.compact => 'compact',
          HomeFeedHeightToken.regular => 'regular',
          HomeFeedHeightToken.expanded => 'expanded',
          HomeFeedHeightToken.unknown => 'regular',
        },
        if (heightPx != null) 'heightPx': heightPx,
        'cardPadding': cardPadding,
        'gap': gap,
        'defaultAnimation': switch (defaultAnimation) {
          HomeFeedAnimationToken.none => 'NONE',
          HomeFeedAnimationToken.fade => 'FADE',
          HomeFeedAnimationToken.slide => 'SLIDE',
          HomeFeedAnimationToken.pulse => 'PULSE',
          HomeFeedAnimationToken.unknown => 'NONE',
        },
        'items': items
            .map(
              (i) => {
                'id': i.id,
                'kind': i.kind.name.toUpperCase(),
                'priority': i.priority,
                'title': i.title,
                'body': i.body,
                'tag': i.tag,
                'surfaceTint': i.surfaceTint,
                if (i.campaignId != null) 'campaignId': i.campaignId,
              },
            )
            .toList(growable: false),
      };

  double get resolvedHeight =>
      resolveFeedHeightPx(heightToken, heightPx: heightPx);

  HomeFeedSurface copyWith({
    HomeFeedHeightToken? heightToken,
    double? heightPx,
    double? cardPadding,
    double? gap,
    HomeFeedAnimationToken? defaultAnimation,
    List<HomeFeedItem>? items,
  }) {
    return HomeFeedSurface(
      heightToken: heightToken ?? this.heightToken,
      heightPx: heightPx ?? this.heightPx,
      cardPadding: cardPadding ?? this.cardPadding,
      gap: gap ?? this.gap,
      defaultAnimation: defaultAnimation ?? this.defaultAnimation,
      items: items ?? this.items,
    );
  }

  HomeFeedSurface merge(HomeFeedSurface? other) {
    if (other == null) return this;
    return HomeFeedSurface(
      heightToken: other.heightToken == HomeFeedHeightToken.unknown
          ? heightToken
          : other.heightToken,
      heightPx: other.heightPx ?? heightPx,
      cardPadding: other.cardPadding,
      gap: other.gap,
      defaultAnimation: other.defaultAnimation == HomeFeedAnimationToken.unknown
          ? defaultAnimation
          : other.defaultAnimation,
      items: other.items.isNotEmpty ? other.items : items,
    );
  }
}

class HomeSurface {
  final int schemaVersion;
  final String version;
  final int ttlSeconds;
  final String balanceView;
  final String locale;
  final String timeZone;
  final HomeLayoutConfig layout;
  final HomeHeaderConfig header;
  final HomeFeedSurface feed;

  /// Communication theater (schema v2). Idle when none.
  final HomeStage stage;
  final HomeRestingHeader restingHeader;

  const HomeSurface({
    this.schemaVersion = kHomeSurfaceSchemaVersion,
    this.version = '',
    this.ttlSeconds = 300,
    this.balanceView = 'TOTAL',
    this.locale = 'pt',
    this.timeZone = 'UTC',
    this.layout = const HomeLayoutConfig(),
    this.header = const HomeHeaderConfig(),
    this.feed = const HomeFeedSurface(),
    this.stage = const HomeStage(),
    this.restingHeader = const HomeRestingHeader(),
  });

  /// Defaults matching current hardcoded home UX (offline / error fallback).
  factory HomeSurface.localDefaults({
    String balanceView = 'TOTAL',
    String locale = 'pt',
    String timeZone = 'UTC',
    List<HomeFeedItem> items = const [],
  }) {
    return HomeSurface(
      schemaVersion: kHomeSurfaceSchemaVersion,
      version: 'local',
      ttlSeconds: 300,
      balanceView: balanceView,
      locale: locale,
      timeZone: timeZone,
      layout: const HomeLayoutConfig(),
      header: const HomeHeaderConfig(),
      feed: HomeFeedSurface(items: items),
      stage: HomeStage.idle(),
      restingHeader: const HomeRestingHeader(),
    );
  }

  factory HomeSurface.fromJson(Map<String, dynamic> json) {
    final schemaRaw = json['schemaVersion'];
    final ttlRaw = json['ttlSeconds'];
    final schemaVersion = schemaRaw is num
        ? schemaRaw.toInt()
        : int.tryParse(schemaRaw?.toString() ?? '') ?? 1;
    final header = HomeHeaderConfig.fromJson(_asMap(json['header']));
    HomeStage stage = HomeStage.fromJson(_asMap(json['stage']));
    // Adapter v1 → stage when only greeting ephemeral exists.
    if (!stage.isActive) {
      final legacy = HomeStage.fromLegacyGreeting(header.greeting);
      if (legacy.isActive) stage = legacy;
    }
    return HomeSurface(
      schemaVersion: schemaVersion,
      version: (json['version'] ?? '').toString(),
      ttlSeconds: ttlRaw is num
          ? ttlRaw.toInt()
          : int.tryParse(ttlRaw?.toString() ?? '') ?? 300,
      balanceView: (json['balanceView'] ?? 'TOTAL').toString(),
      locale: (json['locale'] ?? 'pt').toString(),
      timeZone: (json['timeZone'] ?? json['timezone'] ?? 'UTC').toString(),
      layout: HomeLayoutConfig.fromJson(_asMap(json['layout'])),
      header: header,
      feed: HomeFeedSurface.fromJson(_asMap(json['feed'])),
      stage: stage,
      restingHeader: HomeRestingHeader.fromJson(_asMap(json['restingHeader'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'version': version,
        'ttlSeconds': ttlSeconds,
        'balanceView': balanceView,
        'locale': locale,
        'timeZone': timeZone,
        'layout': layout.toJson(),
        'header': header.toJson(),
        'stage': stage.toJson(),
        'restingHeader': restingHeader.toJson(),
        'feed': feed.toJson(),
      };

  HomeSurface copyWith({
    int? schemaVersion,
    String? version,
    int? ttlSeconds,
    String? balanceView,
    String? locale,
    String? timeZone,
    HomeLayoutConfig? layout,
    HomeHeaderConfig? header,
    HomeFeedSurface? feed,
    HomeStage? stage,
    HomeRestingHeader? restingHeader,
  }) {
    return HomeSurface(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      version: version ?? this.version,
      ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      balanceView: balanceView ?? this.balanceView,
      locale: locale ?? this.locale,
      timeZone: timeZone ?? this.timeZone,
      layout: layout ?? this.layout,
      header: header ?? this.header,
      feed: feed ?? this.feed,
      stage: stage ?? this.stage,
      restingHeader: restingHeader ?? this.restingHeader,
    );
  }

  /// Deep partial merge from a patch map (HOME_UI_PATCH / override overlay).
  HomeSurface applyPatch(Map<String, dynamic> patch) {
    final merged = deepMergeMaps(toJson(), patch);
    return HomeSurface.fromJson(merged);
  }

  HomeSurface enqueueGreeting(HomeGreetingMessage message) {
    final next = [...header.greeting.messages, message];
    final greeting = header.greeting.copyWith(
      mode: HomeGreetingMode.ephemeral,
      messages: next,
      rotation: const HomeGreetingRotation(intervalMs: 7000, loop: false),
      presentation: const HomeGreetingPresentation(
        playPolicy: HomeGreetingPlayPolicy.once,
      ),
    );
    final withHeader = copyWith(
      header: HomeHeaderConfig(
        greeting: greeting,
        actions: header.actions,
        spacing: header.spacing,
      ),
    );
    return withHeader.copyWith(
      stage: HomeStage.fromLegacyGreeting(withHeader.header.greeting),
    );
  }

  HomeSurface withStage(HomeStage next) => copyWith(stage: next);

  HomeSurface clearStage() => copyWith(stage: HomeStage.idle());
}

enum HomeUiEventType {
  snapshot,
  patch,
  greeting,
  feedDelta,
  stage,
  stageClear,

  /// Scene-Driven UI payload (layout/background/media/content — not widgets).
  scene,
  sceneClear,
  unknown,
}

class HomeUiEvent {
  final HomeUiEventType type;
  final String version;
  final Map<String, dynamic> payload;

  const HomeUiEvent({
    required this.type,
    required this.version,
    required this.payload,
  });

  factory HomeUiEvent.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] ?? '').toString().toUpperCase();
    final type = switch (typeRaw) {
      'HOME_UI_SNAPSHOT' => HomeUiEventType.snapshot,
      'HOME_UI_PATCH' => HomeUiEventType.patch,
      'HOME_UI_GREETING' => HomeUiEventType.greeting,
      'HOME_UI_FEED_DELTA' => HomeUiEventType.feedDelta,
      'HOME_UI_STAGE' => HomeUiEventType.stage,
      'HOME_UI_STAGE_CLEAR' => HomeUiEventType.stageClear,
      'HOME_UI_SCENE' => HomeUiEventType.scene,
      'HOME_UI_SCENE_CLEAR' => HomeUiEventType.sceneClear,
      _ => HomeUiEventType.unknown,
    };
    final payloadRaw = json['payload'];
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};
    return HomeUiEvent(
      type: type,
      version: (json['version'] ?? '').toString(),
      payload: payload,
    );
  }
}

/// Applies a realtime event onto the current surface state.
HomeSurface applyHomeUiEvent(HomeSurface current, HomeUiEvent event) {
  if (event.type == HomeUiEventType.unknown) {
    return current;
  }
  // Drop stale versions when both are ISO timestamps / comparable strings.
  if (event.version.isNotEmpty &&
      current.version.isNotEmpty &&
      current.version != 'local' &&
      event.version.compareTo(current.version) < 0) {
    return current;
  }

  switch (event.type) {
    case HomeUiEventType.snapshot:
      if (event.payload.isEmpty) return current;
      return HomeSurface.fromJson(event.payload);
    case HomeUiEventType.patch:
      if (event.payload.isEmpty) return current;
      final patched = current.applyPatch(event.payload);
      return patched.copyWith(
        version: event.version.isNotEmpty ? event.version : patched.version,
      );
    case HomeUiEventType.greeting:
      final message = HomeGreetingMessage.fromJson(event.payload);
      if (message.text.isEmpty) return current;
      return current.enqueueGreeting(message).copyWith(
            version: event.version.isNotEmpty ? event.version : current.version,
          );
    case HomeUiEventType.stage:
      final stage = HomeStage.fromJson(event.payload);
      return current.withStage(stage).copyWith(
            version: event.version.isNotEmpty ? event.version : current.version,
          );
    case HomeUiEventType.stageClear:
      return current.clearStage().copyWith(
            version: event.version.isNotEmpty ? event.version : current.version,
          );
    // Scene events update surface stage only when payload can bridge to stage;
    // pure scene presentation is handled by HomeSceneNotifier (applyEventJson).
    case HomeUiEventType.scene:
      if (event.payload.isEmpty) return current;
      // If payload looks like a legacy stage, keep surface.stage in sync.
      if (event.payload.containsKey('kind') ||
          event.payload.containsKey('playPolicy')) {
        final stage = HomeStage.fromJson(event.payload);
        return current.withStage(stage).copyWith(
              version:
                  event.version.isNotEmpty ? event.version : current.version,
            );
      }
      return current.copyWith(
        version: event.version.isNotEmpty ? event.version : current.version,
      );
    case HomeUiEventType.sceneClear:
      return current.clearStage().copyWith(
            version: event.version.isNotEmpty ? event.version : current.version,
          );
    case HomeUiEventType.feedDelta:
      return _applyFeedDelta(current, event.payload).copyWith(
        version: event.version.isNotEmpty ? event.version : current.version,
      );
    case HomeUiEventType.unknown:
      return current;
  }
}

HomeSurface _applyFeedDelta(HomeSurface current, Map<String, dynamic> payload) {
  final op = (payload['op'] ?? payload['operation'] ?? 'REPLACE')
      .toString()
      .toUpperCase();
  final itemsRaw = payload['items'];
  final items = itemsRaw is List
      ? itemsRaw
          .whereType<Map>()
          .map((e) => HomeFeedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList()
      : <HomeFeedItem>[];

  if (op == 'REPLACE' || op == 'SET') {
    return current.copyWith(feed: current.feed.copyWith(items: items));
  }
  if (op == 'APPEND' || op == 'ADD') {
    return current.copyWith(
      feed: current.feed.copyWith(items: [...current.feed.items, ...items]),
    );
  }
  if (op == 'REMOVE') {
    final ids = items.map((e) => e.id).toSet();
    final singleId = payload['id']?.toString();
    if (singleId != null && singleId.isNotEmpty) {
      ids.add(singleId);
    }
    return current.copyWith(
      feed: current.feed.copyWith(
        items: current.feed.items.where((i) => !ids.contains(i.id)).toList(),
      ),
    );
  }
  // Partial feed property patch (heightToken etc.)
  final feedPatch = Map<String, dynamic>.from(payload)
    ..remove('op')
    ..remove('operation');
  if (feedPatch.isNotEmpty) {
    final mergedFeed = deepMergeMaps(current.feed.toJson(), feedPatch);
    // Preserve full item objects when patch only touches tokens.
    final next = HomeFeedSurface.fromJson(mergedFeed);
    return current.copyWith(
      feed: next.copyWith(
        items: next.items.isNotEmpty ? next.items : current.feed.items,
      ),
    );
  }
  return current;
}

Map<String, dynamic> deepMergeMaps(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  final result = Map<String, dynamic>.from(base);
  patch.forEach((key, value) {
    if (value == null) return;
    final existing = result[key];
    if (value is Map && existing is Map) {
      result[key] = deepMergeMaps(
        Map<String, dynamic>.from(existing),
        Map<String, dynamic>.from(value),
      );
    } else if (value is Map) {
      result[key] = Map<String, dynamic>.from(value);
    } else if (value is List) {
      result[key] = List<dynamic>.from(value);
    } else {
      result[key] = value;
    }
  });
  return result;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
