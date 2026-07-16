import 'package:kerosene/features/home/domain/entities/home_stage.dart';

/// Named glow packs for education / product theater pieces.
enum TheaterAtmospherePreset {
  learn,
  bitcoin,
  lightning,
  security,
  positive,
  brand,
  marketUp,
  marketDown,
}

HomeStageAtmosphere theaterAtmosphereFor(
  TheaterAtmospherePreset preset, {
  bool animated = true,
  int transitionMs = 480,
}) {
  List<HomeStageGlow> glows;
  switch (preset) {
    case TheaterAtmospherePreset.learn:
      glows = const [
        HomeStageGlow(
          id: 'learn-main',
          colorToken: 'cold',
          x: 0.5,
          y: 0.0,
          width: 1.65,
          height: 0.55,
          intensity: 0.44,
          radius: 0.72,
        ),
        HomeStageGlow(
          id: 'learn-rim',
          colorToken: 'platform',
          x: 0.22,
          y: 0.12,
          width: 0.75,
          height: 0.32,
          intensity: 0.16,
          radius: 0.6,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.bitcoin:
      glows = const [
        HomeStageGlow(
          id: 'btc-main',
          colorToken: 'amber',
          x: 0.5,
          y: 0.0,
          width: 1.7,
          height: 0.52,
          intensity: 0.46,
          radius: 0.72,
        ),
        HomeStageGlow(
          id: 'btc-rim',
          colorToken: 'soft',
          x: 0.72,
          y: 0.1,
          width: 0.8,
          height: 0.3,
          intensity: 0.18,
          radius: 0.6,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.lightning:
      glows = const [
        HomeStageGlow(
          id: 'ln-main',
          colorToken: 'amber',
          x: 0.48,
          y: 0.0,
          width: 1.55,
          height: 0.5,
          intensity: 0.48,
          radius: 0.7,
        ),
        HomeStageGlow(
          id: 'ln-flash',
          colorToken: 'brand',
          x: 0.65,
          y: 0.05,
          width: 0.7,
          height: 0.28,
          intensity: 0.22,
          radius: 0.55,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.security:
      glows = const [
        HomeStageGlow(
          id: 'sec-main',
          colorToken: 'cold',
          x: 0.5,
          y: 0.0,
          width: 1.6,
          height: 0.55,
          intensity: 0.42,
          radius: 0.72,
        ),
        HomeStageGlow(
          id: 'sec-rim',
          colorToken: 'platform',
          x: 0.3,
          y: 0.1,
          width: 0.7,
          height: 0.3,
          intensity: 0.14,
          radius: 0.6,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.positive:
      glows = const [
        HomeStageGlow(
          id: 'pos-main',
          colorToken: 'positive',
          x: 0.5,
          y: 0.0,
          width: 1.7,
          height: 0.55,
          intensity: 0.48,
          radius: 0.72,
        ),
      ];
    case TheaterAtmospherePreset.brand:
      glows = const [
        HomeStageGlow(
          id: 'brand-main',
          colorToken: 'brand',
          x: 0.5,
          y: 0.0,
          width: 1.55,
          height: 0.5,
          intensity: 0.4,
          radius: 0.7,
        ),
        HomeStageGlow(
          id: 'brand-rim',
          colorToken: 'soft',
          x: 0.25,
          y: 0.12,
          width: 0.65,
          height: 0.28,
          intensity: 0.15,
          radius: 0.55,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.marketUp:
      glows = const [
        HomeStageGlow(
          id: 'mkt-main',
          colorToken: 'positive',
          x: 0.5,
          y: 0.0,
          width: 1.7,
          height: 0.52,
          intensity: 0.48,
          radius: 0.72,
        ),
        HomeStageGlow(
          id: 'mkt-rim',
          colorToken: 'positive',
          x: 0.72,
          y: 0.08,
          width: 0.9,
          height: 0.35,
          intensity: 0.22,
          radius: 0.65,
          zIndex: 1,
        ),
      ];
    case TheaterAtmospherePreset.marketDown:
      glows = const [
        HomeStageGlow(
          id: 'mkt-main',
          colorToken: 'danger',
          x: 0.5,
          y: 0.0,
          width: 1.7,
          height: 0.52,
          intensity: 0.48,
          radius: 0.72,
        ),
        HomeStageGlow(
          id: 'mkt-rim',
          colorToken: 'danger',
          x: 0.28,
          y: 0.08,
          width: 0.9,
          height: 0.35,
          intensity: 0.22,
          radius: 0.65,
          zIndex: 1,
        ),
      ];
  }

  return HomeStageAtmosphere(
    glows: glows,
    animated: animated,
    transitionMs: transitionMs,
  );
}

TheaterAtmospherePreset? parseTheaterAtmospherePreset(String? raw) {
  return switch ((raw ?? '').trim().toLowerCase()) {
    'learn' || 'education' => TheaterAtmospherePreset.learn,
    'bitcoin' || 'onchain' || 'btc' => TheaterAtmospherePreset.bitcoin,
    'lightning' || 'ln' => TheaterAtmospherePreset.lightning,
    'security' || 'sec' || 'totp' => TheaterAtmospherePreset.security,
    'positive' || 'success' || 'receive' => TheaterAtmospherePreset.positive,
    'brand' || 'warm' || 'product' => TheaterAtmospherePreset.brand,
    'marketup' || 'market_up' || 'up' => TheaterAtmospherePreset.marketUp,
    'marketdown' || 'market_down' || 'down' => TheaterAtmospherePreset.marketDown,
    _ => null,
  };
}
