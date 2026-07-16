import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

import 'settings_formatters.dart';
import 'settings_section_components.dart';

class SettingsAccountPane extends ConsumerWidget {
  const SettingsAccountPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.tr;
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.settingsAccountTitle,
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
          tr.settingsAccountSubtitle,
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
          title: tr.settingsAccountIdentitySection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.userCheck,
              title: tr.settingsAccountUsernameTitle,
              subtitle: settingsFormatHandle(user?.username ?? ''),
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        SettingsSection(
          title: tr.settingsAccountSessionSection,
          children: [
            SettingsSectionRow(
              icon: KeroseneIcons.history,
              title: tr.settingsAccountCreatedAtTitle,
              subtitle: settingsDateLabel(user?.createdAt),
              onTap: null,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.device,
              title: tr.settingsAccountLastAccessTitle,
              subtitle: settingsDateLabel(user?.lastLogin),
              onTap: null,
            ),
            SettingsSectionRow(
              icon: KeroseneIcons.logout,
              title: tr.settingsAccountLogoutTitle,
              subtitle: tr.settingsAccountLogoutSubtitle,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/welcome', (_) => false);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
