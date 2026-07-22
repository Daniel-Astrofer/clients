import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

import 'settings_modern_components.dart';

enum SettingsPane {
  account,
  security,
  notifications,
  appearance,
  display,
  wallets
}

class SettingsHeader extends StatelessWidget {
  final VoidCallback onClose;

  const SettingsHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SettingsIconButtonFrame(
            icon: KeroseneIcons.back,
            semanticLabel: context.tr.settingsNavBack,
            onTap: onClose,
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class SettingsHero extends StatelessWidget {
  const SettingsHero({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.settingsNavTitle,
          style: AppTypography.newsreader(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 40,
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          tr.settingsNavDescription,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class SettingsNavigationRail extends StatelessWidget {
  final SettingsPane? selected;
  final ValueChanged<SettingsPane> onSelected;

  const SettingsNavigationRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final items = <SettingsPaneSpec>[
      SettingsPaneSpec(
        pane: SettingsPane.account,
        icon: KeroseneIcons.userCheck,
        animation: KeroseneAnimationAsset.secureConnection,
        title: tr.settingsNavProfileTitle,
        subtitle: tr.settingsNavProfileSubtitle,
      ),
      SettingsPaneSpec(
        pane: SettingsPane.security,
        icon: KeroseneIcons.security,
        animation: KeroseneAnimationAsset.securityShield,
        title: tr.settingsNavSecurityTitle,
        subtitle: tr.settingsNavSecuritySubtitle,
      ),
      SettingsPaneSpec(
        pane: SettingsPane.notifications,
        icon: KeroseneIcons.notifications,
        animation: KeroseneAnimationAsset.transactionStatus,
        title: tr.settingsNavNotificationsTitle,
        subtitle: tr.settingsNavNotificationsSubtitle,
      ),
      SettingsPaneSpec(
        pane: SettingsPane.appearance,
        icon: KeroseneIcons.contrast,
        animation: KeroseneAnimationAsset.networkReview,
        title: tr.settingsNavAppearanceTitle,
        subtitle: tr.settingsNavAppearanceSubtitle,
      ),
      SettingsPaneSpec(
        pane: SettingsPane.display,
        icon: KeroseneIcons.language,
        animation: KeroseneAnimationAsset.networkReview,
        title: tr.settingsNavDisplayTitle,
        subtitle: tr.settingsNavDisplaySubtitle,
      ),
      SettingsPaneSpec(
        pane: SettingsPane.wallets,
        icon: KeroseneIcons.wallet,
        animation: KeroseneAnimationAsset.emptyWallet,
        title: tr.settingsNavWalletsTitle,
        subtitle: tr.settingsNavWalletsSubtitle,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.settingsNavPreferencesSection.toUpperCase(),
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in items)
          SettingsNavigationTile(
            spec: item,
            selected: item.pane == selected,
            onTap: () => onSelected(item.pane),
          ),
      ],
    );
  }
}

class SettingsPaneSpec {
  final SettingsPane pane;
  final IconData icon;
  final KeroseneAnimationAsset animation;
  final String title;
  final String subtitle;

  const SettingsPaneSpec({
    required this.pane,
    required this.icon,
    required this.animation,
    required this.title,
    required this.subtitle,
  });
}

class SettingsNavigationTile extends StatelessWidget {
  final SettingsPaneSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const SettingsNavigationTile({
    super.key,
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: KeroseneMotion.short,
            curve: KeroseneMotion.standard,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.hexFF2C2C2E : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.hexFF1C1C1E
                        : Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(
                    spec.icon,
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 21,
                  ),
                ),
                SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        spec.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  KeroseneIcons.chevronRight,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                    alpha: selected ? 1.0 : 0.45,
                  ),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
