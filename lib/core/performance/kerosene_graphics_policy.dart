import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/performance/graphics_runtime_degrade.dart';

/// Device graphics quality tier. High keeps full authored effects;
/// low swaps expensive composition for pixel-close solid fallbacks.
enum GraphicsTier {
  high,
  mid,
  low,
}

/// Central flags for raster-costly effects. Visual design tokens stay the same;
/// only engine paths (blur, ambient loops, cache caps) are gated.
@immutable
class KeroseneGraphicsPolicy {
  final GraphicsTier tier;
  final bool allowBackdropBlur;
  final bool allowImageFilteredBlur;
  final bool allowAuroraShaderMotion;
  final bool allowAmbientGpuLoops;
  final int maxImageCacheBytes;
  final int maxImageCacheEntries;

  const KeroseneGraphicsPolicy({
    required this.tier,
    required this.allowBackdropBlur,
    required this.allowImageFilteredBlur,
    required this.allowAuroraShaderMotion,
    required this.allowAmbientGpuLoops,
    required this.maxImageCacheBytes,
    required this.maxImageCacheEntries,
  });

  static const high = KeroseneGraphicsPolicy(
    tier: GraphicsTier.high,
    allowBackdropBlur: true,
    allowImageFilteredBlur: true,
    allowAuroraShaderMotion: true,
    allowAmbientGpuLoops: true,
    maxImageCacheBytes: 100 * 1024 * 1024,
    maxImageCacheEntries: 120,
  );

  static const mid = KeroseneGraphicsPolicy(
    tier: GraphicsTier.mid,
    allowBackdropBlur: true,
    allowImageFilteredBlur: true,
    allowAuroraShaderMotion: true,
    allowAmbientGpuLoops: true,
    maxImageCacheBytes: 64 * 1024 * 1024,
    maxImageCacheEntries: 80,
  );

  static const low = KeroseneGraphicsPolicy(
    tier: GraphicsTier.low,
    allowBackdropBlur: false,
    allowImageFilteredBlur: false,
    allowAuroraShaderMotion: false,
    allowAmbientGpuLoops: false,
    maxImageCacheBytes: 32 * 1024 * 1024,
    maxImageCacheEntries: 48,
  );

  /// Strip expensive GPU paths while keeping cache caps / tier identity.
  KeroseneGraphicsPolicy withoutExpensiveEffects() {
    if (!allowBackdropBlur &&
        !allowImageFilteredBlur &&
        !allowAuroraShaderMotion &&
        !allowAmbientGpuLoops) {
      return this;
    }
    return KeroseneGraphicsPolicy(
      tier: tier,
      allowBackdropBlur: false,
      allowImageFilteredBlur: false,
      allowAuroraShaderMotion: false,
      allowAmbientGpuLoops: false,
      maxImageCacheBytes: maxImageCacheBytes,
      maxImageCacheEntries: maxImageCacheEntries,
    );
  }

  /// Resolve tier from compile-time override and a coarse device heuristic.
  ///
  /// Override: `--dart-define=GRAPHICS_TIER=low|mid|high`
  factory KeroseneGraphicsPolicy.resolve({
    String? dartDefineTier,
    int? deviceRamMb,
  }) {
    final raw = (dartDefineTier ??
            const String.fromEnvironment('GRAPHICS_TIER', defaultValue: ''))
        .trim()
        .toLowerCase();
    if (raw == 'low') return low;
    if (raw == 'mid' || raw == 'medium') return mid;
    if (raw == 'high') return high;

    if (deviceRamMb != null) {
      if (deviceRamMb > 0 && deviceRamMb < 3000) return low;
      if (deviceRamMb > 0 && deviceRamMb < 6000) return mid;
    }

    // Safe default for unknown devices: mid (effects on, moderate cache).
    return mid;
  }
}

/// Static device tier only (no FrameTiming). Use for bootstrap ImageCache.
final baseGraphicsPolicyProvider = Provider<KeroseneGraphicsPolicy>((ref) {
  return KeroseneGraphicsPolicy.resolve();
});

/// Effective policy: base tier + optional runtime degrade under sustained jank.
final graphicsPolicyProvider = Provider<KeroseneGraphicsPolicy>((ref) {
  final base = ref.watch(baseGraphicsPolicyProvider);
  final degraded = ref.watch(graphicsRuntimeDegradeProvider);
  return degraded ? base.withoutExpensiveEffects() : base;
});
