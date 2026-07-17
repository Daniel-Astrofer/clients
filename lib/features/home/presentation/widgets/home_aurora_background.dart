import 'package:flutter/material.dart';
import 'package:kerosene/features/home/scene/renderer/aurora_background.dart';

/// Home ambient aurora — thin shell over the Scene-Driven renderer.
///
/// Prefer [SceneAuroraBackground] for new call sites. Kept for existing imports.
class HomeAuroraBackground extends StatelessWidget {
  const HomeAuroraBackground({super.key});

  @override
  Widget build(BuildContext context) => const SceneAuroraBackground();
}
