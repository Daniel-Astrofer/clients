import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeSize;
import 'package:kerosene/features/home/scene/models/home_scene.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';
import 'package:kerosene/features/home/scene/renderer/action_layer.dart';
import 'package:kerosene/features/home/scene/renderer/content_layer.dart';
import 'package:kerosene/features/home/scene/renderer/media_layer.dart';
import 'package:kerosene/features/home/scene/renderer/scene_transition.dart';

/// Top-level scene host — picks a native layout renderer.
///
/// No screen parses JSON; only this renderer (and layers) touch [HomeScene].
class HeroScene extends ConsumerWidget {
  final String userName;
  final SceneActionHandler? onAction;
  /// Optional trailing chrome (e.g. notification bell) kept outside scene JSON.
  final Widget? trailing;

  const HeroScene({
    super.key,
    this.userName = '',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(homeSceneProvider);

    if (!scene.hasForegroundContent) {
      return _ChromeOnly(trailing: trailing);
    }

    return SceneTransition(
      scene: scene,
      child: switch (scene.layout) {
        SceneLayout.hero ||
        SceneLayout.immersive ||
        SceneLayout.fullscreen =>
          HeroRenderer(
            scene: scene,
            userName: userName,
            onAction: onAction,
            trailing: trailing,
          ),
        SceneLayout.education || SceneLayout.card => EducationRenderer(
            scene: scene,
            userName: userName,
            onAction: onAction,
            trailing: trailing,
          ),
        SceneLayout.market => MarketRenderer(
            scene: scene,
            userName: userName,
            onAction: onAction,
            trailing: trailing,
          ),
        SceneLayout.compact => CompactRenderer(
            scene: scene,
            userName: userName,
            onAction: onAction,
            trailing: trailing,
          ),
        SceneLayout.idle => _ChromeOnly(trailing: trailing),
      },
    );
  }
}

class _ChromeOnly extends StatelessWidget {
  final Widget? trailing;

  const _ChromeOnly({this.trailing});

  @override
  Widget build(BuildContext context) {
    if (trailing == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topRight,
      child: trailing!,
    );
  }
}

/// Desktop vs mobile shell for hero layouts.
class HeroRenderer extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const HeroRenderer({
    super.key,
    required this.scene,
    this.userName = '',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = KeroseneResponsiveScope.of(context);
    if (responsive.useWideHomeLayout) {
      return _DesktopHero(
        scene: scene,
        userName: userName,
        onAction: onAction,
        trailing: trailing,
      );
    }
    return _MobileHero(
      scene: scene,
      userName: userName,
      onAction: onAction,
      trailing: trailing,
    );
  }
}

class _MobileHero extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const _MobileHero({
    required this.scene,
    required this.userName,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Align(alignment: Alignment.topRight, child: trailing!),
        if (scene.media.hasVisual) ...[
          SceneMediaLayer(media: scene.media, maxHeight: 100),
          SizedBox(height: homeSize(12)),
        ],
        SceneContentLayer(
          content: scene.content,
          userName: userName,
          showDurationMs: scene.lifecycle.showDurationMs,
        ),
        if (scene.cta.isActive) ...[
          SizedBox(height: homeSize(14)),
          Align(
            alignment: Alignment.centerLeft,
            child: SceneActionLayer(cta: scene.cta, onAction: onAction),
          ),
        ],
      ],
    );
  }
}

class _DesktopHero extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const _DesktopHero({
    required this.scene,
    required this.userName,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scene.media.hasVisual) ...[
          SizedBox(
            width: homeSize(140),
            child: SceneMediaLayer(media: scene.media, maxHeight: 120),
          ),
          SizedBox(width: homeSize(20)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SceneContentLayer(
                content: scene.content,
                userName: userName,
                showDurationMs: scene.lifecycle.showDurationMs,
              ),
              if (scene.cta.isActive) ...[
                SizedBox(height: homeSize(16)),
                SceneActionLayer(cta: scene.cta, onAction: onAction),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: homeSize(12)),
          trailing!,
        ],
      ],
    );
  }
}

class EducationRenderer extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const EducationRenderer({
    super.key,
    required this.scene,
    this.userName = '',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scene.media.hasVisual) ...[
              SceneMediaLayer(media: scene.media, maxHeight: 56),
              SizedBox(width: homeSize(12)),
            ],
            Expanded(
              child: SceneContentLayer(
                content: scene.content,
                userName: userName,
                compact: true,
                showDurationMs: scene.lifecycle.showDurationMs,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (scene.cta.isActive) ...[
          SizedBox(height: homeSize(12)),
          Align(
            alignment: Alignment.centerLeft,
            child: SceneActionLayer(cta: scene.cta, onAction: onAction),
          ),
        ],
      ],
    );
  }
}

class MarketRenderer extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const MarketRenderer({
    super.key,
    required this.scene,
    this.userName = '',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Market layout: compact headline + optional CTA; chart lives in feed.
    return EducationRenderer(
      scene: scene,
      userName: userName,
      onAction: onAction,
      trailing: trailing,
    );
  }
}

class CompactRenderer extends StatelessWidget {
  final HomeScene scene;
  final String userName;
  final SceneActionHandler? onAction;
  final Widget? trailing;

  const CompactRenderer({
    super.key,
    required this.scene,
    this.userName = '',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SceneContentLayer(
            content: scene.content,
            userName: userName,
            compact: true,
            showDurationMs: scene.lifecycle.showDurationMs,
          ),
        ),
        if (scene.cta.isActive)
          SceneActionLayer(cta: scene.cta, onAction: onAction),
        if (trailing != null) trailing!,
      ],
    );
  }
}
