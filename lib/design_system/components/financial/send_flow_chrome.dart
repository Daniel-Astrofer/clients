import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';

/// Pins the primary CTA in the thumb zone (lower third) with consistent padding.
class SendFlowThumbDock extends StatelessWidget {
  final Widget child;
  final Color? background;

  const SendFlowThumbDock({
    super.key,
    required this.child,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: background ?? tokens.background,
        child: Padding(
          padding: tokens.thumbDockPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Primary financial-flow action: pill, min height from tokens, full-width.
class SendFlowPrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final IconData? icon;
  final bool inverted;

  const SendFlowPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.icon,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    final ready = enabled && !isLoading && onPressed != null;
    final bg = inverted
        ? (ready ? tokens.surfaceHigh : tokens.ctaDisabledBackground)
        : (ready ? tokens.ctaBackground : tokens.ctaDisabledBackground);
    final fg = inverted
        ? (ready ? tokens.textPrimary : tokens.ctaDisabledForeground)
        : (ready ? tokens.ctaForeground : tokens.ctaDisabledForeground);

    return SizedBox(
      width: double.infinity,
      height: tokens.ctaHeight,
      child: FilledButton(
        onPressed: ready ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: tokens.ctaDisabledBackground,
          disabledForegroundColor: tokens.ctaDisabledForeground,
          minimumSize: Size(double.infinity, tokens.minTouch),
          shape: RoundedRectangleBorder(borderRadius: tokens.pillBorderRadius),
          textStyle: tokens.ctaLabel(color: fg),
          elevation: 0,
        ),
        child: isLoading
            ? CupertinoActivityIndicator(radius: 9, color: fg)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (icon != null) ...[
                    SizedBox(width: tokens.spaceSm),
                    Icon(icon, size: 18, color: fg),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Soft card chrome for breakdown / review blocks.
class SendFlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SendFlowCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: tokens.cardBorderRadius,
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
        boxShadow: tokens.cardShadow,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.spaceMd),
        child: child,
      ),
    );
  }
}
