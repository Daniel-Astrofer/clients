import 'package:flutter/painting.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';

/// Source of truth for scene payloads (HTTP snapshot, WebSocket patch, local).
///
/// Screens never parse JSON — only [SceneRepository] / mapper do.
class SceneRepository {
  const SceneRepository();

  /// Parse a raw scene object (or map nested under `scene`).
  HomeScene parsePayload(dynamic raw) {
    if (raw == null) return HomeScene.idle();
    if (raw is HomeScene) return raw;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['scene'] is Map) {
        return HomeScene.fromJson(Map<String, dynamic>.from(map['scene'] as Map));
      }
      // Accept either pure scene JSON or legacy stage JSON (has kind/playPolicy).
      if (map.containsKey('layout') || map.containsKey('background')) {
        return HomeScene.fromJson(map);
      }
      if (map.containsKey('kind') || map.containsKey('content')) {
        return homeSceneFromStage(HomeStage.fromJson(map));
      }
      return HomeScene.fromJson(map);
    }
    return HomeScene.idle();
  }

  HomeScene fromStage(HomeStage stage) => homeSceneFromStage(stage);

  /// Resting home atmosphere when no theater piece is active.
  HomeScene restingAurora() {
    return HomeScene(
      id: 'resting',
      layout: SceneLayout.hero,
      background: SceneBackground.aurora(
        primary: const Color(0xFF4D7EFF),
        secondary: const Color(0xFF9B7BFF),
        intensity: 0.25,
      ),
      motion: const SceneMotion(
        preset: SceneMotionPreset.orbit,
        durationSec: 8,
      ),
      // No content/CTA — only ambient background for the home shell.
    );
  }
}
