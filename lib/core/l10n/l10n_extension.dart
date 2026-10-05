import 'package:flutter/widgets.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  /// Retorna as strings baseadas no locale atual do context.
  AppLocalizations get l10n {
    final provided = AppLocalizations.of(this);
    if (provided != null) return provided;

    // Small isolated surfaces (storybook/tests/embedded overlays) can be
    // mounted below a MaterialApp without the app delegate. Keep those
    // surfaces renderable instead of crashing on a null localization.
    final locale = Localizations.maybeLocaleOf(this) ?? const Locale('pt');
    return lookupAppLocalizations(locale);
  }

  /// Alias curto usado nas telas refatoradas.
  AppLocalizations get tr => l10n;
}
