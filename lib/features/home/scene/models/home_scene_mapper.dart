import 'package:flutter/painting.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';

/// Bridges legacy Communication Stage (HomeStage) → Scene-Driven [HomeScene].
///
/// Screens never see JSON or stage schema; they watch [HomeScene] only.
HomeScene homeSceneFromStage(HomeStage stage) {
  if (!stage.isActive) return HomeScene.idle();

  return HomeScene(
    id: stage.id,
    layout: _layoutFor(stage),
    background: _backgroundFor(stage),
    media: _mediaFor(stage),
    motion: _motionFor(stage),
    content: _contentFor(stage),
    cta: _ctaFor(stage),
    lifecycle: _lifecycleFor(stage),
    local: stage.id.startsWith('local-'),
  );
}

SceneLayout _layoutFor(HomeStage stage) {
  return switch (stage.kind) {
    HomeStageKind.market => SceneLayout.market,
    HomeStageKind.feature ||
    HomeStageKind.announcement ||
    HomeStageKind.promo =>
      SceneLayout.hero,
    HomeStageKind.news => SceneLayout.education,
    HomeStageKind.idle || HomeStageKind.unknown => SceneLayout.idle,
  };
}

SceneBackground _backgroundFor(HomeStage stage) {
  final atmo = stage.resolvedAtmosphere;
  Color primary = const Color(0xFF4D7EFF);
  Color secondary = const Color(0xFF9B7BFF);
  var intensity = 0.28;

  if (atmo.hasGlows) {
    final main = atmo.glows.first;
    primary = resolveStageColorToken(main.colorToken);
    // Feed aurora intensity only — no separate static glow layer.
    intensity = main.intensity.clamp(0.32, 0.58);
    if (atmo.glows.length > 1) {
      secondary = resolveStageColorToken(atmo.glows[1].colorToken);
    } else {
      secondary =
          Color.lerp(primary, const Color(0xFF9B7BFF), 0.45) ?? secondary;
    }
  } else {
    // Theater without explicit glows still brightens the living field a bit.
    intensity = stage.isActive ? 0.38 : 0.26;
  }

  return SceneBackground.aurora(
    primary: primary,
    secondary: secondary,
    intensity: intensity,
  );
}

SceneMedia _mediaFor(HomeStage stage) {
  final m = stage.media;
  final type = switch (m.type) {
    HomeStageMediaType.icon => SceneMediaType.icon,
    HomeStageMediaType.image => SceneMediaType.image,
    HomeStageMediaType.lottie => SceneMediaType.lottie,
    HomeStageMediaType.video => SceneMediaType.video,
    HomeStageMediaType.none ||
    HomeStageMediaType.unknown =>
      SceneMediaType.none,
  };
  if (type == SceneMediaType.none) return const SceneMedia();

  final asset = (m.iconKey ?? '').trim();
  final url = (m.url ?? '').trim();
  return SceneMedia(
    type: type,
    asset: asset.isNotEmpty
        ? asset
        : (url.isNotEmpty ? url.split('/').last.split('.').first : ''),
    url: url.isEmpty ? null : url,
    iconKey: m.iconKey,
    aspectRatio: m.aspectRatio,
    autoplay: m.autoplay,
    loop: m.loop,
  );
}

SceneMotion _motionFor(HomeStage stage) {
  // Always keep living aurora motion while a theater piece is active.
  // Mapping enter motion (fade/slide) onto aurora froze the “feel” into a
  // static color wash; light field should stay an orbit of soft blobs.
  final contentIsMarquee =
      stage.motion.content.type == HomeStageMotionType.marquee ||
          stage.content.textMode == HomeStageTextMode.marquee;
  final showSec = (stage.lifecycle.showDurationMs / 1000).round().clamp(8, 60);
  return SceneMotion(
    preset:
        contentIsMarquee ? SceneMotionPreset.float : SceneMotionPreset.orbit,
    durationSec: showSec,
  );
}

SceneContent _contentFor(HomeStage stage) {
  final c = stage.content;
  final subtitle = c.hasRichBlocks
      ? c.blocks
          .where((b) => b.role == TheaterBlockRole.h2 && b.hasVisibleText)
          .map((b) => b.text.trim())
          .join(' ')
      : '';
  final body = c.hasRichBlocks ? c.plainBodyFallback() : (c.body ?? '');

  var textMode = switch (c.textMode) {
    HomeStageTextMode.typewriter => SceneTextMode.typewriter,
    HomeStageTextMode.marquee => SceneTextMode.marquee,
    _ => SceneTextMode.staticText,
  };
  // Long single-line titles without body still marquee (legacy behavior).
  if (textMode == SceneTextMode.staticText &&
      body.trim().isEmpty &&
      c.title.runes.length >= 28) {
    textMode = SceneTextMode.marquee;
  }
  if (stage.motion.content.type == HomeStageMotionType.marquee &&
      textMode == SceneTextMode.staticText) {
    textMode = SceneTextMode.marquee;
  }

  return SceneContent(
    title: c.title,
    subtitle: subtitle,
    body: body.isEmpty ? null : body,
    includeNamePlaceholder: c.includeNamePlaceholder,
    textMode: textMode,
  );
}

SceneCta _ctaFor(HomeStage stage) {
  final c = stage.content.cta;
  if (c == null || c.label.trim().isEmpty) return const SceneCta();
  final action =
      c.isNavigate ? c.target : (c.action.trim().isEmpty ? c.target : c.action);
  return SceneCta(label: c.label, action: action);
}

SceneLifecycle _lifecycleFor(HomeStage stage) {
  return SceneLifecycle(
    showDurationMs: stage.lifecycle.showDurationMs.clamp(1500, 60000),
    once: stage.playPolicy == HomeStagePlayPolicy.once,
    restoreOnComplete: stage.lifecycle.restoreOnComplete,
  );
}
