/// Scene-Driven UI public barrel.
///
/// Backend describes scenes; Flutter renders them. Screens import this file —
/// not JSON parsers or raw stage maps.
library;

export 'models/home_scene.dart';
export 'models/home_scene_mapper.dart';
export 'providers/scene_provider.dart';
export 'repository/scene_repository.dart';
export 'renderer/action_layer.dart';
export 'renderer/aurora_background.dart';
export 'renderer/gemini_glow_background.dart';
export 'renderer/content_layer.dart';
export 'renderer/hero_scene.dart';
export 'renderer/home_scene_host.dart';
export 'renderer/media_layer.dart';
export 'renderer/scene_transition.dart';
