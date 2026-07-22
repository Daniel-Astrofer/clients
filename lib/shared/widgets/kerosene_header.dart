import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/performance/kerosene_graphics_policy.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';

/// Glass-morphism top bar. Blur is policy-gated — solid surface is pixel-close
/// on dark UI and avoids a permanent BackdropFilter saveLayer.
class KeroseneHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const KeroseneHeader({
    super.key,
    this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(graphicsPolicyProvider);
    final allowBlur =
        policy.allowBackdropBlur && !KeroseneMotion.reduceMotion(context);
    final surface = Theme.of(context).colorScheme.surface;
    final bar = Container(
      color: surface.withValues(alpha: allowBlur ? 0.6 : 0.92),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                if (showBackButton)
                  IconButton(
                    onPressed: onBackPressed ?? () => Navigator.pop(context),
                    icon: Icon(
                      KeroseneIcons.back,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                    ),
                  )
                else
                  SizedBox(width: 48),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: title != null
                      ? Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium!,
                          textAlign: TextAlign.center,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (actions != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );

    if (!allowBlur) {
      return bar;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: bar,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
