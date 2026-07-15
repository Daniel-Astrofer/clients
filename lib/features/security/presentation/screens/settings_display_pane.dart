import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/localization/app_localization_manager.dart';
import 'package:kerosene/core/localization/app_timezone.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

import 'settings_section_components.dart';

class SettingsDisplayPane extends ConsumerWidget {
  const SettingsDisplayPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appDisplayPreferencesProvider);
    final notifier = ref.read(appDisplayPreferencesProvider.notifier);
    final lang = preferences.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title(lang),
          style: AppTypography.newsreader(
            color: KeroseneBrandTokens.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _subtitle(lang),
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: _sectionLanguage(lang),
          children: [
            for (final locale in AppLocalizationManager.supportedLocales)
              _DisplayOptionRow(
                icon: KeroseneIcons.language,
                title: _languageName(locale),
                subtitle: _languageSubtitle(locale),
                selected:
                    preferences.locale.languageCode == locale.languageCode,
                onTap: () => notifier.setLocale(locale),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: _sectionCurrency(lang),
          children: [
            for (final currency in Currency.values)
              _DisplayOptionRow(
                icon: currency == Currency.btc
                    ? KeroseneIcons.bitcoin
                    : KeroseneIcons.fiat,
                title:
                    '${MoneyDisplay.tickerSymbolFor(currency)} ${currency.code}',
                subtitle: _currencySubtitle(currency, lang),
                selected: preferences.currency == currency,
                onTap: () => notifier.setCurrency(currency),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: _sectionTimezone(lang),
          children: [
            _DisplayOptionRow(
              icon: KeroseneIcons.globe,
              title: _followDeviceTitle(lang),
              subtitle: AppTimezone.displayLabel(AppTimezone.detectId()),
              selected: preferences.timeZoneFollowDevice,
              onTap: () => notifier.setTimeZoneFollowDevice(true),
            ),
            _DisplayOptionRow(
              icon: KeroseneIcons.schedule,
              title: _currentTimezoneTitle(lang),
              subtitle: AppTimezone.displayLabel(preferences.timeZoneId),
              selected: !preferences.timeZoneFollowDevice,
              onTap: () => notifier.setTimeZoneId(preferences.timeZoneId),
            ),
          ],
        ),
      ],
    );
  }

  static String _title(String lang) => switch (lang) {
        'pt' => 'Idioma, moeda e fuso',
        'es' => 'Idioma, moneda y zona',
        _ => 'Language, currency & time',
      };

  static String _subtitle(String lang) => switch (lang) {
        'pt' =>
          'Preferências globais do app. Idioma e fuso vão ao backend para notícias e educação. O extrato local é criptografado — o servidor só guarda ~24h de histórico.',
        'es' =>
          'Preferencias globales. Idioma y zona se envían al backend para noticias y educación. El extracto local está cifrado — el servidor solo guarda ~24h de historial.',
        _ =>
          'Global app preferences. Language and timezone are sent to the backend for news and education. Local statement is encrypted — the server only keeps ~24h of history.',
      };

  static String _sectionLanguage(String lang) => switch (lang) {
        'pt' => 'Idioma',
        'es' => 'Idioma',
        _ => 'Language',
      };

  static String _sectionCurrency(String lang) => switch (lang) {
        'pt' => 'Moeda principal',
        'es' => 'Moneda principal',
        _ => 'Primary currency',
      };

  static String _sectionTimezone(String lang) => switch (lang) {
        'pt' => 'Fuso horário',
        'es' => 'Zona horaria',
        _ => 'Time zone',
      };

  static String _followDeviceTitle(String lang) => switch (lang) {
        'pt' => 'Seguir fuso do aparelho',
        'es' => 'Seguir zona del dispositivo',
        _ => 'Follow device time zone',
      };

  static String _currentTimezoneTitle(String lang) => switch (lang) {
        'pt' => 'Fuso usado no app',
        'es' => 'Zona usada en la app',
        _ => 'Time zone used in app',
      };

  static String _languageName(Locale locale) {
    return switch (locale.languageCode) {
      'pt' => 'Português',
      'es' => 'Español',
      _ => 'English',
    };
  }

  static String _languageSubtitle(Locale locale) {
    return switch (locale.languageCode) {
      'pt' => 'Interface e feed em português',
      'es' => 'Interfaz y feed en español',
      _ => 'Interface and feed in English',
    };
  }

  static String _currencySubtitle(Currency currency, String lang) {
    return switch (currency) {
      Currency.btc => switch (lang) {
          'pt' => 'Exibe valores diretamente em Bitcoin',
          'es' => 'Muestra valores directamente en Bitcoin',
          _ => 'Show amounts directly in Bitcoin',
        },
      Currency.usd => switch (lang) {
          'pt' => 'Dólar americano como moeda de leitura',
          'es' => 'Dólar estadounidense como moneda de lectura',
          _ => 'US dollar as display currency',
        },
      Currency.eur => switch (lang) {
          'pt' => 'Euro como moeda de leitura',
          'es' => 'Euro como moneda de lectura',
          _ => 'Euro as display currency',
        },
      Currency.brl => switch (lang) {
          'pt' => 'Real brasileiro como moeda de leitura',
          'es' => 'Real brasileño como moneda de lectura',
          _ => 'Brazilian real as display currency',
        },
    };
  }
}

class _DisplayOptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DisplayOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionRow(
      icon: selected ? KeroseneIcons.check : icon,
      title: title,
      subtitle: subtitle,
      trailing: SettingsReadonlySwitch(value: selected),
      onTap: onTap,
    );
  }
}
