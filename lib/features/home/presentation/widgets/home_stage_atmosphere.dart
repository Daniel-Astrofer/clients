import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_stage_playback_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';

/// Design-system color tokens for theater glows.
/// Never resolve to pure white for washes — always a tinted color.
Color resolveStageColorToken(String token, {Color? fallback}) {
  return switch (token.trim().toLowerCase()) {
    'positive' || 'green' || 'up' => homePositiveColor,
    'danger' || 'red' || 'down' => AppColors.hexFFFF5A67,
    'amber' || 'onchain' || 'orange' || 'bitcoin' => homeAmberColor,
    'cold' || 'blue' || 'sky' => const Color(0xFF7DD3FC),
    'platform' || 'white' => const Color(0xFFB8C4D4),
    'muted' => homeMutedTextColor,
    'brand' || 'warm' => const Color(0xFFE8D5B5),
    'soft' || 'cream' => const Color(0xFFF2E6D0),
    _ => fallback ?? const Color(0xFF7DD3FC),
  };
}

/// Colored accent for resting wash by ledger page — never pure white.
Color restingWashAccentFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => const Color(0xFF7DD3FC),
    HomeLedgerBalanceView.platform => const Color(0xFFB8C4D4),
    HomeLedgerBalanceView.onChain => homeAmberColor,
    HomeLedgerBalanceView.cold => const Color(0xFF7DD3FC),
  };
}

String restingWashTokenFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => 'cold',
    HomeLedgerBalanceView.platform => 'platform',
    HomeLedgerBalanceView.onChain => 'amber',
    HomeLedgerBalanceView.cold => 'cold',
  };
}

@immutable
class TheaterTopWashStyle {
  final Color accent;
  final double peakAlpha;
  final Duration transition;
  final bool theaterActive;

  const TheaterTopWashStyle({
    required this.accent,
    required this.peakAlpha,
    required this.theaterActive,
    this.transition = const Duration(milliseconds: 480),
  });

  Color get solidColor => Color.alphaBlend(
        accent.withValues(alpha: peakAlpha.clamp(0.0, 0.72)),
        const Color(0xFF000000),
      );
}

TheaterTopWashStyle resolveTheaterTopWashStyle({
  required HomeStage stage,
  required HomeLedgerBalanceView view,
  required bool stagePlaying,
}) {
  final atmo = stage.resolvedAtmosphere;
  final theaterActive = stagePlaying && stage.isActive;
  final ms = atmo.transitionMs.clamp(180, 1200);

  if (theaterActive && atmo.hasGlows) {
    final main = atmo.glows.first;
    var accent = resolveStageColorToken(main.colorToken);
    if (accent.computeLuminance() > 0.92 && accent.a >= 0.95) {
      accent = const Color(0xFF7DD3FC);
    }
    return TheaterTopWashStyle(
      accent: accent,
      peakAlpha: main.intensity.clamp(0.38, 0.58),
      theaterActive: true,
      transition: Duration(milliseconds: ms),
    );
  }

  if (theaterActive) {
    return TheaterTopWashStyle(
      accent: restingWashAccentFor(view),
      peakAlpha: 0.48,
      theaterActive: true,
      transition: Duration(milliseconds: ms),
    );
  }

  return TheaterTopWashStyle(
    accent: restingWashAccentFor(view),
    peakAlpha: 0.22,
    theaterActive: false,
    transition: Duration(milliseconds: ms),
  );
}

TheaterTopWashStyle watchTheaterTopWashStyle(WidgetRef ref) {
  final stage = ref.watch(homeSurfaceProvider.select((s) => s.stage));
  final playback = ref.watch(homeStagePlaybackProvider);
  final view = ref.watch(homeLedgerBalanceViewProvider);
  return resolveTheaterTopWashStyle(
    stage: stage,
    view: view,
    stagePlaying: playback.isPlaying && stage.isActive,
  );
}

/// Scaffold stays pure black — glow lives only in the aurora layer.
final theaterScaffoldSolidColorProvider = Provider<Color>((ref) {
  return homeBackgroundColor;
});

/// Layout shell around the communication stage.
///
/// **No painted wash / SoftEdgeBloom / static glow stack.** Those were a
/// fixed vertical linear fade over static radials, which read as a straight
/// degrade band when backend theater text arrived. Ambient light is owned
/// exclusively by [SceneAuroraBackground] (moving multi-blob haze).
class HomeTheaterHeaderWash extends ConsumerWidget {
  final Widget child;

  const HomeTheaterHeaderWash({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    // Tiny tail only for safe-area spacing — no gradient paint.
    final fadeTail = (MediaQuery.sizeOf(context).height * 0.02).clamp(8.0, 16.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: child,
        ),
        SizedBox(height: fadeTail),
      ],
    );
  }
}
