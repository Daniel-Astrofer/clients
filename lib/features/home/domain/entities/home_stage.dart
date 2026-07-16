import 'package:flutter/material.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart'
    show
        HomeGreetingAnimation,
        HomeGreetingConfig,
        HomeGreetingMode,
        clampHomeSpacing;

// ── Communication Stage (schema v2) ─────────────────────────────────────────

enum HomeStageKind {
  market,
  news,
  feature,
  announcement,
  promo,
  idle,
  unknown,
}

enum HomeStagePlayPolicy { once, loop, pinned, unknown }

enum HomeStageTextMode { marquee, staticText, fadeLines, typewriter, unknown }

enum HomeStageMediaType { none, icon, image, lottie, video, unknown }

enum HomeStagePreset {
  compactLine,
  bannerText,
  mediaLeft,
  mediaTop,
  videoFocus,
  unknown,
}

enum HomeStageActionsPlacement {
  trailing,
  belowStage,
  overlayEnd,
  hidden,
  unknown,
}

enum HomeStageActionsPolicy {
  alwaysVisible,
  hideForVideo,
  forceHidden,
  unknown,
}

enum HomeStageMotionType {
  none,
  fade,
  fadeSlideDown,
  fadeSlideUp,
  scaleFade,
  marquee,
  unknown,
}

enum HomeStageCurveToken {
  linear,
  easeOutCubic,
  easeInOut,
  easeIn,
  springSoft,
  unknown,
}

HomeStageKind parseStageKind(String? raw) => switch ((raw ?? '').toUpperCase()) {
      'MARKET' => HomeStageKind.market,
      'NEWS' => HomeStageKind.news,
      'FEATURE' => HomeStageKind.feature,
      'ANNOUNCEMENT' => HomeStageKind.announcement,
      'PROMO' => HomeStageKind.promo,
      'IDLE' => HomeStageKind.idle,
      _ => HomeStageKind.unknown,
    };

HomeStagePlayPolicy parseStagePlayPolicy(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'ONCE' => HomeStagePlayPolicy.once,
      'LOOP' => HomeStagePlayPolicy.loop,
      'PINNED' => HomeStagePlayPolicy.pinned,
      _ => HomeStagePlayPolicy.unknown,
    };

HomeStageTextMode parseStageTextMode(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'MARQUEE' => HomeStageTextMode.marquee,
      'STATIC' => HomeStageTextMode.staticText,
      'FADE_LINES' => HomeStageTextMode.fadeLines,
      'TYPEWRITER' || 'TYPE' || 'WRITE' => HomeStageTextMode.typewriter,
      _ => HomeStageTextMode.unknown,
    };

HomeStageMediaType parseStageMediaType(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'NONE' => HomeStageMediaType.none,
      'ICON' => HomeStageMediaType.icon,
      'IMAGE' => HomeStageMediaType.image,
      'LOTTIE' => HomeStageMediaType.lottie,
      'VIDEO' => HomeStageMediaType.video,
      _ => HomeStageMediaType.unknown,
    };

HomeStagePreset parseStagePreset(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'COMPACT_LINE' => HomeStagePreset.compactLine,
      'BANNER_TEXT' => HomeStagePreset.bannerText,
      'MEDIA_LEFT' => HomeStagePreset.mediaLeft,
      'MEDIA_TOP' => HomeStagePreset.mediaTop,
      'VIDEO_FOCUS' => HomeStagePreset.videoFocus,
      _ => HomeStagePreset.unknown,
    };

HomeStageActionsPlacement parseActionsPlacement(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'TRAILING' => HomeStageActionsPlacement.trailing,
      'BELOW_STAGE' => HomeStageActionsPlacement.belowStage,
      'OVERLAY_END' => HomeStageActionsPlacement.overlayEnd,
      'HIDDEN' => HomeStageActionsPlacement.hidden,
      _ => HomeStageActionsPlacement.unknown,
    };

HomeStageActionsPolicy parseActionsPolicy(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'ALWAYS_VISIBLE' => HomeStageActionsPolicy.alwaysVisible,
      'HIDE_FOR_VIDEO' => HomeStageActionsPolicy.hideForVideo,
      'FORCE_HIDDEN' => HomeStageActionsPolicy.forceHidden,
      _ => HomeStageActionsPolicy.unknown,
    };

HomeStageMotionType parseStageMotionType(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'NONE' => HomeStageMotionType.none,
      'FADE' => HomeStageMotionType.fade,
      'FADE_SLIDE_DOWN' => HomeStageMotionType.fadeSlideDown,
      'FADE_SLIDE_UP' => HomeStageMotionType.fadeSlideUp,
      'SCALE_FADE' => HomeStageMotionType.scaleFade,
      'MARQUEE' => HomeStageMotionType.marquee,
      _ => HomeStageMotionType.unknown,
    };

HomeStageCurveToken parseStageCurve(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'LINEAR' => HomeStageCurveToken.linear,
      'EASE_OUT_CUBIC' => HomeStageCurveToken.easeOutCubic,
      'EASE_IN_OUT' => HomeStageCurveToken.easeInOut,
      'EASE_IN' => HomeStageCurveToken.easeIn,
      'SPRING_SOFT' => HomeStageCurveToken.springSoft,
      _ => HomeStageCurveToken.unknown,
    };

int clampMotionMs(num? raw, {int fallback = 400, int min = 120, int max = 2000}) {
  if (raw == null) return fallback;
  return raw.toInt().clamp(min, max);
}

Curve resolveStageCurve(HomeStageCurveToken token) => switch (token) {
      HomeStageCurveToken.linear => Curves.linear,
      HomeStageCurveToken.easeOutCubic => Curves.easeOutCubic,
      HomeStageCurveToken.easeInOut => Curves.easeInOut,
      HomeStageCurveToken.easeIn => Curves.easeIn,
      HomeStageCurveToken.springSoft => Curves.easeOutBack,
      HomeStageCurveToken.unknown => Curves.easeOutCubic,
    };

class HomeStageCta {
  final String label;
  final String action;
  final String target;

  const HomeStageCta({
    this.label = '',
    this.action = 'NONE',
    this.target = '',
  });

  factory HomeStageCta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageCta();
    return HomeStageCta(
      label: (json['label'] ?? '').toString(),
      action: (json['action'] ?? 'NONE').toString(),
      target: (json['target'] ?? '').toString(),
    );
  }

  bool get isNavigate =>
      action.toUpperCase() == 'NAVIGATE' && target.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'label': label,
        'action': action,
        'target': target,
      };
}

// ── Rich theater text (H1/H2/body/bullets + spans) ─────────────────────────

enum TheaterBlockRole { h1, h2, body, caption, bullet, spacer, unknown }

enum TheaterTextWeight { regular, medium, bold, unknown }

enum TheaterTextTone { positive, danger, amber, muted, cold, brand, unknown }

TheaterBlockRole parseTheaterBlockRole(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'H1' || 'TITLE' => TheaterBlockRole.h1,
      'H2' || 'SUBTITLE' || 'HEADING' => TheaterBlockRole.h2,
      'BODY' || 'P' || 'PARAGRAPH' => TheaterBlockRole.body,
      'CAPTION' || 'FOOTNOTE' || 'HINT' => TheaterBlockRole.caption,
      'BULLET' || 'LI' || 'ITEM' => TheaterBlockRole.bullet,
      'SPACER' || 'GAP' => TheaterBlockRole.spacer,
      _ => TheaterBlockRole.unknown,
    };

TheaterTextWeight parseTheaterTextWeight(String? raw) =>
    switch ((raw ?? '').toUpperCase()) {
      'REGULAR' || 'NORMAL' || 'W400' => TheaterTextWeight.regular,
      'MEDIUM' || 'W500' || 'W600' => TheaterTextWeight.medium,
      'BOLD' || 'W700' || 'STRONG' => TheaterTextWeight.bold,
      _ => TheaterTextWeight.unknown,
    };

TheaterTextTone parseTheaterTextTone(String? raw) =>
    switch ((raw ?? '').toLowerCase()) {
      'positive' || 'green' || 'up' => TheaterTextTone.positive,
      'danger' || 'red' || 'down' => TheaterTextTone.danger,
      'amber' || 'bitcoin' || 'orange' => TheaterTextTone.amber,
      'muted' => TheaterTextTone.muted,
      'cold' || 'blue' => TheaterTextTone.cold,
      'brand' || 'warm' => TheaterTextTone.brand,
      _ => TheaterTextTone.unknown,
    };

@immutable
class TheaterTextSpanMark {
  final int start;
  final int end;
  final TheaterTextWeight weight;
  final TheaterTextTone tone;

  const TheaterTextSpanMark({
    required this.start,
    required this.end,
    this.weight = TheaterTextWeight.bold,
    this.tone = TheaterTextTone.unknown,
  });

  factory TheaterTextSpanMark.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TheaterTextSpanMark(start: 0, end: 0);
    }
    final start = json['start'] is num
        ? (json['start'] as num).toInt()
        : int.tryParse('${json['start']}') ?? 0;
    final end = json['end'] is num
        ? (json['end'] as num).toInt()
        : int.tryParse('${json['end']}') ?? 0;
    return TheaterTextSpanMark(
      start: start.clamp(0, 1 << 20),
      end: end.clamp(0, 1 << 20),
      weight: parseTheaterTextWeight(json['weight']?.toString()),
      tone: parseTheaterTextTone(json['tone']?.toString()),
    );
  }

  bool get isValid => end > start && start >= 0;

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'weight': switch (weight) {
          TheaterTextWeight.regular => 'REGULAR',
          TheaterTextWeight.medium => 'MEDIUM',
          TheaterTextWeight.bold => 'BOLD',
          TheaterTextWeight.unknown => 'BOLD',
        },
        if (tone != TheaterTextTone.unknown)
          'tone': switch (tone) {
            TheaterTextTone.positive => 'positive',
            TheaterTextTone.danger => 'danger',
            TheaterTextTone.amber => 'amber',
            TheaterTextTone.muted => 'muted',
            TheaterTextTone.cold => 'cold',
            TheaterTextTone.brand => 'brand',
            TheaterTextTone.unknown => 'muted',
          },
      };
}

@immutable
class TheaterTextBlock {
  final TheaterBlockRole role;
  final String text;
  final String? emoji;
  final List<TheaterTextSpanMark> spans;

  const TheaterTextBlock({
    this.role = TheaterBlockRole.body,
    this.text = '',
    this.emoji,
    this.spans = const [],
  });

  factory TheaterTextBlock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TheaterTextBlock();
    final rawSpans = json['spans'];
    final spans = rawSpans is List
        ? rawSpans
            .whereType<Map>()
            .map((e) => TheaterTextSpanMark.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.isValid)
            .toList(growable: false)
        : const <TheaterTextSpanMark>[];
    return TheaterTextBlock(
      role: parseTheaterBlockRole(json['role']?.toString()),
      text: (json['text'] ?? '').toString(),
      emoji: () {
        final e = (json['emoji'] ?? '').toString().trim();
        return e.isEmpty ? null : e;
      }(),
      spans: spans,
    );
  }

  bool get isSpacer => role == TheaterBlockRole.spacer;

  bool get hasVisibleText =>
      role != TheaterBlockRole.spacer && text.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'role': switch (role) {
          TheaterBlockRole.h1 => 'H1',
          TheaterBlockRole.h2 => 'H2',
          TheaterBlockRole.body => 'BODY',
          TheaterBlockRole.caption => 'CAPTION',
          TheaterBlockRole.bullet => 'BULLET',
          TheaterBlockRole.spacer => 'SPACER',
          TheaterBlockRole.unknown => 'BODY',
        },
        'text': text,
        if (emoji != null) 'emoji': emoji,
        if (spans.isNotEmpty)
          'spans': spans.map((s) => s.toJson()).toList(growable: false),
      };
}

class HomeStageContent {
  final String title;
  final String? body;
  final HomeStageTextMode textMode;
  final bool includeNamePlaceholder;
  final HomeStageCta? cta;
  /// Structured hierarchy (H2/body/bullets). When non-empty, wins over plain body.
  final List<TheaterTextBlock> blocks;

  const HomeStageContent({
    this.title = '',
    this.body,
    this.textMode = HomeStageTextMode.staticText,
    this.includeNamePlaceholder = false,
    this.cta,
    this.blocks = const [],
  });

  bool get hasRichBlocks => blocks.any((b) => b.hasVisibleText || b.isSpacer);

  factory HomeStageContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageContent();
    final placeholders = json['placeholders'];
    var includeName = false;
    if (placeholders is Map) {
      final n = placeholders['name'];
      includeName = n is bool ? n : n?.toString() == 'true';
    }
    final ctaRaw = json['cta'];
    final rawBlocks = json['blocks'];
    final blocks = rawBlocks is List
        ? rawBlocks
            .whereType<Map>()
            .map((e) => TheaterTextBlock.fromJson(Map<String, dynamic>.from(e)))
            .where((b) => b.role != TheaterBlockRole.unknown || b.hasVisibleText)
            .toList(growable: false)
        : const <TheaterTextBlock>[];
    return HomeStageContent(
      title: (json['title'] ?? '').toString(),
      body: json['body']?.toString(),
      textMode: parseStageTextMode(json['textMode']?.toString()),
      includeNamePlaceholder: includeName,
      cta: ctaRaw is Map
          ? HomeStageCta.fromJson(Map<String, dynamic>.from(ctaRaw))
          : null,
      blocks: blocks,
    );
  }

  String resolveTitle(String userName) {
    if (!includeNamePlaceholder) return title;
    return title.replaceAll('{name}', userName);
  }

  /// Plain fallback used by typewriter / a11y when blocks are present.
  String plainBodyFallback() {
    if (!hasRichBlocks) return (body ?? '').trim();
    final parts = <String>[];
    for (final b in blocks) {
      if (!b.hasVisibleText) continue;
      final lead = (b.emoji ?? '').trim();
      parts.add(lead.isEmpty ? b.text.trim() : '$lead ${b.text.trim()}');
    }
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (body != null) 'body': body,
        'textMode': switch (textMode) {
          HomeStageTextMode.marquee => 'MARQUEE',
          HomeStageTextMode.staticText => 'STATIC',
          HomeStageTextMode.fadeLines => 'FADE_LINES',
          HomeStageTextMode.typewriter => 'TYPEWRITER',
          HomeStageTextMode.unknown => 'STATIC',
        },
        'placeholders': {'name': includeNamePlaceholder},
        if (cta != null) 'cta': cta!.toJson(),
        if (blocks.isNotEmpty)
          'blocks': blocks.map((b) => b.toJson()).toList(growable: false),
      };
}

class HomeStageMedia {
  final HomeStageMediaType type;
  final String? iconKey;
  final String? url;
  final String? posterUrl;
  final double aspectRatio;
  final bool autoplay;
  final bool muted;
  final bool loop;

  const HomeStageMedia({
    this.type = HomeStageMediaType.none,
    this.iconKey,
    this.url,
    this.posterUrl,
    this.aspectRatio = 16 / 9,
    this.autoplay = true,
    this.muted = true,
    this.loop = false,
  });

  factory HomeStageMedia.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageMedia();
    final ar = json['aspectRatio'];
    return HomeStageMedia(
      type: parseStageMediaType(json['type']?.toString()),
      iconKey: json['iconKey']?.toString(),
      url: json['url']?.toString(),
      posterUrl: json['posterUrl']?.toString(),
      aspectRatio: ar is num
          ? ar.toDouble()
          : double.tryParse(ar?.toString() ?? '') ?? 16 / 9,
      autoplay: json['autoplay'] is bool
          ? json['autoplay'] as bool
          : json['autoplay']?.toString() != 'false',
      muted: json['muted'] is bool
          ? json['muted'] as bool
          : json['muted']?.toString() != 'false',
      loop: json['loop'] is bool
          ? json['loop'] as bool
          : json['loop']?.toString() == 'true',
    );
  }

  IconData resolveIcon() {
    return switch ((iconKey ?? '').trim()) {
      'bitcoin' => KeroseneIcons.bitcoin,
      'lightning' => KeroseneIcons.lightning,
      'info' => KeroseneIcons.info,
      'wallet' => KeroseneIcons.wallet,
      'play' => KeroseneIcons.next,
      _ => KeroseneIcons.info,
    };
  }

  bool get hasVisual =>
      type != HomeStageMediaType.none && type != HomeStageMediaType.unknown;

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          HomeStageMediaType.none => 'NONE',
          HomeStageMediaType.icon => 'ICON',
          HomeStageMediaType.image => 'IMAGE',
          HomeStageMediaType.lottie => 'LOTTIE',
          HomeStageMediaType.video => 'VIDEO',
          HomeStageMediaType.unknown => 'NONE',
        },
        if (iconKey != null) 'iconKey': iconKey,
        if (url != null) 'url': url,
        if (posterUrl != null) 'posterUrl': posterUrl,
        'aspectRatio': aspectRatio,
        'autoplay': autoplay,
        'muted': muted,
        'loop': loop,
      };
}

class HomeStageActionsLayout {
  final HomeStageActionsPlacement placement;
  final HomeStageActionsPolicy policy;

  const HomeStageActionsLayout({
    this.placement = HomeStageActionsPlacement.belowStage,
    this.policy = HomeStageActionsPolicy.alwaysVisible,
  });

  factory HomeStageActionsLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageActionsLayout();
    return HomeStageActionsLayout(
      placement: parseActionsPlacement(json['placement']?.toString()),
      policy: parseActionsPolicy(json['policy']?.toString()),
    );
  }

  /// Effective placement for current media (video policy).
  HomeStageActionsPlacement resolvePlacement(HomeStageMedia media) {
    if (policy == HomeStageActionsPolicy.forceHidden) {
      return HomeStageActionsPlacement.hidden;
    }
    if (policy == HomeStageActionsPolicy.hideForVideo &&
        media.type == HomeStageMediaType.video) {
      return HomeStageActionsPlacement.hidden;
    }
    if (placement == HomeStageActionsPlacement.unknown) {
      return HomeStageActionsPlacement.belowStage;
    }
    return placement;
  }

  Map<String, dynamic> toJson() => {
        'placement': switch (placement) {
          HomeStageActionsPlacement.trailing => 'TRAILING',
          HomeStageActionsPlacement.belowStage => 'BELOW_STAGE',
          HomeStageActionsPlacement.overlayEnd => 'OVERLAY_END',
          HomeStageActionsPlacement.hidden => 'HIDDEN',
          HomeStageActionsPlacement.unknown => 'BELOW_STAGE',
        },
        'policy': switch (policy) {
          HomeStageActionsPolicy.alwaysVisible => 'ALWAYS_VISIBLE',
          HomeStageActionsPolicy.hideForVideo => 'HIDE_FOR_VIDEO',
          HomeStageActionsPolicy.forceHidden => 'FORCE_HIDDEN',
          HomeStageActionsPolicy.unknown => 'ALWAYS_VISIBLE',
        },
      };
}

/// One radial ambient glow in the home theater atmosphere (server-driven).
///
/// Coordinates [x]/[y] are normalized 0–1 relative to the atmosphere layer
/// (top of home). [width]/[height] are factors of screen width/height.
class HomeStageGlow {
  final String id;
  final String colorToken;
  final double x;
  final double y;
  final double width;
  final double height;
  final double intensity;
  final double radius;
  final int zIndex;

  const HomeStageGlow({
    this.id = '',
    this.colorToken = 'white',
    this.x = 0.5,
    this.y = 0.0,
    this.width = 1.4,
    this.height = 0.55,
    this.intensity = 0.45,
    this.radius = 0.72,
    this.zIndex = 0,
  });

  factory HomeStageGlow.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageGlow();
    double n(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return HomeStageGlow(
      id: (json['id'] ?? '').toString(),
      colorToken: (json['colorToken'] ?? json['color'] ?? 'white').toString(),
      x: n(json['x'], 0.5).clamp(0.0, 1.0),
      y: n(json['y'], 0.0).clamp(0.0, 1.0),
      width: n(json['width'], 1.4).clamp(0.2, 4.0),
      height: n(json['height'], 0.55).clamp(0.1, 2.5),
      intensity: n(json['intensity'], 0.45).clamp(0.0, 1.0),
      radius: n(json['radius'], 0.72).clamp(0.2, 1.5),
      zIndex: json['zIndex'] is num
          ? (json['zIndex'] as num).toInt()
          : int.tryParse('${json['zIndex']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'colorToken': colorToken,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'intensity': intensity,
        'radius': radius,
        'zIndex': zIndex,
      };
}

/// Atmosphere layer for the theater: N independent glows from the backend.
class HomeStageAtmosphere {
  final List<HomeStageGlow> glows;
  final bool animated;
  final int transitionMs;

  const HomeStageAtmosphere({
    this.glows = const [],
    this.animated = true,
    this.transitionMs = 480,
  });

  factory HomeStageAtmosphere.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageAtmosphere();
    final raw = json['glows'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => HomeStageGlow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <HomeStageGlow>[];
    list.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final anim = json['animated'];
    return HomeStageAtmosphere(
      glows: List.unmodifiable(list),
      animated: anim is bool ? anim : anim?.toString() != 'false',
      transitionMs: clampMotionMs(
        json['transitionMs'],
        fallback: 480,
        min: 120,
        max: 2000,
      ),
    );
  }

  bool get hasGlows => glows.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'glows': glows.map((g) => g.toJson()).toList(growable: false),
        'animated': animated,
        'transitionMs': transitionMs,
      };
}

class HomeStageLayout {
  final HomeStagePreset preset;
  final String backgroundToken;
  final double paddingTop;
  final double paddingBottom;
  final double paddingHorizontal;
  final double gap;
  final double minHeight;
  final double maxHeight;
  final HomeStageActionsLayout actions;
  final HomeStageAtmosphere atmosphere;

  const HomeStageLayout({
    this.preset = HomeStagePreset.bannerText,
    this.backgroundToken = 'transparent',
    this.paddingTop = 0,
    this.paddingBottom = 8,
    this.paddingHorizontal = 0,
    this.gap = 8,
    this.minHeight = 0,
    this.maxHeight = 180,
    this.actions = const HomeStageActionsLayout(),
    this.atmosphere = const HomeStageAtmosphere(),
  });

  factory HomeStageLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageLayout();
    final pad = json['padding'];
    Map<String, dynamic>? padMap;
    if (pad is Map) padMap = Map<String, dynamic>.from(pad);
    // atmosphere may live under layout or as sibling — layout first.
    final atmoRaw = json['atmosphere'];
    return HomeStageLayout(
      preset: parseStagePreset(json['preset']?.toString()),
      backgroundToken: (json['backgroundToken'] ?? 'transparent').toString(),
      paddingTop: clampHomeSpacing(
        padMap?['top'] is num ? padMap!['top'] as num : null,
        fallback: 0,
      ),
      paddingBottom: clampHomeSpacing(
        padMap?['bottom'] is num ? padMap!['bottom'] as num : num.tryParse('${json['paddingBottom']}'),
        fallback: 8,
      ),
      paddingHorizontal: clampHomeSpacing(
        padMap?['horizontal'] is num ? padMap!['horizontal'] as num : null,
        fallback: 0,
      ),
      gap: clampHomeSpacing(
        json['gap'] is num ? json['gap'] as num : num.tryParse('${json['gap']}'),
        fallback: 8,
      ),
      minHeight: (json['minHeight'] is num
              ? (json['minHeight'] as num).toDouble()
              : double.tryParse('${json['minHeight']}'))
          ?.clamp(0, 320) ??
          0,
      maxHeight: (json['maxHeight'] is num
              ? (json['maxHeight'] as num).toDouble()
              : double.tryParse('${json['maxHeight']}'))
          ?.clamp(48, 320) ??
          180,
      actions: HomeStageActionsLayout.fromJson(
        json['actions'] is Map
            ? Map<String, dynamic>.from(json['actions'] as Map)
            : null,
      ),
      atmosphere: HomeStageAtmosphere.fromJson(
        atmoRaw is Map ? Map<String, dynamic>.from(atmoRaw) : null,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': switch (preset) {
          HomeStagePreset.compactLine => 'COMPACT_LINE',
          HomeStagePreset.bannerText => 'BANNER_TEXT',
          HomeStagePreset.mediaLeft => 'MEDIA_LEFT',
          HomeStagePreset.mediaTop => 'MEDIA_TOP',
          HomeStagePreset.videoFocus => 'VIDEO_FOCUS',
          HomeStagePreset.unknown => 'BANNER_TEXT',
        },
        'backgroundToken': backgroundToken,
        'padding': {
          'top': paddingTop,
          'bottom': paddingBottom,
          'horizontal': paddingHorizontal,
        },
        'gap': gap,
        'minHeight': minHeight,
        'maxHeight': maxHeight,
        'actions': actions.toJson(),
        'atmosphere': atmosphere.toJson(),
      };
}

class HomeStageMotionStep {
  final HomeStageMotionType type;
  final int durationMs;
  final HomeStageCurveToken curve;
  final int delayMs;

  const HomeStageMotionStep({
    this.type = HomeStageMotionType.fade,
    this.durationMs = 400,
    this.curve = HomeStageCurveToken.easeOutCubic,
    this.delayMs = 0,
  });

  factory HomeStageMotionStep.fromJson(
    Map<String, dynamic>? json, {
    HomeStageMotionType defaultType = HomeStageMotionType.fade,
    int defaultMs = 400,
  }) {
    if (json == null) {
      return HomeStageMotionStep(type: defaultType, durationMs: defaultMs);
    }
    final type = parseStageMotionType(json['type']?.toString());
    return HomeStageMotionStep(
      type: type == HomeStageMotionType.unknown ? defaultType : type,
      durationMs: clampMotionMs(json['durationMs'], fallback: defaultMs),
      curve: parseStageCurve(json['curve']?.toString()),
      delayMs: clampMotionMs(json['delayMs'], fallback: 0, min: 0, max: 3000),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          HomeStageMotionType.none => 'NONE',
          HomeStageMotionType.fade => 'FADE',
          HomeStageMotionType.fadeSlideDown => 'FADE_SLIDE_DOWN',
          HomeStageMotionType.fadeSlideUp => 'FADE_SLIDE_UP',
          HomeStageMotionType.scaleFade => 'SCALE_FADE',
          HomeStageMotionType.marquee => 'MARQUEE',
          HomeStageMotionType.unknown => 'FADE',
        },
        'durationMs': durationMs,
        'curve': switch (curve) {
          HomeStageCurveToken.linear => 'LINEAR',
          HomeStageCurveToken.easeOutCubic => 'EASE_OUT_CUBIC',
          HomeStageCurveToken.easeInOut => 'EASE_IN_OUT',
          HomeStageCurveToken.easeIn => 'EASE_IN',
          HomeStageCurveToken.springSoft => 'SPRING_SOFT',
          HomeStageCurveToken.unknown => 'EASE_OUT_CUBIC',
        },
        'delayMs': delayMs,
      };
}

class HomeStageBodyShift {
  final bool enabled;
  final double offsetPx;
  final int durationMs;
  final HomeStageCurveToken curve;
  final bool fadeBody;

  const HomeStageBodyShift({
    this.enabled = true,
    this.offsetPx = 36,
    this.durationMs = 480,
    this.curve = HomeStageCurveToken.easeOutCubic,
    this.fadeBody = false,
  });

  factory HomeStageBodyShift.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageBodyShift();
    final en = json['enabled'];
    final off = json['offsetPx'];
    return HomeStageBodyShift(
      enabled: en is bool ? en : en?.toString() != 'false',
      offsetPx: clampHomeSpacing(
        off is num ? off : num.tryParse('$off'),
        fallback: 36,
      ),
      durationMs: clampMotionMs(json['durationMs'], fallback: 480, min: 200, max: 2000),
      curve: parseStageCurve(json['curve']?.toString()),
      fadeBody: json['fadeBody'] is bool
          ? json['fadeBody'] as bool
          : json['fadeBody']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'offsetPx': offsetPx,
        'durationMs': durationMs,
        'curve': switch (curve) {
          HomeStageCurveToken.linear => 'LINEAR',
          HomeStageCurveToken.easeOutCubic => 'EASE_OUT_CUBIC',
          HomeStageCurveToken.easeInOut => 'EASE_IN_OUT',
          HomeStageCurveToken.easeIn => 'EASE_IN',
          HomeStageCurveToken.springSoft => 'SPRING_SOFT',
          HomeStageCurveToken.unknown => 'EASE_OUT_CUBIC',
        },
        'fadeBody': fadeBody,
      };
}

class HomeStageMotion {
  final HomeStageMotionStep enter;
  final HomeStageMotionStep exit;
  final HomeStageMotionStep content;
  final HomeStageBodyShift bodyShift;

  const HomeStageMotion({
    this.enter = const HomeStageMotionStep(
      type: HomeStageMotionType.fadeSlideDown,
      durationMs: 420,
    ),
    this.exit = const HomeStageMotionStep(
      type: HomeStageMotionType.fade,
      durationMs: 280,
      curve: HomeStageCurveToken.easeIn,
    ),
    this.content = const HomeStageMotionStep(
      type: HomeStageMotionType.marquee,
      durationMs: 9000,
      curve: HomeStageCurveToken.linear,
    ),
    this.bodyShift = const HomeStageBodyShift(),
  });

  factory HomeStageMotion.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageMotion();
    return HomeStageMotion(
      enter: HomeStageMotionStep.fromJson(
        json['enter'] is Map
            ? Map<String, dynamic>.from(json['enter'] as Map)
            : null,
        defaultType: HomeStageMotionType.fadeSlideDown,
        defaultMs: 420,
      ),
      exit: HomeStageMotionStep.fromJson(
        json['exit'] is Map
            ? Map<String, dynamic>.from(json['exit'] as Map)
            : null,
        defaultType: HomeStageMotionType.fade,
        defaultMs: 280,
      ),
      content: HomeStageMotionStep.fromJson(
        json['content'] is Map
            ? Map<String, dynamic>.from(json['content'] as Map)
            : null,
        defaultType: HomeStageMotionType.marquee,
        defaultMs: 9000,
      ),
      bodyShift: HomeStageBodyShift.fromJson(
        json['bodyShift'] is Map
            ? Map<String, dynamic>.from(json['bodyShift'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'enter': enter.toJson(),
        'exit': exit.toJson(),
        'content': content.toJson(),
        'bodyShift': bodyShift.toJson(),
      };
}

class HomeStageLifecycle {
  final int showDurationMs;
  final bool restoreOnComplete;
  final bool dismissible;

  const HomeStageLifecycle({
    this.showDurationMs = 9000,
    this.restoreOnComplete = true,
    this.dismissible = false,
  });

  factory HomeStageLifecycle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeStageLifecycle();
    return HomeStageLifecycle(
      showDurationMs:
          clampMotionMs(json['showDurationMs'], fallback: 9000, min: 1500, max: 60000),
      restoreOnComplete: json['restoreOnComplete'] is bool
          ? json['restoreOnComplete'] as bool
          : json['restoreOnComplete']?.toString() != 'false',
      dismissible: json['dismissible'] is bool
          ? json['dismissible'] as bool
          : json['dismissible']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'showDurationMs': showDurationMs,
        'restoreOnComplete': restoreOnComplete,
        'dismissible': dismissible,
      };
}

/// One communication piece for the upper home theater.
class HomeStage {
  final String id;
  final HomeStageKind kind;
  final HomeStagePlayPolicy playPolicy;
  final int priority;
  final HomeStageContent content;
  final HomeStageMedia media;
  final HomeStageLayout layout;
  final HomeStageMotion motion;
  final HomeStageLifecycle lifecycle;
  /// Top-level atmosphere (preferred). Falls back to [layout.atmosphere].
  final HomeStageAtmosphere atmosphere;

  const HomeStage({
    this.id = '',
    this.kind = HomeStageKind.idle,
    this.playPolicy = HomeStagePlayPolicy.once,
    this.priority = 0,
    this.content = const HomeStageContent(),
    this.media = const HomeStageMedia(),
    this.layout = const HomeStageLayout(),
    this.motion = const HomeStageMotion(),
    this.lifecycle = const HomeStageLifecycle(),
    this.atmosphere = const HomeStageAtmosphere(),
  });

  bool get isActive =>
      kind != HomeStageKind.idle &&
      kind != HomeStageKind.unknown &&
      (content.title.trim().isNotEmpty || media.hasVisual);

  /// Effective glows: top-level atmosphere wins, else layout.atmosphere.
  HomeStageAtmosphere get resolvedAtmosphere =>
      atmosphere.hasGlows ? atmosphere : layout.atmosphere;

  factory HomeStage.idle() => const HomeStage(kind: HomeStageKind.idle);

  factory HomeStage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HomeStage.idle();
    final priorityRaw = json['priority'];
    final play = parseStagePlayPolicy(json['playPolicy']?.toString());
    final layout = HomeStageLayout.fromJson(
      json['layout'] is Map
          ? Map<String, dynamic>.from(json['layout'] as Map)
          : null,
    );
    // Top-level atmosphere OR nested under layout.
    final atmoTop = HomeStageAtmosphere.fromJson(
      json['atmosphere'] is Map
          ? Map<String, dynamic>.from(json['atmosphere'] as Map)
          : null,
    );
    return HomeStage(
      id: (json['id'] ?? '').toString(),
      kind: parseStageKind(json['kind']?.toString()),
      playPolicy:
          play == HomeStagePlayPolicy.unknown ? HomeStagePlayPolicy.once : play,
      priority: priorityRaw is num
          ? priorityRaw.toInt()
          : int.tryParse(priorityRaw?.toString() ?? '') ?? 0,
      content: HomeStageContent.fromJson(
        json['content'] is Map
            ? Map<String, dynamic>.from(json['content'] as Map)
            : null,
      ),
      media: HomeStageMedia.fromJson(
        json['media'] is Map
            ? Map<String, dynamic>.from(json['media'] as Map)
            : null,
      ),
      layout: layout,
      motion: HomeStageMotion.fromJson(
        json['motion'] is Map
            ? Map<String, dynamic>.from(json['motion'] as Map)
            : null,
      ),
      lifecycle: HomeStageLifecycle.fromJson(
        json['lifecycle'] is Map
            ? Map<String, dynamic>.from(json['lifecycle'] as Map)
            : null,
      ),
      atmosphere: atmoTop.hasGlows ? atmoTop : layout.atmosphere,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': switch (kind) {
          HomeStageKind.market => 'MARKET',
          HomeStageKind.news => 'NEWS',
          HomeStageKind.feature => 'FEATURE',
          HomeStageKind.announcement => 'ANNOUNCEMENT',
          HomeStageKind.promo => 'PROMO',
          HomeStageKind.idle => 'IDLE',
          HomeStageKind.unknown => 'IDLE',
        },
        'playPolicy': switch (playPolicy) {
          HomeStagePlayPolicy.once => 'ONCE',
          HomeStagePlayPolicy.loop => 'LOOP',
          HomeStagePlayPolicy.pinned => 'PINNED',
          HomeStagePlayPolicy.unknown => 'ONCE',
        },
        'priority': priority,
        'content': content.toJson(),
        'media': media.toJson(),
        'layout': layout.toJson(),
        'motion': motion.toJson(),
        'lifecycle': lifecycle.toJson(),
        'atmosphere': resolvedAtmosphere.toJson(),
      };

  /// Map legacy v1 greeting ephemeral → stage piece.
  factory HomeStage.fromLegacyGreeting(HomeGreetingConfig greeting) {
    final msgs = greeting.activeMessages;
    if (msgs.isEmpty &&
        greeting.mode != HomeGreetingMode.ephemeral &&
        greeting.mode != HomeGreetingMode.ticker) {
      return HomeStage.idle();
    }
    if (msgs.isEmpty) return HomeStage.idle();

    final first = msgs.first;
    final title = first.text;
    final duration = first.durationMs > 0
        ? first.durationMs
        : greeting.rotation.intervalMs;
    final once = greeting.isEphemeralOnce;
    final push = greeting.presentation.pushDownBalanceWhilePlaying
        ? greeting.presentation.pushDownBalancePx
        : 0.0;

    return HomeStage(
      id: first.id.isNotEmpty ? first.id : 'legacy-greeting',
      kind: HomeStageKind.market,
      playPolicy: once ? HomeStagePlayPolicy.once : HomeStagePlayPolicy.loop,
      priority: first.priority,
      content: HomeStageContent(
        title: title,
        textMode: first.animation == HomeGreetingAnimation.marquee ||
                title.runes.length >= 28
            ? HomeStageTextMode.marquee
            : HomeStageTextMode.staticText,
        includeNamePlaceholder: title.contains('{name}'),
      ),
      media: const HomeStageMedia(),
      layout: HomeStageLayout(
        preset: title.runes.length >= 28
            ? HomeStagePreset.bannerText
            : HomeStagePreset.compactLine,
        backgroundToken: 'transparent',
        // Product decision: BELOW_STAGE for text theater (not hide).
        actions: const HomeStageActionsLayout(
          placement: HomeStageActionsPlacement.belowStage,
          policy: HomeStageActionsPolicy.alwaysVisible,
        ),
        atmosphere: HomeStageAtmosphere(
          glows: [
            HomeStageGlow(
              id: 'legacy-main',
              colorToken: first.style.colorToken == 'danger'
                  ? 'danger'
                  : first.style.colorToken == 'positive'
                      ? 'positive'
                      : 'amber',
              x: 0.5,
              y: 0.0,
              width: 1.6,
              height: 0.5,
              intensity: 0.42,
              radius: 0.7,
              zIndex: 0,
            ),
          ],
        ),
      ),
      atmosphere: HomeStageAtmosphere(
        glows: [
          HomeStageGlow(
            id: 'legacy-main',
            colorToken: first.style.colorToken == 'danger'
                ? 'danger'
                : first.style.colorToken == 'positive'
                    ? 'positive'
                    : 'amber',
            x: 0.5,
            y: 0.0,
            width: 1.6,
            height: 0.5,
            intensity: 0.42,
            radius: 0.7,
          ),
        ],
      ),
      motion: HomeStageMotion(
        enter: const HomeStageMotionStep(
          type: HomeStageMotionType.fadeSlideDown,
          durationMs: 420,
          curve: HomeStageCurveToken.easeOutCubic,
        ),
        exit: const HomeStageMotionStep(
          type: HomeStageMotionType.fade,
          durationMs: 280,
          curve: HomeStageCurveToken.easeIn,
        ),
        content: HomeStageMotionStep(
          type: HomeStageMotionType.marquee,
          durationMs: duration,
          curve: HomeStageCurveToken.linear,
        ),
        bodyShift: HomeStageBodyShift(
          enabled: push > 0,
          offsetPx: push > 0 ? push : 36,
          durationMs: 480,
          curve: HomeStageCurveToken.easeOutCubic,
          fadeBody: false,
        ),
      ),
      lifecycle: HomeStageLifecycle(
        showDurationMs: duration * (once ? msgs.length : 1),
        restoreOnComplete: greeting.presentation.restoreActionsAfterPlay,
      ),
    );
  }
}

class HomeRestingHeader {
  final String greetingTemplate;
  final bool includeName;
  final HomeStageActionsPlacement actionsPlacement;
  final bool balanceVisibility;
  final bool notifications;
  final bool settings;

  const HomeRestingHeader({
    this.greetingTemplate = 'TIME_OF_DAY',
    this.includeName = true,
    this.actionsPlacement = HomeStageActionsPlacement.trailing,
    this.balanceVisibility = true,
    this.notifications = true,
    this.settings = true,
  });

  factory HomeRestingHeader.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HomeRestingHeader();
    final greeting = json['greeting'];
    Map<String, dynamic>? gMap;
    if (greeting is Map) gMap = Map<String, dynamic>.from(greeting);
    final actions = json['actions'];
    Map<String, dynamic>? aMap;
    if (actions is Map) aMap = Map<String, dynamic>.from(actions);
    return HomeRestingHeader(
      greetingTemplate: (gMap?['template'] ?? 'TIME_OF_DAY').toString(),
      includeName: gMap?['includeName'] is bool
          ? gMap!['includeName'] as bool
          : gMap?['includeName']?.toString() != 'false',
      actionsPlacement: parseActionsPlacement(aMap?['placement']?.toString()),
      balanceVisibility: aMap?['balanceVisibility'] is bool
          ? aMap!['balanceVisibility'] as bool
          : aMap?['balanceVisibility']?.toString() != 'false',
      notifications: aMap?['notifications'] is bool
          ? aMap!['notifications'] as bool
          : aMap?['notifications']?.toString() != 'false',
      settings: aMap?['settings'] is bool
          ? aMap!['settings'] as bool
          : aMap?['settings']?.toString() != 'false',
    );
  }

  Map<String, dynamic> toJson() => {
        'greeting': {
          'template': greetingTemplate,
          'includeName': includeName,
        },
        'actions': {
          'placement': 'TRAILING',
          'balanceVisibility': balanceVisibility,
          'notifications': notifications,
          'settings': settings,
        },
      };
}
