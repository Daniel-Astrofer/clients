import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/financial/send_flow_chrome.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/shared/widgets/bouncing_button_wrapper.dart';

/// The top navigation bar for the internal Send Money flow.
///
/// This widget provides a back button and a title specifically styled
/// for the internal transfer interface. It is completely isolated from state.
class InternalTopBar extends StatelessWidget {
  /// Callback triggered when the back button is pressed.
  final VoidCallback onBack;

  /// The main color for the text and icons.
  final Color textColor;

  const InternalTopBar({
    super.key,
    required this.onBack,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(KeroseneIcons.back, size: 22),
              tooltip: context.tr.authBackAction,
              style: IconButton.styleFrom(
                foregroundColor: textColor,
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Expanded(
              child: Text(
                SendMoneyCopy.sendTitle(context),
                textAlign: TextAlign.center,
                style: HomeTypography.heroTitle(
                  color: textColor,
                  fontSize: 24,
                ).copyWith(height: 1.2),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// A custom numeric keypad for the internal Send Money flow.
class InternalKeypad extends StatelessWidget {
  /// Callback triggered when a key is pressed.
  final ValueChanged<String> onKeyTap;

  /// The color for standard text keys.
  final Color textColor;

  /// The color for the outline/backspace key.
  final Color outlineColor;

  const InternalKeypad({
    super.key,
    required this.onKeyTap,
    required this.textColor,
    required this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
        Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
        Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
        Row(children: [_buildKey('.'), _buildKey('0'), _buildKey('←')]),
      ],
    );
  }

  Widget _buildKey(String keyStr) {
    final isBackspace = keyStr == '←';
    final display = keyStr == '.' ? ',' : keyStr;

    return Expanded(
      child: SizedBox(
        height: 56,
        child: TextButton(
          onPressed: () => onKeyTap(keyStr),
          style: TextButton.styleFrom(
            foregroundColor: isBackspace ? outlineColor : textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: HomeTypography.heroTitle(
              fontSize: 24,
            ),
          ),
          child: isBackspace
              ? const Icon(KeroseneIcons.backspace, size: 24)
              : Text(display),
        ),
      ),
    );
  }
}

/// The primary action button used in the internal transfer UI.
///
/// Thin wrapper over [SendFlowPrimaryCta] (design system). Prefer calling
/// [SendFlowPrimaryCta] directly in new code.
class InternalPrimaryButton extends StatelessWidget {
  /// The text label for the button.
  final String label;

  /// An optional icon to display alongside the text.
  final IconData? icon;

  /// Whether the button is enabled.
  final bool enabled;

  /// Callback when the button is tapped.
  final VoidCallback onTap;

  /// Whether the button is currently in a loading state.
  final bool isLoading;

  /// Kept for call-site compatibility; colors come from [SendFlowTheme].
  final Color backgroundColor;

  /// Kept for call-site compatibility; colors come from [SendFlowTheme].
  final Color foregroundColor;

  const InternalPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SendFlowPrimaryCta(
      label: label,
      icon: icon,
      enabled: enabled,
      isLoading: isLoading,
      onPressed: onTap,
    );
  }
}

/// A generic quick action button for the internal transfer screen.
///
/// It displays a circular icon button with a label underneath.
class InternalQuickAction extends StatelessWidget {
  /// Optional icon to display. If omitted, [iconWidget] must be provided.
  final IconData? icon;

  /// Optional widget to display instead of a standard icon.
  final Widget? iconWidget;

  /// The text label below the action button.
  final String label;

  /// The tooltip message when the user hovers or long-presses.
  final String tooltip;

  /// Callback when the action is tapped.
  final VoidCallback onTap;

  /// The outline and icon color.
  final Color textColor;

  /// The text color of the label underneath.
  final Color mutedTextColor;

  const InternalQuickAction({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.textColor,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BouncingButton(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: textColor),
            ),
            child: Tooltip(
              message: tooltip,
              child: Center(
                child: iconWidget ??
                    Icon(
                      icon,
                      size: 24,
                      color: textColor,
                    ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mutedTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}
