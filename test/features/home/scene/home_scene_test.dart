import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';
import 'package:kerosene/features/home/scene/repository/scene_repository.dart';

void main() {
  group('HomeScene.fromJson', () {
    test('parses scene-driven payload without widgets', () {
      final scene = HomeScene.fromJson({
        'id': 'lightning_onboarding',
        'layout': 'hero',
        'background': {
          'type': 'aurora',
          'primary': '#4D7EFF',
          'secondary': '#9B7BFF',
          'intensity': 0.42,
        },
        'media': {
          'type': 'rive',
          'asset': 'lightning_intro',
        },
        'motion': {
          'preset': 'breathe',
          'duration': 28,
        },
        'content': {
          'title': 'Lightning está pronto',
          'subtitle': 'Pagamentos instantâneos...',
        },
        'cta': {
          'label': 'Experimentar',
          'action': 'open_lightning',
        },
      });

      expect(scene.id, 'lightning_onboarding');
      expect(scene.layout, SceneLayout.hero);
      expect(scene.background.type, SceneBackgroundType.aurora);
      expect(scene.background.primary, const Color(0xFF4D7EFF));
      expect(scene.background.secondary, const Color(0xFF9B7BFF));
      expect(scene.background.intensity, closeTo(0.42, 0.001));
      expect(scene.media.type, SceneMediaType.rive);
      expect(scene.media.asset, 'lightning_intro');
      expect(scene.motion.preset, SceneMotionPreset.breathe);
      expect(scene.motion.durationSec, 28);
      expect(scene.content.title, 'Lightning está pronto');
      expect(scene.cta.action, 'open_lightning');
      expect(scene.isActive, isTrue);
    });

    test('accepts flat motion string', () {
      final scene = HomeScene.fromJson({
        'id': 'x',
        'layout': 'compact',
        'motion': 'orbit',
        'content': {'title': 'Hi'},
      });
      expect(scene.motion.preset, SceneMotionPreset.orbit);
    });
  });

  group('SceneRepository', () {
    const repo = SceneRepository();

    test('parses nested scene key', () {
      final scene = repo.parsePayload({
        'scene': {
          'id': 'a',
          'layout': 'education',
          'content': {'title': 'Learn'},
        },
      });
      expect(scene.layout, SceneLayout.education);
      expect(scene.content.title, 'Learn');
    });

    test('maps legacy HomeStage JSON', () {
      final scene = repo.parsePayload({
        'id': 'stage-1',
        'kind': 'FEATURE',
        'content': {
          'title': 'Welcome',
          'body': 'Hello',
          'cta': {'label': 'Go', 'action': 'NAVIGATE', 'target': '/wallet'},
        },
        'media': {'type': 'ICON', 'iconKey': 'bitcoin'},
        'atmosphere': {
          'glows': [
            {
              'id': 'g1',
              'colorToken': 'cold',
              'intensity': 0.5,
            }
          ],
        },
      });
      expect(scene.id, 'stage-1');
      expect(scene.layout, SceneLayout.hero);
      expect(scene.content.title, 'Welcome');
      expect(scene.media.type, SceneMediaType.icon);
      expect(scene.background.type, SceneBackgroundType.aurora);
      expect(scene.cta.label, 'Go');
    });

    test('resting aurora is atmosphere-only', () {
      final resting = repo.restingAurora();
      expect(resting.id, 'resting');
      expect(resting.background.isActive, isTrue);
      expect(resting.content.hasText, isFalse);
    });
  });

  group('homeSceneFromStage', () {
    test('idle stage → idle scene', () {
      expect(homeSceneFromStage(HomeStage.idle()).layout, SceneLayout.idle);
    });

    test('maps typewriter + once lifecycle', () {
      final scene = homeSceneFromStage(
        HomeStage(
          id: 'local-tip',
          kind: HomeStageKind.feature,
          playPolicy: HomeStagePlayPolicy.once,
          content: const HomeStageContent(
            title: 'Hello',
            body: 'World',
            textMode: HomeStageTextMode.typewriter,
          ),
          lifecycle: const HomeStageLifecycle(showDurationMs: 12000),
        ),
      );
      expect(scene.hasForegroundContent, isTrue);
      expect(scene.content.textMode, SceneTextMode.typewriter);
      expect(scene.lifecycle.once, isTrue);
      expect(scene.lifecycle.showDurationMs, 12000);
      expect(scene.local, isTrue);
    });
  });

  group('Home header action configuration', () {
    test('resting header round-trips placement and visibility', () {
      for (final placement in HomeStageActionsPlacement.values) {
        final original = HomeRestingHeader(
          actionsPlacement: placement,
          balanceVisibility: false,
          notifications: true,
          settings: false,
        );
        final restored = HomeRestingHeader.fromJson(original.toJson());

        final expectedPlacement = placement == HomeStageActionsPlacement.unknown
            ? HomeStageActionsPlacement.belowStage
            : placement;
        expect(restored.actionsPlacement, expectedPlacement);
        expect(restored.balanceVisibility, isFalse);
        expect(restored.notifications, isTrue);
        expect(restored.settings, isFalse);
      }
    });

    test('stage action policy resolves hidden and video cases', () {
      const video = HomeStageMedia(type: HomeStageMediaType.video);
      const image = HomeStageMedia(type: HomeStageMediaType.image);

      expect(
        const HomeStageActionsLayout(
          placement: HomeStageActionsPlacement.overlayEnd,
          policy: HomeStageActionsPolicy.hideForVideo,
        ).resolvePlacement(video),
        HomeStageActionsPlacement.hidden,
      );
      expect(
        const HomeStageActionsLayout(
          placement: HomeStageActionsPlacement.overlayEnd,
          policy: HomeStageActionsPolicy.hideForVideo,
        ).resolvePlacement(image),
        HomeStageActionsPlacement.overlayEnd,
      );
      expect(
        const HomeStageActionsLayout(
          placement: HomeStageActionsPlacement.trailing,
          policy: HomeStageActionsPolicy.forceHidden,
        ).resolvePlacement(image),
        HomeStageActionsPlacement.hidden,
      );
    });
  });

  group('HomeUiEvent scene types', () {
    test('parses HOME_UI_SCENE', () {
      final event = HomeUiEvent.fromJson({
        'type': 'HOME_UI_SCENE',
        'version': 'v2',
        'payload': {
          'id': 'campaign_1',
          'layout': 'hero',
          'content': {'title': 'Promo'},
        },
      });
      expect(event.type, HomeUiEventType.scene);
      expect(event.payload['id'], 'campaign_1');
    });
  });
}
