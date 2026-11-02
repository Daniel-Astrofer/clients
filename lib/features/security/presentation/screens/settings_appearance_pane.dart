import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

import 'settings_section_components.dart';

class SettingsAppearancePane extends ConsumerStatefulWidget {
  const SettingsAppearancePane({super.key});

  @override
  ConsumerState<SettingsAppearancePane> createState() =>
      _SettingsAppearancePaneState();
}

class _SettingsAppearancePaneState
    extends ConsumerState<SettingsAppearancePane> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _save(bool enabled) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(appearanceProvider.notifier).setDarkModeEnabled(enabled);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final tr = context.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(tr.settingsPreferenceSaveFailed,
                style: AppTypography.bodyMedium
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          ),
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
              onTap: _saving
                  ? null
                  : () => _save(
                        !appearance.darkModeEnabled,
                      ),
            ),
          ],
        ),
      ],
    );
  }
}
