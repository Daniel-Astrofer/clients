import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
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
    final tr = context.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.settingsDisplayTitle,
          style: AppTypography.newsreader(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          tr.settingsDisplaySubtitle,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsDisplayLanguageSection,
          children: [
            for (final locale in AppLocalizationManager.supportedLocales)
              _DisplayOptionRow(
                icon: KeroseneIcons.language,
                title: _languageName(tr, locale),
                subtitle: _languageSubtitle(tr, locale),
                selected:
                    preferences.locale.languageCode == locale.languageCode,
                onTap: () => notifier.setLocale(locale),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsDisplayCurrencySection,
          children: [
            for (final currency in Currency.values)
              _DisplayOptionRow(
                icon: currency == Currency.btc
                    ? KeroseneIcons.bitcoin
                    : KeroseneIcons.fiat,
                title:
                    '${MoneyDisplay.tickerSymbolFor(currency)} ${currency.code}',
                subtitle: _currencySubtitle(tr, currency),
                selected: preferences.currency == currency,
                onTap: () => notifier.setCurrency(currency),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsDisplayTimezoneSection,
          children: [
            _DisplayOptionRow(
              icon: KeroseneIcons.globe,
              title: tr.settingsDisplayFollowDeviceTimezone,
              subtitle: AppTimezone.displayLabel(AppTimezone.detectId()),
              selected: preferences.timeZoneFollowDevice,
              onTap: () => notifier.setTimeZoneFollowDevice(true),
            ),
            _DisplayOptionRow(
              icon: KeroseneIcons.schedule,
              title: tr.settingsDisplayPinnedTimezone,
              subtitle: AppTimezone.displayLabel(preferences.timeZoneId),
              selected: !preferences.timeZoneFollowDevice,
              onTap: () => _pickTimezone(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  static String _languageName(AppLocalizations tr, Locale locale) {
    return switch (locale.languageCode) {
      'pt' => tr.settingsDisplayLanguagePt,
      'es' => tr.settingsDisplayLanguageEs,
      _ => tr.settingsDisplayLanguageEn,
    };
  }

  static String _languageSubtitle(AppLocalizations tr, Locale locale) {
    return switch (locale.languageCode) {
      'pt' => tr.settingsDisplayLanguagePtSubtitle,
      'es' => tr.settingsDisplayLanguageEsSubtitle,
      _ => tr.settingsDisplayLanguageEnSubtitle,
    };
  }

  static String _currencySubtitle(AppLocalizations tr, Currency currency) {
    return switch (currency) {
      Currency.btc => tr.settingsDisplayCurrencyBtcSubtitle,
      Currency.usd => tr.settingsDisplayCurrencyUsdSubtitle,
      Currency.eur => tr.settingsDisplayCurrencyEurSubtitle,
      Currency.brl => tr.settingsDisplayCurrencyBrlSubtitle,
    };
  }

  Future<void> _pickTimezone(BuildContext context, WidgetRef ref) async {
    final tr = context.tr;
    final current = ref.read(appDisplayPreferencesProvider).timeZoneId;
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: maxH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    tr.settingsDisplayPickTimezone,
                    style: AppTypography.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: AppTimezone.curatedZones.length,
                    itemBuilder: (context, index) {
                      final zone = AppTimezone.curatedZones[index];
                      final isSelected = zone == current ||
                          (current.startsWith('UTC') && zone == 'UTC');
                      return ListTile(
                        title: Text(
                          AppTimezone.shortLabel(zone),
                          style: AppTypography.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          zone,
                          style: AppTypography.inter(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                KeroseneIcons.check,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(ctx).pop(zone),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    HapticFeedback.selectionClick();
    await ref
        .read(appDisplayPreferencesProvider.notifier)
        .setTimeZoneId(selected);
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
