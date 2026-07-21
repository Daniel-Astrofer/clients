import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// ── Scene-Driven UI (not Server-Driven Widgets) ─────────────────────────────
// Backend describes a *scene*: layout, background, media, motion, content, CTA.
// Flutter owns high-quality rendering. No Row/Padding/Container in JSON.

/// High-level layout slot the native renderer chooses how to paint.
enum SceneLayout {
  hero,
  education,
  market,
  immersive,
  card,
  compact,
  fullscreen,
  idle,
}

/// Background strategy — renderer picks implementation (painter / shader).
enum SceneBackgroundType {
  none,
  aurora,
  solid,
  gradient,
}

/// Media kinds the native [MediaLayer] knows how to host.
enum SceneMediaType {
  none,
  icon,
  image,
  svg,
  rive,
  lottie,
  video,
}

/// Named motion presets — backend never sends curves/pixels.
enum SceneMotionPreset {
  none,
  fade,
  slide,
  breathe,
  pulse,
  orbit,
  parallax,
  wave,
  float,
  shimmer,
  expand,
}

/// How text is revealed — independent of layout chrome.
enum SceneTextMode {
  staticText,
  typewriter,
  marquee,
}

SceneLayout parseSceneLayout(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return switch (v) {
    'hero' => SceneLayout.hero,
    'education' || 'learn' => SceneLayout.education,
    'market' => SceneLayout.market,
    'immersive' => SceneLayout.immersive,
    'card' => SceneLayout.card,
    'compact' => SceneLayout.compact,
    'fullscreen' || 'full' => SceneLayout.fullscreen,
    'idle' || '' => SceneLayout.idle,
    _ => SceneLayout.hero,
  };
}

SceneBackgroundType parseSceneBackgroundType(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return switch (v) {
    'aurora' => SceneBackgroundType.aurora,
    'solid' => SceneBackgroundType.solid,
    'gradient' => SceneBackgroundType.gradient,
    'none' || '' => SceneBackgroundType.none,
    _ => SceneBackgroundType.aurora,
  };
}

SceneMediaType parseSceneMediaType(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return switch (v) {
    'icon' => SceneMediaType.icon,
    'image' || 'png' || 'jpg' || 'jpeg' || 'webp' => SceneMediaType.image,
    'svg' => SceneMediaType.svg,
    'rive' || 'riv' => SceneMediaType.rive,
    'lottie' || 'json' => SceneMediaType.lottie,
    'video' || 'mp4' => SceneMediaType.video,
    'none' || '' => SceneMediaType.none,
    _ => SceneMediaType.none,
  };
}

SceneMotionPreset parseSceneMotionPreset(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return switch (v) {
    'fade' => SceneMotionPreset.fade,
    'slide' => SceneMotionPreset.slide,
    'breathe' => SceneMotionPreset.breathe,
    'pulse' => SceneMotionPreset.pulse,
    'orbit' => SceneMotionPreset.orbit,
    'parallax' => SceneMotionPreset.parallax,
    'wave' => SceneMotionPreset.wave,
    'float' => SceneMotionPreset.float,
    'shimmer' => SceneMotionPreset.shimmer,
    'expand' => SceneMotionPreset.expand,
    'none' || '' => SceneMotionPreset.none,
    _ => SceneMotionPreset.breathe,
  };
}

SceneTextMode parseSceneTextMode(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return switch (v) {
    'typewriter' || 'type' || 'write' => SceneTextMode.typewriter,
    'marquee' || 'ticker' => SceneTextMode.marquee,
    'static' || 'fade_lines' || 'fadelines' || '' => SceneTextMode.staticText,
    _ => SceneTextMode.staticText,
  };
}

Color? parseSceneColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
  if (s.length == 8) {
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
  return null;
}

String colorToSceneHex(Color c) {
  final a = (c.a * 255).round().clamp(0, 255);
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  if (a >= 255) {
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
  return '#${a.toRadixString(16).padLeft(2, '0')}'
          '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

@immutable
class SceneBackground {
  final SceneBackgroundType type;
  final Color? primary;
  final Color? secondary;
  final double intensity;

  const SceneBackground({
    this.type = SceneBackgroundType.none,
    this.primary,
    this.secondary,
    this.intensity = 0.32,
  });

  factory SceneBackground.aurora({
    Color? primary,
    Color? secondary,
    double intensity = 0.32,
  }) {
    return SceneBackground(
      type: SceneBackgroundType.aurora,
      primary: primary ?? const Color(0xFF4D7EFF),
      secondary: secondary ?? const Color(0xFF9B7BFF),
      intensity: intensity.clamp(0.0, 1.0),
    );
  }

  factory SceneBackground.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneBackground();
    final intensityRaw = json['intensity'];
    final intensity = intensityRaw is num
        ? intensityRaw.toDouble()
        : double.tryParse('${intensityRaw ?? ''}') ?? 0.32;
    return SceneBackground(
      type: parseSceneBackgroundType(json['type']?.toString()),
      primary: parseSceneColor(json['primary']?.toString()),
      secondary: parseSceneColor(json['secondary']?.toString()),
      intensity: intensity.clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (primary != null) 'primary': colorToSceneHex(primary!),
        if (secondary != null) 'secondary': colorToSceneHex(secondary!),
        'intensity': intensity,
      };

  bool get isActive => type != SceneBackgroundType.none;
}

@immutable
class SceneMedia {
  final SceneMediaType type;

  /// Logical asset key (e.g. `lightning_intro`) — never a full path from BE.
  final String asset;

  /// Optional remote URL when asset is network-hosted.
  final String? url;

  /// Rive state machine input / state name (e.g. `receive_success`).
  final String? state;
  final String? iconKey;
  final double aspectRatio;
  final bool autoplay;
  final bool loop;

  const SceneMedia({
    this.type = SceneMediaType.none,
    this.asset = '',
    this.url,
    this.state,
    this.iconKey,
    this.aspectRatio = 1,
    this.autoplay = true,
    this.loop = true,
  });

  factory SceneMedia.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneMedia();
    final ar = json['aspectRatio'];
    return SceneMedia(
      type: parseSceneMediaType(json['type']?.toString()),
      asset: (json['asset'] ?? json['key'] ?? '').toString().trim(),
      url: () {
        final u = (json['url'] ?? '').toString().trim();
        return u.isEmpty ? null : u;
      }(),
      state: () {
        final s = (json['state'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      iconKey: () {
        final k = (json['iconKey'] ?? json['icon'] ?? '').toString().trim();
        return k.isEmpty ? null : k;
      }(),
      aspectRatio:
          ar is num ? ar.toDouble() : double.tryParse('${ar ?? ''}') ?? 1.0,
      autoplay: json['autoplay'] is bool
          ? json['autoplay'] as bool
          : json['autoplay']?.toString() != 'false',
      loop: json['loop'] is bool
          ? json['loop'] as bool
          : json['loop']?.toString() != 'false',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (asset.isNotEmpty) 'asset': asset,
        if (url != null) 'url': url,
        if (state != null) 'state': state,
        if (iconKey != null) 'iconKey': iconKey,
        'aspectRatio': aspectRatio,
        'autoplay': autoplay,
        'loop': loop,
      };

  bool get hasVisual =>
      type != SceneMediaType.none &&
      (asset.isNotEmpty ||
          (url?.isNotEmpty ?? false) ||
          (iconKey?.isNotEmpty ?? false));

  @override
  bool operator ==(Object other) {
    return other is SceneMedia &&
        other.type == type &&
        other.asset == asset &&
        other.url == url &&
        other.state == state &&
        other.iconKey == iconKey &&
        other.aspectRatio == aspectRatio &&
        other.autoplay == autoplay &&
        other.loop == loop;
  }

  @override
  int get hashCode => Object.hash(
        type,
        asset,
        url,
        state,
        iconKey,
        aspectRatio,
        autoplay,
        loop,
      );
}

@immutable
class SceneMotion {
  final SceneMotionPreset preset;

  /// Full cycle seconds for continuous presets (breathe / orbit / …).
  final int durationSec;

  const SceneMotion({
    this.preset = SceneMotionPreset.none,
    this.durationSec = 18,
  });

  factory SceneMotion.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneMotion();
    // Accept flat string: "motion":"orbit" or object form.
    if (json.containsKey('preset') || json.containsKey('duration')) {
      final d = json['duration'] ?? json['durationSec'] ?? json['duration_s'];
      final sec = d is num ? d.toInt() : int.tryParse('${d ?? ''}') ?? 18;
      return SceneMotion(
        preset: parseSceneMotionPreset(json['preset']?.toString()),
        durationSec: sec.clamp(4, 120),
      );
    }
    return const SceneMotion();
  }

  /// Parse either a string preset or a map.
  factory SceneMotion.parse(dynamic raw) {
    if (raw is String) {
      return SceneMotion(preset: parseSceneMotionPreset(raw));
    }
    if (raw is Map) {
      return SceneMotion.fromJson(Map<String, dynamic>.from(raw));
    }
    return const SceneMotion();
  }

  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'duration': durationSec,
      };
}

@immutable
class SceneContent {
  final String title;
  final String subtitle;
  final String? body;
  final bool includeNamePlaceholder;
  final SceneTextMode textMode;

  const SceneContent({
    this.title = '',
    this.subtitle = '',
    this.body,
    this.includeNamePlaceholder = false,
    this.textMode = SceneTextMode.staticText,
  });

  factory SceneContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneContent();
    final placeholders = json['placeholders'];
    var includeName = false;
    if (placeholders is Map) {
      final n = placeholders['name'];
      includeName = n is bool ? n : n?.toString() == 'true';
    }
    return SceneContent(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? json['subTitle'] ?? '').toString(),
      body: json['body']?.toString(),
      includeNamePlaceholder: includeName,
      textMode: parseSceneTextMode(
        (json['textMode'] ?? json['text_mode'])?.toString(),
      ),
    );
  }

  String resolveTitle(String userName) {
    if (!includeNamePlaceholder) return title;
    return title.replaceAll('{name}', userName);
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        if (body != null) 'body': body,
        'placeholders': {'name': includeNamePlaceholder},
        'textMode': textMode.name,
      };

  bool get hasText =>
      title.trim().isNotEmpty ||
      subtitle.trim().isNotEmpty ||
      (body?.trim().isNotEmpty ?? false);

  @override
  bool operator ==(Object other) {
    return other is SceneContent &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.body == body &&
        other.includeNamePlaceholder == includeNamePlaceholder &&
        other.textMode == textMode;
  }

  @override
  int get hashCode => Object.hash(
        title,
        subtitle,
        body,
        includeNamePlaceholder,
        textMode,
      );
}

@immutable
class SceneLifecycle {
  final int showDurationMs;
  final bool once;
  final bool restoreOnComplete;

  const SceneLifecycle({
    this.showDurationMs = 15000,
    this.once = true,
    this.restoreOnComplete = true,
  });

  factory SceneLifecycle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneLifecycle();
    final ms =
        json['showDurationMs'] ?? json['showDuration'] ?? json['durationMs'];
    final onceRaw = json['once'] ?? json['playOnce'];
    return SceneLifecycle(
      showDurationMs: () {
        if (ms is num) return ms.toInt().clamp(1500, 60000);
        return int.tryParse('${ms ?? ''}')?.clamp(1500, 60000) ?? 15000;
      }(),
      once: onceRaw is bool ? onceRaw : onceRaw?.toString() != 'false',
      restoreOnComplete: json['restoreOnComplete'] is bool
          ? json['restoreOnComplete'] as bool
          : json['restoreOnComplete']?.toString() != 'false',
    );
  }

  Map<String, dynamic> toJson() => {
        'showDurationMs': showDurationMs,
        'once': once,
        'restoreOnComplete': restoreOnComplete,
      };
}

@immutable
class SceneCta {
  final String label;
  final String action;

  const SceneCta({
    this.label = '',
    this.action = '',
  });

  factory SceneCta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneCta();
    return SceneCta(
      label: (json['label'] ?? '').toString(),
      action: (json['action'] ?? json['target'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (label.isNotEmpty) 'label': label,
        if (action.isNotEmpty) 'action': action,
      };

  bool get isActive => label.trim().isNotEmpty && action.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is SceneCta && other.label == label && other.action == action;
  }

  @override
  int get hashCode => Object.hash(label, action);
}

/// One backend-described home scene. Pure data — no widgets.
@immutable
class HomeScene {
  final String id;
  final SceneLayout layout;
  final SceneBackground background;
  final SceneMedia media;
  final SceneMotion motion;
  final SceneContent content;
  final SceneCta cta;
  final SceneLifecycle lifecycle;

  /// Optional decoration keys (e.g. `sparkle`, `grid`) — renderer interprets.
  final List<String> decorations;

  /// Client-only: true when injected locally (education catalog, receive).
  final bool local;

  const HomeScene({
    this.id = '',
    this.layout = SceneLayout.idle,
    this.background = const SceneBackground(),
    this.media = const SceneMedia(),
    this.motion = const SceneMotion(),
    this.content = const SceneContent(),
    this.cta = const SceneCta(),
    this.lifecycle = const SceneLifecycle(),
    this.decorations = const [],
    this.local = false,
  });

  factory HomeScene.idle() =>
      const HomeScene(id: 'idle', layout: SceneLayout.idle);

  factory HomeScene.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HomeScene.idle();

    final motionRaw = json['motion'];
    final mediaRaw = json['media'];
    final bgRaw = json['background'];
    final contentRaw = json['content'];
    final ctaRaw = json['cta'];
    final lifeRaw = json['lifecycle'];
    final decRaw = json['decorations'];

    final decorations = decRaw is List
        ? decRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    // CTA may also live under content.cta in some payloads.
    Map<String, dynamic>? ctaMap;
    if (ctaRaw is Map) {
      ctaMap = Map<String, dynamic>.from(ctaRaw);
    } else if (contentRaw is Map && contentRaw['cta'] is Map) {
      ctaMap = Map<String, dynamic>.from(contentRaw['cta'] as Map);
    }

    return HomeScene(
      id: (json['id'] ?? '').toString(),
      layout: parseSceneLayout(json['layout']?.toString()),
      background: SceneBackground.fromJson(
        bgRaw is Map ? Map<String, dynamic>.from(bgRaw) : null,
      ),
      media: SceneMedia.fromJson(
        mediaRaw is Map ? Map<String, dynamic>.from(mediaRaw) : null,
      ),
      motion: SceneMotion.parse(motionRaw),
      content: SceneContent.fromJson(
        contentRaw is Map ? Map<String, dynamic>.from(contentRaw) : null,
      ),
      cta: SceneCta.fromJson(ctaMap),
      lifecycle: SceneLifecycle.fromJson(
        lifeRaw is Map ? Map<String, dynamic>.from(lifeRaw) : null,
      ),
      decorations: List.unmodifiable(decorations),
      local: json['local'] == true || json['local']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'layout': layout.name,
        'background': background.toJson(),
        'media': media.toJson(),
        'motion': motion.toJson(),
        'content': content.toJson(),
        if (cta.label.isNotEmpty || cta.action.isNotEmpty) 'cta': cta.toJson(),
        'lifecycle': lifecycle.toJson(),
        if (decorations.isNotEmpty) 'decorations': decorations,
        if (local) 'local': true,
      };

  /// Atmosphere-only shell (resting home) — not a theater piece.
  bool get isAtmosphereOnly =>
      id == 'resting' ||
      (layout != SceneLayout.idle &&
          !content.hasText &&
          !media.hasVisual &&
          !cta.isActive &&
          background.isActive);

  /// Theater / campaign piece with user-facing content.
  bool get hasForegroundContent =>
      id.isNotEmpty &&
      id != 'resting' &&
      layout != SceneLayout.idle &&
      (content.hasText || media.hasVisual || cta.isActive);

  bool get isActive =>
      layout != SceneLayout.idle &&
      id.isNotEmpty &&
      (content.hasText || media.hasVisual || background.isActive);

  HomeScene copyWith({
    String? id,
    SceneLayout? layout,
    SceneBackground? background,
    SceneMedia? media,
    SceneMotion? motion,
    SceneContent? content,
    SceneCta? cta,
    SceneLifecycle? lifecycle,
    List<String>? decorations,
    bool? local,
  }) {
    return HomeScene(
      id: id ?? this.id,
      layout: layout ?? this.layout,
      background: background ?? this.background,
      media: media ?? this.media,
      motion: motion ?? this.motion,
      content: content ?? this.content,
      cta: cta ?? this.cta,
      lifecycle: lifecycle ?? this.lifecycle,
      decorations: decorations ?? this.decorations,
      local: local ?? this.local,
    );
  }
}
