import 'package:flutter/material.dart';

/// Admin color aliases for the web dashboard.
///
/// Kept as compile-time constants so existing `const` UI trees keep working.
/// Values mirror the dark Kerosene brand chrome (admin is dark-first).
class AdminColors {
  AdminColors._();

  static const Color background = Color(0xFF030405);
  static const Color backgroundElevated = Color(0xFF0A0D10);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF1D2328);
  static const Color surfaceHover = Color(0xFF181A17);

  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color border = Color(0xFF2F3131);
  static const Color borderStrong = Color(0xFF3A3A3A);

  static const Color textPrimary = Color(0xFFF7F7F1);
  static const Color textSecondary = Color(0xFFB8B8BC);
  static const Color textTertiary = Color(0xFF7D838A);
  static const Color textDisabled = Color(0xFF555550);

  static const Color accent = Color(0xFFD6A84F);
  static const Color info = Color(0xFF60A5FA);
  static const Color positive = Color(0xFF3EDB9B);
  static const Color warning = Color(0xFFFFC46B);
  static const Color negative = Color(0xFFFF5A67);

  static const Color positiveSubtle = positive;
  static const Color warningSubtle = warning;
  static const Color negativeSubtle = negative;
  static const Color infoSubtle = info;
  static const Color accentSubtle = accent;

  static const Color sidebarBg = backgroundElevated;
  static const Color sidebarHover = surface;
  static const Color sidebarActive = surfaceHover;
  static const Color sidebarText = textSecondary;
  static const Color sidebarTextActive = textPrimary;

  static const Color tableHeader = surface;
  static const Color tableRowHover = surfaceHover;
  static const Color tableRowAlt = backgroundElevated;

  static const Color chartLine = accent;
  static const Color chartArea = accent;
  static const Color chartGrid = borderSubtle;

  static Color withAlpha(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
