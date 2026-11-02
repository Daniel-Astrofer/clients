import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_preferences_provider.dart';

// ─── Theme Mode ───────────────────────────────────────
enum AppThemeVariant { dark, light }

extension AppThemeVariantX on AppThemeVariant {
  String get label {
    switch (this) {
      case AppThemeVariant.dark:
        return 'Modo escuro';
      case AppThemeVariant.light:
        return 'Modo claro';
    }
  }

  String get description {
    switch (this) {
      case AppThemeVariant.dark:
        return 'Interface escura ativada.';
      case AppThemeVariant.light:
        return 'Interface escura desativada.';
    }
  }
}

// ─── State ────────────────────────────────────────────
class AppearanceState {
  final AppThemeVariant themeVariant;

  const AppearanceState({
    this.themeVariant = AppThemeVariant.dark,
  });

  bool get darkModeEnabled => themeVariant == AppThemeVariant.dark;

  AppearanceState copyWith({
    AppThemeVariant? themeVariant,
  }) {
    return AppearanceState(
      themeVariant: themeVariant ?? this.themeVariant,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────
class AppearanceNotifier extends Notifier<AppearanceState> {
  static const _darkModeKey = 'appearance_dark_mode_enabled';

  @override
  AppearanceState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final darkModeEnabled = prefs.getBool(_darkModeKey) ?? true;

    return AppearanceState(
      themeVariant:
          darkModeEnabled ? AppThemeVariant.dark : AppThemeVariant.light,
    );
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    final variant = enabled ? AppThemeVariant.dark : AppThemeVariant.light;
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      if (!await prefs.setBool(_darkModeKey, enabled)) {
        throw StateError('Appearance preference was not saved.');
      }
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    state = state.copyWith(themeVariant: variant);
  }

  Future<void> setThemeVariant(AppThemeVariant variant) async {
    await setDarkModeEnabled(variant == AppThemeVariant.dark);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
  AppearanceNotifier.new,
);
