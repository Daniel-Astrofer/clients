import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeLedgerBalanceViewProvider;
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';
import 'package:kerosene/features/home/scene/repository/scene_repository.dart';

final sceneRepositoryProvider = Provider<SceneRepository>((ref) {
  return const SceneRepository();
});

/// Active [HomeScene] for the home shell.
///
/// Derives from Communication Stage when present; otherwise resting aurora.
/// Supports local overrides (WebSocket / education) via [HomeSceneNotifier.present].
final homeSceneProvider =
    NotifierProvider<HomeSceneNotifier, HomeScene>(HomeSceneNotifier.new);

/// Convenience: only the background config (aurora layer).
final homeSceneBackgroundProvider = Provider<SceneBackground>((ref) {
  return ref.watch(homeSceneProvider.select((s) => s.background));
});

/// Convenience: motion preset for continuous atmosphere.
final homeSceneMotionProvider = Provider<SceneMotion>((ref) {
  return ref.watch(homeSceneProvider.select((s) => s.motion));
});

class HomeSceneNotifier extends Notifier<HomeScene> {
  final SceneRepository _repo = const SceneRepository();

  /// Local/override scene (education, receive, WS push). Null = follow surface.
  HomeScene? _override;

  @override
  HomeScene build() {
    ref.listen<HomeStage>(
      homeSurfaceProvider.select((s) => s.stage),
      (prev, next) {
        if (_override != null) {
          // Drop override when a higher-priority remote stage arrives.
          if (next.isActive &&
              !next.id.startsWith('local-') &&
              next.id != _override!.id) {
            _override = null;
          } else if (!next.isActive && _override!.local && next.id.isEmpty) {
            // Stage cleared — keep override only if still local active.
          }
        }
        state = _resolve(next);
      },
    );

    // Also tint resting aurora with ledger wash accent when idle.
    ref.listen(homeLedgerBalanceViewProvider, (prev, next) {
      if (prev != next && (_override == null || !_override!.isActive)) {
        final stage = ref.read(homeSurfaceProvider).stage;
        if (!stage.isActive) {
          state = _restingForLedger();
        }
      }
    });

    final stage = ref.read(homeSurfaceProvider).stage;
    return _resolve(stage);
  }

  HomeScene _resolve(HomeStage stage) {
    if (_override != null && _override!.isActive) {
      return _override!;
    }
    if (stage.isActive) {
      return homeSceneFromStage(stage);
    }
    return _restingForLedger();
  }

  HomeScene _restingForLedger() {
    final resting = _repo.restingAurora();
    try {
      final view = ref.read(homeLedgerBalanceViewProvider);
      final accent = restingWashAccentFor(view);
      return resting.copyWith(
        background: SceneBackground.aurora(
          primary: accent,
          secondary: resting.background.secondary,
          intensity: resting.background.intensity,
        ),
      );
    } catch (_) {
      return resting;
    }
  }

  /// Present a scene from raw JSON (WebSocket / future content API).
  void presentFromJson(Map<String, dynamic> json) {
    final scene = _repo.parsePayload(json);
    present(scene);
  }

  /// Inject a fully built scene (local education, campaign, alert).
  void present(HomeScene scene) {
    if (!scene.isActive && scene.layout == SceneLayout.idle) {
      clearOverride();
      return;
    }
    _override = scene;
    state = scene;
    debugPrint(
        '[homeScene] present id=${scene.id} layout=${scene.layout.name}');
  }

  /// Clear local override; fall back to surface stage / resting.
  void clearOverride() {
    _override = null;
    state = _resolve(ref.read(homeSurfaceProvider).stage);
  }
}
