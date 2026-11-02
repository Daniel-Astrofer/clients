import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/components/generic/kerosene_screen_background.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'settings_notifications_pane.dart';

/// Standalone entry shares permissions and persistence feedback with settings.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeroseneScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const KeroseneIcon(KeroseneIcons.back),
                  ),
                ),
              ),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SettingsNotificationsPane(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
