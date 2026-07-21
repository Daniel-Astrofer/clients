import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which home aurora implementation is active.
///
/// Keep both [painter] (CustomPaint blobs/waves) and [shader] (GLSL Gemini)
/// so we can A/B which looks better without deleting either path.
enum HomeAuroraRenderer {
  /// Existing [SceneAuroraBackground] CustomPainter.
  painter,

  /// New [SceneGeminiGlowBackground] fragment shader.
  shader,
}

class HomeAuroraRendererNotifier extends Notifier<HomeAuroraRenderer> {
  @override
  HomeAuroraRenderer build() => HomeAuroraRenderer.shader;

  void set(HomeAuroraRenderer next) => state = next;

  void toggle() {
    state = state == HomeAuroraRenderer.shader
        ? HomeAuroraRenderer.painter
        : HomeAuroraRenderer.shader;
  }
}

final homeAuroraRendererProvider =
    NotifierProvider<HomeAuroraRendererNotifier, HomeAuroraRenderer>(
  HomeAuroraRendererNotifier.new,
);
