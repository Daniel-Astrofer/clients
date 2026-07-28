import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'admin_colors.dart';

/// Kerosene Enterprise — Material Theme Data
/// Square corners, monochrome palette, institutional look.
/// Extends [AppTheme] tokens where possible.
class AdminTheme {
  AdminTheme._();

  // ─── Spacing Tokens (delegates to AppSpacing) ─────
  static const double spacingXs = AppSpacing.spacing4;
  static const double spacingSm = AppSpacing.spacing8;
  static const double spacingMd = AppSpacing.spacing12;
  static const double spacingLg = AppSpacing.spacing16;
  static const double spacingXl = AppSpacing.spacing24;
  static const double spacingXxl = AppSpacing.spacing32;
  static const double spacing3xl = AppSpacing.spacing48;

  // ─── Border Radius (admin uses 4px, 6px) ──────────
  static const double radiusNone = 0;
  static const double radiusXs = 2;
  static const double radiusSm = 4;
  static const double radiusMd = 6;

  static BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);

  // ─── Sidebar ────────────────────────────────────
  static const double sidebarWidth = 240;
  static const double sidebarCollapsedWidth = 64;

  // ─── Top Bar ────────────────────────────────────
  static const double topBarHeight = 56;

  // ─── ThemeData ──────────────────────────────────
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AdminColors.background,
      canvasColor: AdminColors.background,
      dividerColor: AdminColors.border,
      fontFamily: AppTypography.bodyFontFamily,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.textPrimary,
        secondary: AdminColors.info,
        surface: AdminColors.surface,
        surfaceContainerHighest: AdminColors.backgroundElevated,
        error: AdminColors.negative,
        onPrimary: AdminColors.background,
        onSurface: AdminColors.textPrimary,
        onSurfaceVariant: AdminColors.textSecondary,
        onError: AdminColors.textPrimary,
      ),
      disabledColor: AdminColors.textDisabled,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AdminColors.textPrimary,
        selectionColor: AdminColors.textPrimary.withValues(alpha: 0.18),
        selectionHandleColor: AdminColors.textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.playfairDisplay(
          fontSize: 48,
          color: AdminColors.textPrimary,
          height: 1.1,
        ),
        headlineLarge: AppTypography.playfairDisplay(
          fontSize: 28,
          color: AdminColors.textPrimary,
          height: 1.2,
        ),
        headlineMedium: AppTypography.playfairDisplay(
          fontSize: 22,
          color: AdminColors.textPrimary,
          height: 1.25,
        ),
        headlineSmall: AppTypography.playfairDisplay(
          fontSize: 18,
          color: AdminColors.textPrimary,
          height: 1.3,
        ),
        titleLarge: AppTypography.playfairDisplay(
          fontSize: 18,
          color: AdminColors.textPrimary,
          height: 1.3,
        ),
        titleMedium: AppTypography.playfairDisplay(
          fontSize: 15,
          color: AdminColors.textPrimary,
          height: 1.35,
        ),
        bodyLarge: AppTypography.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AdminColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AdminColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: AppTypography.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AdminColors.textTertiary,
          height: 1.4,
        ),
        labelLarge: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AdminColors.textPrimary,
        ),
        labelMedium: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AdminColors.textTertiary,
          height: 1.3,
        ),
        labelSmall: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AdminColors.textTertiary,
          height: 1.3,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AdminColors.borderStrong),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.backgroundElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadiusSm,
          borderSide: const BorderSide(color: AdminColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusSm,
          borderSide: const BorderSide(color: AdminColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusSm,
          borderSide: const BorderSide(
            color: AdminColors.textPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadiusSm,
          borderSide: const BorderSide(color: AdminColors.negative, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadiusSm,
          borderSide: const BorderSide(color: AdminColors.negative, width: 1.5),
        ),
        hintStyle: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AdminColors.textSecondary,
        ),
        labelStyle: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AdminColors.textSecondary,
        ),
        floatingLabelStyle: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AdminColors.textPrimary,
        ),
        prefixIconColor: AdminColors.textSecondary,
        suffixIconColor: AdminColors.textSecondary,
        errorStyle: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AdminColors.negative,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.textPrimary,
          foregroundColor: AdminColors.background,
          disabledBackgroundColor: AdminColors.surfaceElevated,
          disabledForegroundColor: AdminColors.textDisabled,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
          padding: const EdgeInsets.symmetric(
            vertical: spacingMd,
            horizontal: spacingXl,
          ),
          textStyle: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.textPrimary,
          foregroundColor: AdminColors.background,
          disabledBackgroundColor: AdminColors.surfaceElevated,
          disabledForegroundColor: AdminColors.textDisabled,
          minimumSize: const Size.fromHeight(40),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
          padding: const EdgeInsets.symmetric(
            vertical: spacingMd,
            horizontal: spacingXl,
          ),
          textStyle: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AdminColors.surface,
          foregroundColor: AdminColors.textPrimary,
          disabledForegroundColor: AdminColors.textDisabled,
          side: const BorderSide(color: AdminColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
          padding: const EdgeInsets.symmetric(
            vertical: spacingMd,
            horizontal: spacingXl,
          ),
          textStyle: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.textPrimary,
          disabledForegroundColor: AdminColors.textDisabled,
          shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
          padding: const EdgeInsets.symmetric(
            vertical: spacingSm,
            horizontal: spacingLg,
          ),
          textStyle: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AdminColors.textSecondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusSm,
          side: const BorderSide(color: AdminColors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AdminColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusSm,
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.surfaceElevated,
          borderRadius: borderRadiusSm,
          border: Border.all(color: AdminColors.border),
        ),
        textStyle: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AdminColors.textPrimary,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AdminColors.tableHeader),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AdminColors.tableRowHover;
          }
          return Colors.transparent;
        }),
        headingTextStyle: AppTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AdminColors.textTertiary,
          height: 1.3,
        ),
        dataTextStyle: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AdminColors.textPrimary,
          height: 1.4,
        ),
        dividerThickness: 1,
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: AdminColors.textSecondary,
        size: 20,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AdminColors.textPrimary,
          disabledForegroundColor: AdminColors.textDisabled,
        ),
      ),
    );
  }
}
