import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_title_bar.dart';

enum ReceiveNetworkChoice { onchain, lightning }

class ReceiveNetworkOption {
  final ReceiveNetworkChoice choice;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String confirmationLabel;
  final bool bestValue;

  const ReceiveNetworkOption({
    required this.choice,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.confirmationLabel,
    this.bestValue = false,
  });
}

/// First-entry network picker for on-chain / cold receives.
class ReceiveNetworkPicker extends StatelessWidget {
  final List<ReceiveNetworkOption> options;
  final ValueChanged<ReceiveNetworkChoice> onSelected;
  final VoidCallback onBack;

  const ReceiveNetworkPicker({
    super.key,
    required this.options,
    required this.onSelected,
    required this.onBack,
  });

  static Color get _optionBg => SendFlowTheme.forVariant(
        ThemeTokenBridge.isLight ? Brightness.light : Brightness.dark,
      ).surfaceHigh;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ReceiveFlowScreenShell(
        onBack: onBack,
        title: ReceiveMoneyCopy.networkPickTitle(context),
        subtitle: ReceiveMoneyCopy.networkPickSubtitle(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiveFlowLayout.pageHorizontal - 4,
            0,
            ReceiveFlowLayout.pageHorizontal - 4,
            ReceiveFlowLayout.pageBottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: ReceiveFlowLayout.optionGap),
                          _NetworkOptionCard(
                            option: options[i],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelected(options[i].choice);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NetworkOptionCard extends StatelessWidget {
  final ReceiveNetworkOption option;
  final VoidCallback onTap;

  const _NetworkOptionCard({
    required this.option,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ReceiveNetworkPicker._optionBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: ReceiveNetworkPicker._optionBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: option.bestValue
                  ? SendFlowTheme.of(context).textPrimary
                  : Theme.of(context).dividerColor,
              width: option.bestValue ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (option.bestValue) ...[
                Text(
                  ReceiveMoneyCopy.networkBestValue(context),
                  style: AppTypography.captionLarge.copyWith(
                    color: SendFlowTheme.of(context).textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                option.title,
                style: AppTypography.h3.copyWith(
                  color: SendFlowTheme.of(context).textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.subtitle,
                style: AppTypography.captionLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    KeroseneIcons.pending,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      option.timeLabel,
                      style: AppTypography.captionLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    KeroseneIcons.success,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      option.confirmationLabel,
                      style: AppTypography.captionLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
