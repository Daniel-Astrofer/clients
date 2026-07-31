import 'package:flutter/material.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';

/// Canonical golden test resolutions mapped to [KeroseneWindowClass] breakpoints.
///
/// Every screen MUST have golden baselines at all 5 sizes.
/// See [docs/product/design/responsive-strategy.md] and
/// [docs/product/design/design-review-rubric.md] §Golden contract.
class GoldenResolution {
  final String name;
  final Size size;
  final KeroseneWindowClass windowClass;

  const GoldenResolution({
    required this.name,
    required this.size,
    required this.windowClass,
  });

  /// All 5 canonical golden resolutions.
  static const List<GoldenResolution> all = [
    compact,
    medium,
    expanded,
    wide,
    wideLarge,
  ];

  /// iPhone 14 size — compact phone portrait.
  static const compact = GoldenResolution(
    name: 'compact',
    size: Size(390, 844),
    windowClass: KeroseneWindowClass.compact,
  );

  /// Tablet portrait / small desktop.
  static const medium = GoldenResolution(
    name: 'medium',
    size: Size(600, 960),
    windowClass: KeroseneWindowClass.medium,
  );

  /// Tablet landscape / small desktop.
  static const expanded = GoldenResolution(
    name: 'expanded',
    size: Size(1024, 768),
    windowClass: KeroseneWindowClass.expanded,
  );

  /// Desktop standard.
  static const wide = GoldenResolution(
    name: 'wide',
    size: Size(1440, 900),
    windowClass: KeroseneWindowClass.wide,
  );

  /// Desktop large / external monitor.
  static const wideLarge = GoldenResolution(
    name: 'wide_large',
    size: Size(1920, 1080),
    windowClass: KeroseneWindowClass.wide,
  );

  /// Returns the golden file name suffix for this resolution.
  /// E.g., "my_screen_compact", "my_screen_wide".
  String goldenName(String baseName) => '${baseName}_$name';

  @override
  String toString() => 'GoldenResolution($name, ${size.width}x${size.height})';
}

/// Extension to pump a widget at a specific golden resolution.
extension GoldenResolutionPump on WidgetTester {
  /// Pump [child] at [resolution] and advance past post-frame callbacks.
  ///
  /// Usage:
  /// ```dart
  /// await tester.pumpGoldenAt(myScreen, GoldenResolution.compact);
  /// await screenMatchesGolden(tester, 'my_screen_compact');
  /// ```
  Future<void> pumpGoldenAt(
    Widget child,
    GoldenResolution resolution,
  ) async {
    await binding.setSurfaceSize(resolution.size);
    addTearDown(() => binding.setSurfaceSize(null));
    // Ensure the widget tree builds at the target physical size
    await pumpWidget(child);
    // Advance enough frames for post-frame callbacks, animations, and font load
    for (var i = 0; i < 8; i++) {
      await pump(const Duration(milliseconds: 120));
    }
  }
}
