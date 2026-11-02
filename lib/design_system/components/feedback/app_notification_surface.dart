import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

enum AppNotificationTone { neutral, success, error, info, warning }

class AppNotificationAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const AppNotificationAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });
}

class AppNotificationStyle {
  static Color get surfaceColor => KeroseneBrandTokens.surface;
  static Color get borderColor => KeroseneBrandTokens.border;
  static Color get buttonColor => KeroseneBrandTokens.textPrimary;
  static Color get closeButtonColor => KeroseneBrandTokens.textPrimary;
  static Color get titleColor => KeroseneBrandTokens.textPrimary;
  static Color get bodyColor => KeroseneBrandTokens.textSecondary;
  static Color get metaColor => KeroseneBrandTokens.textMuted;

  // State meaning is carried by its icon and label, using the Home ink palette.
  static Color accentFor(AppNotificationTone tone) =>
      KeroseneBrandTokens.textPrimary;

  static IconData iconFor(AppNotificationTone tone) {
    return switch (tone) {
      AppNotificationTone.success => KeroseneIcons.success,
      AppNotificationTone.error => KeroseneIcons.error,
      AppNotificationTone.warning => KeroseneIcons.warning,
      AppNotificationTone.info => KeroseneIcons.info,
      AppNotificationTone.neutral => KeroseneIcons.pending,
    };
  }
}

class AppNotificationSurface extends StatelessWidget {
  final String title;
  final String? message;
  final AppNotificationTone tone;
  final VoidCallback? onClose;
  final List<AppNotificationAction> actions;
  final String? footerLabel;
  final IconData? leadingIcon;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? minHeight;
  final int? maxMessageLines;
  final bool showLeadingIcon;

  const AppNotificationSurface({
    super.key,
    required this.title,
    this.message,
    this.tone = AppNotificationTone.neutral,
    this.onClose,
    this.actions = const [],
    this.footerLabel,
    this.leadingIcon,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 14, 14),
    this.borderRadius = 0,
    this.minHeight,
    this.maxMessageLines = 3,
    this.showLeadingIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedTitle = _normalize(
      title,
      fallback: _fallbackTitle(context),
    );
    final normalizedMessage = _normalize(message ?? '', fallback: '');
    final normalizedFooter = _normalize(footerLabel ?? '', fallback: '');
    final brand = KeroseneBrandTheme.of(context);
    final accent = brand.textPrimary;

    return Container(
      constraints:
          minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: brand.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showLeadingIcon) ...[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: brand.surfaceMuted,
                      border: Border.all(
                        color: brand.border,
                      ),
                    ),
                    child: KeroseneIcon(
                      leadingIcon ?? AppNotificationStyle.iconFor(tone),
                      color: accent,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    normalizedTitle,
                    style: AppTypography.bodyMedium.copyWith(
                      color: brand.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 10),
                  _NotificationCloseButton(onPressed: onClose!),
                ],
              ],
            ),
            if (normalizedMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                normalizedMessage,
                maxLines: maxMessageLines,
                softWrap: true,
                overflow: maxMessageLines == null
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: brand.textSecondary,
                  fontSize: 13,
                  height: 1.42,
                  letterSpacing: 0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
            if (actions.isNotEmpty || normalizedFooter.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (actions.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in actions)
                            _NotificationActionButton(action: action),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (normalizedFooter.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        normalizedFooter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTypography.caption.copyWith(
                          color: brand.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: 0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _normalize(String value, {required String fallback}) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? fallback : collapsed;
  }

  static String _fallbackTitle(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return 'Update';
      case 'es':
        return 'Actualizacion';
      default:
        return 'Atualização';
    }
  }
}

class _NotificationCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NotificationCloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final brand = KeroseneBrandTheme.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: const KeroseneIcon(KeroseneIcons.close),
        color: brand.textSecondary,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        iconSize: 15,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
        ),
      ),
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  final AppNotificationAction action;

  const _NotificationActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final brand = KeroseneBrandTheme.of(context);
    final child = action.icon == null
        ? Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeroseneIcon(action.icon!, size: 14),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: brand.textInverse.withValues(alpha: 0.92),
        backgroundColor: brand.textPrimary,
        shape: const RoundedRectangleBorder(),
        textStyle: AppTypography.bodySmall.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      child: child,
    );
  }
}
