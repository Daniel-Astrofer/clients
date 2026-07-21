import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';

enum KeroseneWindowClass { compact, medium, expanded, wide }

/// Shared responsive metrics for Kerosene screens.
///
/// This keeps breakpoint math and text scaling in one place so individual
/// screens do not invent slightly different behavior for every device.
class KeroseneResponsiveMetrics {
  final Size size;
  final EdgeInsets viewPadding;
  final KeroseneWindowClass windowClass;
  final double systemTextScale;
  final double effectiveTextScale;

  const KeroseneResponsiveMetrics({
    required this.size,
    required this.viewPadding,
    required this.windowClass,
    required this.systemTextScale,
    required this.effectiveTextScale,
  });

  factory KeroseneResponsiveMetrics.fromMediaQuery(
    MediaQueryData mediaQuery, {
    double requestedTextScale = 1.0,
  }) {
    final width = mediaQuery.size.width;
    final systemScale = mediaQuery.textScaler.scale(1.0);
    final rawScale = systemScale * requestedTextScale;
    final windowClass = _classForWidth(width);

    return KeroseneResponsiveMetrics(
      size: mediaQuery.size,
      viewPadding: mediaQuery.viewPadding,
      windowClass: windowClass,
      systemTextScale: systemScale,
      effectiveTextScale: _scaleForWidth(width, rawScale),
    );
  }

  bool get isCompact => windowClass == KeroseneWindowClass.compact;
  bool get isMedium => windowClass == KeroseneWindowClass.medium;
  bool get isExpanded => windowClass == KeroseneWindowClass.expanded;
  bool get isWide => windowClass == KeroseneWindowClass.wide;
  bool get isTinyPhone => size.width < 360;

  double get horizontalPadding {
    return switch (windowClass) {
      KeroseneWindowClass.compact =>
        size.width < 340 ? AppSpacing.sm : AppSpacing.md,
      KeroseneWindowClass.medium => AppSpacing.lg,
      KeroseneWindowClass.expanded => AppSpacing.xl,
      KeroseneWindowClass.wide => AppSpacing.xxl,
    };
  }

  /// Usable width after horizontal page padding.
  double get usableWidth {
    return math.max(0.0, size.width - (horizontalPadding * 2));
  }

  /// Whether the window is large enough for desktop-style multi-column home.
  bool get useWideHomeLayout =>
      windowClass == KeroseneWindowClass.expanded ||
      windowClass == KeroseneWindowClass.wide;

  /// Wide reading column (landing, long-form). Caps only — screens own padding.
  double get maxReadableWidth {
    return switch (windowClass) {
      KeroseneWindowClass.compact => size.width,
      KeroseneWindowClass.medium => math.min(size.width, 760),
      KeroseneWindowClass.expanded => math.min(size.width, 1040),
      KeroseneWindowClass.wide => math.min(size.width, 1280),
    };
  }

  /// Primary app column (home, settings, statements, accounts).
  ///
  /// Fills the window so Linux/desktop never shows a phone-width column with
  /// empty side bars. Screens apply their own horizontal padding for breathing
  /// room; only extreme ultrawide gets a soft readability cap.
  double get mobileContentMaxWidth {
    return switch (windowClass) {
      KeroseneWindowClass.compact => size.width,
      KeroseneWindowClass.medium => size.width,
      KeroseneWindowClass.expanded => size.width,
      // Soft cap only for multi-monitor ultrawide setups.
      KeroseneWindowClass.wide => math.min(size.width, 1920),
    };
  }

  /// Alias used by screens that want the main app column width.
  double get appColumnMaxWidth => mobileContentMaxWidth;

  /// Auth / form surfaces: wider than a phone, still readable as a form.
  double get formMaxWidth {
    return switch (windowClass) {
      KeroseneWindowClass.compact => size.width,
      KeroseneWindowClass.medium => math.min(size.width, 520),
      KeroseneWindowClass.expanded => math.min(size.width, 560),
      KeroseneWindowClass.wide => math.min(size.width, 600),
    };
  }

  double get sheetMaxWidth {
    return switch (windowClass) {
      KeroseneWindowClass.compact => size.width,
      KeroseneWindowClass.medium => math.min(size.width, 560),
      KeroseneWindowClass.expanded => math.min(size.width, 640),
      KeroseneWindowClass.wide => math.min(size.width, 720),
    };
  }

  BoxConstraints get appColumnConstraints =>
      BoxConstraints(maxWidth: appColumnMaxWidth);

  BoxConstraints get formConstraints =>
      BoxConstraints(maxWidth: formMaxWidth);

  double compactFontSize({
    required double compact,
    required double regular,
    double? tiny,
    double? medium,
    double? expanded,
    double? wide,
  }) {
    if (isTinyPhone && tiny != null) return tiny;
    return switch (windowClass) {
      KeroseneWindowClass.compact => compact,
      KeroseneWindowClass.medium => medium ?? regular,
      KeroseneWindowClass.expanded => expanded ?? regular,
      KeroseneWindowClass.wide => wide ?? expanded ?? regular,
    };
  }

  double clampWidth(double desiredWidth) {
    return math.max(
      0,
      math.min(desiredWidth, size.width - (horizontalPadding * 2)),
    );
  }

  static KeroseneWindowClass _classForWidth(double width) {
    if (width < 600) return KeroseneWindowClass.compact;
    if (width < 960) return KeroseneWindowClass.medium;
    if (width < 1280) return KeroseneWindowClass.expanded;
    return KeroseneWindowClass.wide;
  }

  static double _scaleForWidth(double width, double rawScale) {
    final maxScale = switch (width) {
      < 320 => 0.88,
      < 360 => 0.92,
      < 400 => 0.98,
      < 600 => 1.04,
      < 960 => 1.12,
      _ => 1.18,
    };
    return rawScale.clamp(0.82, maxScale).toDouble();
  }
}

class KeroseneResponsiveScope extends InheritedWidget {
  final KeroseneResponsiveMetrics metrics;

  const KeroseneResponsiveScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  static KeroseneResponsiveMetrics of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<KeroseneResponsiveScope>();
    if (scope != null) {
      return scope.metrics;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return const KeroseneResponsiveMetrics(
        size: Size(390, 844),
        viewPadding: EdgeInsets.zero,
        windowClass: KeroseneWindowClass.compact,
        systemTextScale: 1,
        effectiveTextScale: 1,
      );
    }

    return KeroseneResponsiveMetrics.fromMediaQuery(mediaQuery);
  }

  @override
  bool updateShouldNotify(KeroseneResponsiveScope oldWidget) {
    return metrics != oldWidget.metrics;
  }
}

class KeroseneResponsiveBoundary extends StatelessWidget {
  final Widget child;
  final double requestedTextScale;

  const KeroseneResponsiveBoundary({
    super.key,
    required this.child,
    this.requestedTextScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return child;
    }

    final metrics = KeroseneResponsiveMetrics.fromMediaQuery(
      mediaQuery,
      requestedTextScale: requestedTextScale,
    );

    return KeroseneResponsiveScope(
      metrics: metrics,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(metrics.effectiveTextScale),
        ),
        child: child,
      ),
    );
  }
}

extension KeroseneResponsiveContext on BuildContext {
  KeroseneResponsiveMetrics get responsive => KeroseneResponsiveScope.of(this);
}

/// Centers content and **forces** it to consume available width up to [maxWidth].
///
/// A bare [Center] + [ConstrainedBox] only sets a ceiling — children can still
/// shrink-wrap to phone width on desktop. This wrapper expands to the column.
class KeroseneAppColumn extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;

  const KeroseneAppColumn({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? context.responsive.appColumnMaxWidth;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
