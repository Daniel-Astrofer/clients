/// Kerosene — Spacing System (4pt Grid)
/// All margins, paddings, and precise spacings should rely on these constants.
class AppSpacing {
  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl2 = 24.0;
  static const double xl = 28.0;

  /// Module grouping (send-flow / financial surfaces).
  static const double module = 32.0;
  static const double xxl = 40.0;

  /// Section rhythm.
  static const double section = 48.0;
  static const double xxxl = 56.0;

  /// Extra wide spacing (Linear scale)
  static const double extraWide = 80.0;

  /// Minimum touch target (Material / thumb ergonomics).
  static const double minTouch = 48.0;

  // --- Linear-style semantic spacing aliases ---
  static const double spacing4 = xs;
  static const double spacing8 = sm;
  static const double spacing12 = md;
  static const double spacing16 = base;
  static const double spacing20 = lg;
  static const double spacing24 = xl2;
  static const double spacing32 = module;
  static const double spacing48 = section;
  static const double spacing56 = xxxl;
  static const double spacing80 = extraWide;
}
