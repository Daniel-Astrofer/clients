import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/presentation/providers/home_aurora_renderer_provider.dart';
import 'package:kerosene/features/home/scene/renderer/aurora_background.dart';
import 'package:kerosene/features/home/scene/renderer/gemini_glow_background.dart';

/// Home ambient aurora shell.
///
/// Defaults to the Gemini fragment shader. The CustomPainter path remains
/// available via [homeAuroraRendererProvider] for A/B comparison.
class HomeAuroraBackground extends ConsumerWidget {
  const HomeAuroraBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(homeAuroraRendererProvider);
    return switch (renderer) {
      HomeAuroraRenderer.shader => const SceneGeminiGlowBackground(),
      HomeAuroraRenderer.painter => const SceneAuroraBackground(),
    };
  }
}

/// Debug A/B chip — tap to flip shader ↔ painter. Only in debug builds.
class HomeAuroraRendererDebugToggle extends ConsumerWidget {
  const HomeAuroraRendererDebugToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final renderer = ref.watch(homeAuroraRendererProvider);
    final label = switch (renderer) {
      HomeAuroraRenderer.shader => 'Aurora: GLSL',
      HomeAuroraRenderer.painter => 'Aurora: Paint',
    };
    return Positioned(
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => ref.read(homeAuroraRendererProvider.notifier).toggle(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
