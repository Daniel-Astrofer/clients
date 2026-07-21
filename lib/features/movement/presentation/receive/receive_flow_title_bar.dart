import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';

/// Back affordance inline to the left of a Newsreader H1 — receive flow chrome.
class ReceiveFlowTitleBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final bool compact;
  final bool alignLeft;

  const ReceiveFlowTitleBar({
    super.key,
    this.onBack,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.compact = false,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseH1 = AppTypography.h1.copyWith(
      color: KeroseneBrandTokens.textPrimary,
    );
    final baseDescription = AppTypography.description.copyWith(
      color: KeroseneBrandTokens.textSecondary,
    );
    final titleScale = compact ? ReceiveFlowLayout.walletPickerTitleScale : 1.0;
    final bodyScale = compact ? ReceiveFlowLayout.walletPickerBodyScale : 1.0;
    final resolvedTitle = (titleStyle ?? baseH1).copyWith(
      fontSize: (titleStyle?.fontSize ?? baseH1.fontSize ?? 40) * titleScale,
      height: titleStyle?.height ?? baseH1.height,
    );
    final resolvedSubtitle = (subtitleStyle ?? baseDescription).copyWith(
      fontSize:
          (subtitleStyle?.fontSize ?? baseDescription.fontSize ?? 14) * bodyScale,
    );

    final horizontalPad = alignLeft || compact ? 20.0 : 8.0;
    final backWidth = onBack != null ? 48.0 : (alignLeft || compact ? 0.0 : 48.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: const Icon(KeroseneIcons.back, size: 22),
                  style: IconButton.styleFrom(
                    foregroundColor: KeroseneBrandTokens.textPrimary,
                    minimumSize: const Size.square(48),
                    padding: EdgeInsets.zero,
                  ),
                )
              else if (!alignLeft && !compact)
                const SizedBox(width: 48, height: 48),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: ReceiveFlowLayout.titleTextTopPadding,
                    left: backWidth == 0 ? 0 : 0,
                  ),
                  child: Text(
                    title,
                    style: resolvedTitle,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(left: onBack != null ? 56 : 0),
              child: Text(
                subtitle!,
                style: resolvedSubtitle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen receive step: body fills the viewport; H1 floats at a fixed
/// height without pushing content below.
class ReceiveFlowScreenShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;

  const ReceiveFlowScreenShell({
    super.key,
    required this.child,
    this.onBack,
    required this.title,
    this.subtitle,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: ReceiveFlowLayout.titleOverlayTop(context),
          left: 0,
          right: 0,
          child: ReceiveFlowTitleBar(
            onBack: onBack,
            title: title,
            subtitle: subtitle,
            titleStyle: titleStyle,
          ),
        ),
      ],
    );
  }
}

/// Thin top edge on receive bottom sheets.
class ReceiveFlowSheetTopBorder extends StatelessWidget {
  const ReceiveFlowSheetTopBorder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ReceiveFlowLayout.sheetTopBorderHeight,
      color: ReceiveFlowLayout.sheetTopBorderColor,
    );
  }
}
