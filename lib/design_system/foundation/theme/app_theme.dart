import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Shared geometry: compact elements 8, controls 16, surfaces 20.
/// Pill geometry is reserved for chips and segmented navigation.
class AppRadius {
  static final BorderRadius small = BorderRadius.circular(8);
  static final BorderRadius medium = BorderRadius.circular(16);
  static final BorderRadius large = BorderRadius.circular(20);

  /// Text fields / compact controls.
  static final BorderRadius input = BorderRadius.circular(16);

  /// Information cards / panels.
  static final BorderRadius card = BorderRadius.circular(20);

  /// Primary CTAs (pill).
  static final BorderRadius pill = BorderRadius.circular(9999);
}

/// Kerosene — Shadows (Linear: no drop shadows — use 1px borders instead)
class AppShadows {
  /// No shadow — use `1px` border for separation.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Linear-style inner stroke pattern for elevated states.
  static final List<BoxShadow> subtle = [
    const BoxShadow(
      color: AppColors.ferriteBorder,
      offset: Offset(0, 0),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> neonGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 2,
      offset: const Offset(0, 0),
    ),
  ];
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  final Color background;
  final Color backgroundTop;
  final Color backgroundMid;
  final Color backgroundBottom;
  final Color surface;
  final Color border;
  final Color inputFill;

  const AppThemePalette({
    required this.background,
    required this.backgroundTop,
    required this.backgroundMid,
    required this.backgroundBottom,
    required this.surface,
    required this.border,
    required this.inputFill,
  });

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, backgroundMid, backgroundBottom],
      );

  @override
  ThemeExtension<AppThemePalette> copyWith({
    Color? background,
    Color? backgroundTop,
    Color? backgroundMid,
    Color? backgroundBottom,
    Color? surface,
    Color? border,
    Color? inputFill,
  }) {
    return AppThemePalette(
      background: background ?? this.background,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundMid: backgroundMid ?? this.backgroundMid,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  ThemeExtension<AppThemePalette> lerp(
    covariant ThemeExtension<AppThemePalette>? other,
    double t,
  ) {
    if (other is! AppThemePalette) {
      return this;
    }
    return AppThemePalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundMid: Color.lerp(backgroundMid, other.backgroundMid, t)!,
      backgroundBottom:
          Color.lerp(backgroundBottom, other.backgroundBottom, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

class AppTheme {
  static AppThemePalette paletteFor(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.dark:
        return const AppThemePalette(
          background: AppColors.onyxCanvas,
          backgroundTop: AppColors.onyxCanvas,
          backgroundMid: AppColors.onyxCanvas,
          backgroundBottom: AppColors.voidColor,
          surface: AppColors.carbonSurface,
          border: AppColors.smokeSurface,
          inputFill: AppColors.carbonSurface,
        );
      case AppThemeVariant.light:
        return const AppThemePalette(
          background: Color(0xFFF7F7F5),
          backgroundTop: Color(0xFFFFFFFF),
          backgroundMid: Color(0xFFF7F7F5),
          backgroundBottom: Color(0xFFEDEDEA),
          surface: Color(0xFFFFFFFF),
          border: Color(0xFFD9DAD6),
          inputFill: Color(0xFFF0F1EE),
        );
    }
  }

  static ThemeData themeFor(AppThemeVariant variant) {
    ThemeTokenBridge.bind(variant);
    final palette = paletteFor(variant);
    final isLight = variant == AppThemeVariant.light;
    final brightness = isLight ? Brightness.light : Brightness.dark;
    final onSurface = isLight ? const Color(0xFF181A17) : AppColors.snow;
    final onSurfaceVariant =
        isLight ? const Color(0xFF62675F) : AppColors.fogText;
    final hintColor = isLight ? const Color(0xFF8B9087) : AppColors.pewterText;
    final labelColor = isLight ? const Color(0xFF5F645B) : AppColors.fogText;
    final baseTextTheme =
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme;

    // Outlined pill: 1px border, no fill — Linear's primary action style.
    final pillOutlinedBorder = RoundedRectangleBorder(
      borderRadius: AppRadius.pill,
      side: BorderSide(color: onSurface, width: 1),
    );

    final colorScheme = isLight
        ? ColorScheme.light(
            primary: AppColors.black,
            secondary: AppColors.secondary,
            surface: palette.surface,
            surfaceContainerHighest: palette.inputFill,
            error: AppColors.error,
            onPrimary: AppColors.white,
            onSecondary: AppColors.white,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            onError: AppColors.white,
            secondaryContainer: AppColors.secondary.withValues(alpha: 0.12),
            onSecondaryContainer: onSurface,
          )
        : ColorScheme.dark(
            primary: AppColors.snow,
            secondary: AppColors.secondary,
            surface: palette.surface,
            surfaceContainerHighest: palette.inputFill,
            error: AppColors.error,
            onPrimary: AppColors.onyxCanvas,
            onSecondary: AppColors.white,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            onError: AppColors.white,
            secondaryContainer: AppColors.secondary.withValues(alpha: 0.2),
            onSecondaryContainer: AppColors.snow,
          );

    final disabledTextColor =
        onSurface.withValues(alpha: isLight ? 0.38 : 0.40);

    // Match status bar icons to scaffold brightness without touching dark look.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.border,
      extensions: [
        palette,
        isLight ? MonochromeColors.light : MonochromeColors.dark,
        isLight ? KeroseneBrandTheme.light : KeroseneBrandTheme.dark,
        isLight ? HomeSurfaceTheme.light : HomeSurfaceTheme.dark,
        isLight ? SendFlowTheme.light() : SendFlowTheme.dark(),
      ],
      fontFamily: AppTypography.fontFamily,
      useMaterial3: true,
      colorScheme: colorScheme,
      disabledColor: disabledTextColor,
      pageTransitionsTheme: kerosenePageTransitionsTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: onSurface,
        selectionColor: onSurface.withValues(alpha: 0.18),
        selectionHandleColor: onSurface,
      ),
      // Linear-style text theme: Plus Jakarta Sans for body/UI,
      // Playfair Display for display/hero.
      textTheme: AppTypography.plusJakartaSansTextTheme(baseTextTheme).copyWith(
        displayLarge: AppTypography.displayLarge.copyWith(color: onSurface),
        displayMedium: AppTypography.display.copyWith(color: onSurface),
        displaySmall: AppTypography.h2.copyWith(color: onSurface),
        headlineLarge: AppTypography.display.copyWith(color: onSurface),
        headlineMedium: AppTypography.h2.copyWith(color: onSurface),
        headlineSmall: AppTypography.h3.copyWith(color: onSurface),
        titleLarge: AppTypography.h2.copyWith(color: onSurface),
        titleMedium: AppTypography.h3.copyWith(color: onSurface),
        titleSmall: AppTypography.descriptionStrong.copyWith(color: onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
        bodySmall: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
        labelLarge: AppTypography.buttonText.copyWith(color: onSurface),
        labelMedium:
            AppTypography.captionLarge.copyWith(color: onSurfaceVariant),
        labelSmall: AppTypography.caption.copyWith(color: onSurfaceVariant),
      ),
      // ─── Input / Text Field (Linear: 4px radius, 1px border) ───────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(color: onSurface, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: hintColor),
        labelStyle: AppTypography.bodyMedium.copyWith(color: labelColor),
        floatingLabelStyle: AppTypography.bodyMedium.copyWith(
          color: onSurface,
          fontWeight: AppTypography.w510,
        ),
        errorStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.error,
          fontWeight: AppTypography.w590,
        ),
        prefixIconColor: labelColor,
        suffixIconColor: labelColor,
      ),
      // ─── Elevated Button ──────────────────────────────────────────
      // Linear-style: outlined pill, 1px snow border.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: onSurface,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: disabledTextColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: pillOutlinedBorder,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.base,
          ),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: AppTypography.w510,
          ),
          side: BorderSide(color: onSurface, width: 1),
        ),
      ),
      // ─── Filled Button ────────────────────────────────────────────
      // Primary CTA: outlined pill (Linear style) — transparent bg,
      // 1px snow border. No filled background.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: onSurface,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: disabledTextColor,
          minimumSize: const Size.fromHeight(AppSpacing.minTouch),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.base,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: pillOutlinedBorder,
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: AppTypography.w510,
          ),
          side: BorderSide(color: onSurface, width: 1),
        ),
      ),
      // ─── Outlined Button ──────────────────────────────────────────
      // Secondary outlined action.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: onSurface,
          disabledForegroundColor: disabledTextColor,
          side: BorderSide(
            color: onSurface.withValues(alpha: isLight ? 0.22 : 0.32),
            width: 1,
          ),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.base,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: AppTypography.w510,
          ),
        ),
      ),
      // ─── Text Button (Ghost: no border, no bg, muted text) ────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurfaceVariant,
          disabledForegroundColor: disabledTextColor,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm,
          ),
          textStyle: AppTypography.buttonText.copyWith(
            fontWeight: AppTypography.w510,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          disabledForegroundColor: disabledTextColor,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h2,
        iconTheme: IconThemeData(color: onSurface),
      ),
      // ─── Card (Linear: 8px radius, 1px hairline border, no shadow) ─
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        modalBarrierColor:
            Colors.black.withValues(alpha: isLight ? 0.30 : 0.74),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadius.card.topLeft),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: onSurface,
          fontWeight: AppTypography.w510,
        ),
        actionTextColor: onSurface,
        disabledActionTextColor: disabledTextColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pill,
          side: BorderSide(color: palette.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: palette.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
        labelStyle: AppTypography.caption.copyWith(color: onSurfaceVariant),
      ),
    );
  }

  static ThemeData get darkTheme => themeFor(AppThemeVariant.dark);

  // ─── Gradients ─────────────────────────────────
  // Preserving from existing theme.
  static const LinearGradient metallicGradient = LinearGradient(
    colors: [Color(0xFF0F1018), Color(0xFF050508)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
