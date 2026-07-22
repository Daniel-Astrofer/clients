import 'package:kerosene/core/providers/appearance_provider.dart';

/// Bridges [AppThemeVariant] into static token getters for call sites that
/// cannot take a [BuildContext] (legacy const aliases, helpers).
///
/// Dark values stay the default; light only activates after [bind].
class ThemeTokenBridge {
  ThemeTokenBridge._();

  static AppThemeVariant _variant = AppThemeVariant.dark;

  static AppThemeVariant get variant => _variant;

  static bool get isLight => _variant == AppThemeVariant.light;

  static void bind(AppThemeVariant variant) {
    _variant = variant;
  }
}
