import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/components/generic/kerosene_logo.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

/// Resolve receive-flow colors from the canonical [SendFlowTheme] so send
/// and receive share one palette. Callers that need a [BuildContext] use
/// [ReceiveFlowColors.of]. Legacy code without a context falls back to the
/// current mode via static getters.
///
/// Old frozen-constant names are kept as static getters for compat.
abstract final class ReceiveFlowColors {
  static SendFlowTheme _current() => SendFlowTheme.forVariant(
        ThemeTokenBridge.isLight ? Brightness.light : Brightness.dark,
      );

  static Color get backgroundColor => _current().background;
  static Color get backgroundTopColor => _current().background;
  static Color get backgroundBottomColor => _current().background;
  static Color get panelColor => _current().surface;
  static Color get panelAltColor => _current().surfaceHigh;
  static Color get panelRaisedColor => _current().surfaceRaised;
  static Color get borderColor => _current().border;
  static Color get borderStrongColor => _current().borderStrong;
  static Color get dividerColor => _current().border;
  static Color get textColor => _current().textPrimary;
  static Color get mutedTextColor => _current().textSecondary;
  static Color get faintTextColor => _current().textMuted;
  static Color get accentColor => _current().accent;

  static SendFlowTheme of(BuildContext context) => SendFlowTheme.of(context);
}

// Legacy frozen aliases — kept for tests / external references; prefer
// [ReceiveFlowColors] or [SendFlowTheme.of].
Color get receiveFlowBackgroundColor => ReceiveFlowColors.backgroundColor;
Color get receiveFlowBackgroundTopColor => ReceiveFlowColors.backgroundTopColor;
Color get receiveFlowBackgroundBottomColor =>
    ReceiveFlowColors.backgroundBottomColor;
Color get receiveFlowPanelColor => ReceiveFlowColors.panelColor;
Color get receiveFlowPanelAltColor => ReceiveFlowColors.panelAltColor;
Color get receiveFlowPanelRaisedColor => ReceiveFlowColors.panelRaisedColor;
Color get receiveFlowBorderColor => ReceiveFlowColors.borderColor;
Color get receiveFlowBorderStrongColor => ReceiveFlowColors.borderStrongColor;
Color get receiveFlowDividerColor => ReceiveFlowColors.dividerColor;
Color get receiveFlowTextColor => ReceiveFlowColors.textColor;
Color get receiveFlowMutedTextColor => ReceiveFlowColors.mutedTextColor;
Color get receiveFlowFaintTextColor => ReceiveFlowColors.faintTextColor;
Color get receiveFlowAccentColor => ReceiveFlowColors.accentColor;

class ReceiveFlowScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry bodyPadding;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBackButton;
  final double chromeRadius;

  const ReceiveFlowScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(18, 8, 18, 22),
    this.actions = const [],
    this.onBack,
    this.showBackButton = true,
    this.chromeRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final resolvedBodyPadding = bodyPadding.resolve(Directionality.of(context));
    final horizontalPadding = responsive.horizontalPadding;
    final effectiveBodyPadding = EdgeInsets.fromLTRB(
      horizontalPadding,
      resolvedBodyPadding.top,
      horizontalPadding,
      resolvedBodyPadding.bottom + keyboardInset,
    );
    final body = scrollable
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: effectiveBodyPadding,
            child: child,
          )
        : Padding(padding: effectiveBodyPadding, child: child);

    return Scaffold(
      backgroundColor: receiveFlowBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ReceiveFlowBackdrop(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.sm,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    children: [
                      _ReceiveFlowBrandBar(actions: actions),
                      const SizedBox(height: AppSpacing.md),
                      _ReceiveFlowHeader(
                        title: title,
                        subtitle: subtitle,
                        onBack: onBack,
                        showBackButton: showBackButton,
                        chromeRadius: chromeRadius,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveFlowBackdrop extends StatelessWidget {
  const _ReceiveFlowBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            receiveFlowBackgroundTopColor,
            receiveFlowBackgroundColor,
            receiveFlowBackgroundBottomColor,
          ],
          stops: const [0, 0.44, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.22, -0.82),
                radius: 0.92,
                colors: [
                  Colors.white.withValues(alpha: 0.045),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.018),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveFlowBrandBar extends StatelessWidget {
  final List<Widget> actions;

  const _ReceiveFlowBrandBar({required this.actions});

  @override
  Widget build(BuildContext context) {
    const brandLabel = 'KEROSENE';
    return Row(
      children: [
        const KeroseneLogo(size: 28, showText: false, color: Colors.white),
        const SizedBox(width: 9),
        Text(
          brandLabel,
          style: AppTypography.caption.copyWith(
            color: receiveFlowTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const Spacer(),
        if (actions.isNotEmpty)
          Flexible(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: actions,
            ),
          )
        else ...[
          Icon(
            KeroseneIcons.eye,
            color: receiveFlowTextColor.withValues(alpha: 0.82),
            size: 17,
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                KeroseneIcons.notifications,
                color: receiveFlowTextColor.withValues(alpha: 0.82),
                size: 18,
              ),
              Positioned(
                right: -1,
                top: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: receiveFlowAccentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReceiveFlowHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBackButton;
  final double chromeRadius;

  const _ReceiveFlowHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.showBackButton,
    required this.chromeRadius,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final titleSize = responsive.size.width < 340
        ? 21.0
        : responsive.isCompact
            ? 23.0
            : 26.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton)
          ReceiveFlowIconButton(
            icon: KeroseneIcons.back,
            onTap: onBack ?? () => Navigator.maybePop(context),
            radius: chromeRadius == 0 ? 999 : chromeRadius,
          )
        else
          const SizedBox(width: 38, height: 38),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HomeTypography.heroTitle(
                        color: receiveFlowTextColor,
                        fontSize: titleSize,
                      ).copyWith(height: 1.02),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 7),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: receiveFlowMutedTextColor,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ReceiveFlowIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double radius;

  const ReceiveFlowIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: receiveFlowTextColor, size: 17),
      style: IconButton.styleFrom(
        backgroundColor: receiveFlowPanelAltColor.withValues(alpha: 0.78),
        minimumSize: const Size(38, 38),
        padding: const EdgeInsets.all(9),
        side: BorderSide(color: receiveFlowBorderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ReceiveFlowPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;

  const ReceiveFlowPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.borderColor,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? receiveFlowPanelColor,
        borderRadius: BorderRadius.circular(radius == 0 ? 14 : radius),
        border: Border.all(color: borderColor ?? receiveFlowBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: -18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ReceiveFlowSectionLabel extends StatelessWidget {
  final String text;

  ReceiveFlowSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: receiveFlowFaintTextColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
    );
  }
}

class ReceiveFlowTag extends StatelessWidget {
  final String label;
  final IconData? icon;

  const ReceiveFlowTag({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: receiveFlowPanelRaisedColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: receiveFlowBorderStrongColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: receiveFlowMutedTextColor),
            SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: receiveFlowMutedTextColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}

class ReceiveFlowActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? tag;
  final VoidCallback? onTap;
  final bool enabled;

  const ReceiveFlowActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;
    final titleColor =
        isEnabled ? receiveFlowTextColor : receiveFlowMutedTextColor;
    final subtitleColor =
        isEnabled ? receiveFlowMutedTextColor : receiveFlowFaintTextColor;
    final borderColor =
        isEnabled ? receiveFlowBorderColor : receiveFlowDividerColor;
    final iconBorderColor =
        isEnabled ? receiveFlowBorderStrongColor : receiveFlowBorderColor;
    final tileColor =
        isEnabled ? receiveFlowPanelColor : receiveFlowBackgroundTopColor;
    final iconPanelColor =
        isEnabled ? receiveFlowPanelRaisedColor : receiveFlowPanelColor;
    final trailingIcon =
        isEnabled ? KeroseneIcons.chevronRight : KeroseneIcons.lock;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconPanelColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: iconBorderColor),
                  ),
                  child: Icon(icon, color: titleColor, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (tag != null) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 96),
                    child: Text(
                      tag!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(trailingIcon, size: 16, color: subtitleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiveFlowPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final double radius;

  const ReceiveFlowPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.icon,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    final foregroundColor =
        enabled ? AppColors.hexFF050505 : receiveFlowMutedTextColor;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor:
              enabled ? Colors.white : Colors.white.withValues(alpha: 0.06),
          foregroundColor: enabled ? Colors.black : receiveFlowMutedTextColor,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
          disabledForegroundColor: receiveFlowMutedTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius == 0 ? 10 : radius),
            side: BorderSide(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.92)
                  : receiveFlowBorderStrongColor,
            ),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? CupertinoActivityIndicator(
                radius: 9,
                color: foregroundColor,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: foregroundColor),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class ReceiveFlowSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool fullWidth;

  const ReceiveFlowSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: receiveFlowPanelColor,
          foregroundColor: receiveFlowTextColor,
          side: BorderSide(color: receiveFlowBorderStrongColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: receiveFlowTextColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class ReceiveFlowKeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;

  const ReceiveFlowKeypadButton({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius == 0 ? 10 : radius),
            child: Ink(
              height: 54,
              decoration: BoxDecoration(
                color: receiveFlowPanelAltColor,
                borderRadius: BorderRadius.circular(radius == 0 ? 10 : radius),
                border: Border.all(color: receiveFlowBorderStrongColor),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiveFlowMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const ReceiveFlowMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseValueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: receiveFlowTextColor,
          fontWeight: FontWeight.w500,
          height: 1.35,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: receiveFlowMutedTextColor,
                letterSpacing: 0,
              ),
        );
        final valueWidget = SelectableText(
          value,
          textAlign:
              constraints.maxWidth < 360 ? TextAlign.left : TextAlign.right,
          maxLines: constraints.maxWidth < 360 ? 4 : 2,
          style: mono
              ? AppTypography.technicalMono(textStyle: baseValueStyle)
              : baseValueStyle,
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), valueWidget],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: 16),
            Flexible(child: valueWidget),
          ],
        );
      },
    );
  }
}

class ReceiveFlowDivider extends StatelessWidget {
  const ReceiveFlowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(color: receiveFlowDividerColor, height: 1, thickness: 1),
    );
  }
}

class ReceiveFlowStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? footer;

  const ReceiveFlowStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return ReceiveFlowPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: receiveFlowPanelRaisedColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: receiveFlowBorderStrongColor),
            ),
            child: Icon(icon, color: receiveFlowTextColor, size: 17),
          ),
          SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: receiveFlowTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: receiveFlowMutedTextColor,
                  height: 1.4,
                ),
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}
