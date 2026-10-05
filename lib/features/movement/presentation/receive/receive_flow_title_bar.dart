import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
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
      color: Theme.of(context).colorScheme.onSurface,
    );
    final baseDescription = AppTypography.description.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final titleScale = compact ? ReceiveFlowLayout.walletPickerTitleScale : 1.0;
    final bodyScale = compact ? ReceiveFlowLayout.walletPickerBodyScale : 1.0;
    final resolvedTitle = (titleStyle ?? baseH1).copyWith(
      fontSize: (titleStyle?.fontSize ?? baseH1.fontSize ?? 40) * titleScale,
      height: titleStyle?.height ?? baseH1.height,
    );
    final resolvedSubtitle = (subtitleStyle ?? baseDescription).copyWith(
      fontSize: (subtitleStyle?.fontSize ?? baseDescription.fontSize ?? 14) *
          bodyScale,
    );

    final horizontalPad =
        alignLeft || compact ? ReceiveFlowLayout.pageHorizontal - 4 : 8.0;
    final backWidth =
        onBack != null ? 48.0 : (alignLeft || compact ? 0.0 : 48.0);

    // Some previews embed this chrome directly as a widget, without the
    // bounded shell supplied by the app scaffold. Keep the title finite in
    // that context so Expanded cannot negotiate an effectively infinite Row.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            horizontalPad, 0, ReceiveFlowLayout.pageHorizontal, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: onBack,
                    icon: Icon(KeroseneIcons.back, size: 22),
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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
      ),
    );
  }
}

/// Full-screen receive step: shared title lead + expanded centered body.
///
/// One vertical system for hub / network / NFC / gateway so steps don't pin
/// content to the status bar or float H1 at unrelated fractions.
class ReceiveFlowScreenShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final bool embeddedInSheet;

  const ReceiveFlowScreenShell({
    super.key,
    required this.child,
    this.onBack,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.embeddedInSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
        final statusPad =
            embeddedInSheet ? 0.0 : ReceiveFlowLayout.statusTopPad(context);
        final lead =
            embeddedInSheet ? 12.0 : ReceiveFlowLayout.titleTopLead(viewportH);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: statusPad + lead),
            ReceiveFlowTitleBar(
              onBack: onBack,
              title: title,
              subtitle: subtitle,
              titleStyle: titleStyle,
              compact: embeddedInSheet,
              alignLeft: embeddedInSheet,
            ),
            const SizedBox(height: ReceiveFlowLayout.titleToContentGap),
            Expanded(
              child: SizedBox(
                width: constraints.maxWidth,
                child: child,
              ),
            ),
          ],
        );
      },
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
      color: ReceiveFlowLayout.sheetTopBorderColorOf(context),
    );
  }
}
