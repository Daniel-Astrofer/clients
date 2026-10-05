import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

import 'settings_section_components.dart';

class SettingsAppearancePane extends ConsumerWidget {
  const SettingsAppearancePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final tr = context.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.settingsAppearanceTitle,
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
          tr.settingsAppearanceSubtitle,
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
          title: tr.settingsAppearanceThemeSection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.contrast,
              title: tr.settingsAppearanceDarkModeTitle,
              subtitle: appearance.darkModeEnabled
                  ? tr.settingsAppearanceDarkModeOn
                  : tr.settingsAppearanceDarkModeOff,
              trailing: SettingsReadonlySwitch(
                value: appearance.darkModeEnabled,
              ),
              onTap: () => notifier.setDarkModeEnabled(
                !appearance.darkModeEnabled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
