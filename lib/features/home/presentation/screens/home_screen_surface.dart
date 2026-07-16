// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'dart:ui';

import 'home_screen_dependencies.dart';
import 'home_screen.dart';

/// Pure OLED black body. Top accent color is owned solely by
/// [HomeStageFixedAtmosphere] (fixed stack layer — does not scroll).
class HomePageBackground extends StatelessWidget {
  const HomePageBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: homeBackgroundColor);
  }
}

class HomeEntryTransition extends StatefulWidget {
  final Widget child;

  const HomeEntryTransition({required this.child});

  @override
  State<HomeEntryTransition> createState() => HomeEntryTransitionState();
}

class HomeEntryTransitionState extends State<HomeEntryTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KeroseneMotion.slow,
    )..forward();
    final curve = CurvedAnimation(
      parent: _controller,
      curve: KeroseneMotion.standard,
    );
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          transformHitTests: false,
          child: widget.child,
        ),
      ),
    );
  }
}

class HomeGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  const HomeGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(HomeRadius.panel)),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: backgroundColor,
        gradient: backgroundColor == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [homePanelTopColor, homePanelBottomColor],
              )
            : null,
        border: Border.all(color: homePanelBorderColor),
        boxShadow: [
          BoxShadow(
            color: HomeColors.overlayDim,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: content,
    );

    return RepaintBoundary(child: clipped);
  }
}

class HomeLoadingContent extends StatelessWidget {
  const HomeLoadingContent();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * 0.72,
      child: const Center(
        child: TorLoadingDots(travel: 5),
      ),
    );
  }
}


class HomeSkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const HomeSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(HomeRadius.small)),
  });

  @override
  Widget build(BuildContext context) {
    final skeleton = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HomeColors.surfaceDim,
        borderRadius: borderRadius,
        border: Border.all(color: HomeColors.surfaceBorder),
      ),
    );

    if (KeroseneMotion.reduceMotion(context)) {
      return skeleton;
    }

    return skeleton
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1300.ms,
          color: HomeColors.surfaceBorder,
        );
  }
}

class HomeHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool hasBadge;

  const HomeHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: Semantics(
            button: true,
            label: semanticLabel,
            child: InkResponse(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              radius: homeSize(24),
              child: SizedBox(
                width: homeSize(48), // Bumped touch target to 48px min
                height: homeSize(48),
                child: Center(
                  child: Icon(
                    icon,
                    size: homeSize(24),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            right: homeSize(5),
            top: homeSize(5),
            child: Container(
              width: homeSize(9),
              height: homeSize(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: homeAmberColor,
                border: Border.all(color: AppColors.hexFF06090B, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class HomeBalanceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const HomeBalanceActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BouncingButtonWrapper(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(homeSize(16)),
        child: BackdropFilter(
          filter: primary 
              ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
              : ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            constraints: BoxConstraints(minHeight: homeSize(52)),
            padding: EdgeInsets.symmetric(horizontal: homeSize(16)),
            decoration: BoxDecoration(
              color: primary 
                  ? Colors.white 
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(homeSize(16)),
              border: Border.all(
                color: primary 
                    ? Colors.transparent 
                    : Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: homeSize(20),
                  color: primary ? Colors.black : Colors.white,
                ),
                SizedBox(width: homeSize(8)),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: primary ? Colors.black : Colors.white,
                      fontSize: homeFontSize(15),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePaginationDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const HomePaginationDots({
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) SizedBox(width: homeSize(6)),
          Container(
            width: homeSize(6),
            height: homeSize(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == activeIndex
                  ? Colors.white
                  : homeMutedTextColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class HomeSetupNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const HomeSetupNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(vertical: homeSize(16)),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: homeSize(2)),
            child: Icon(
              icon,
              size: homeSize(24),
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(width: homeSize(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontSize: homeFontSize(15),
                    fontFamily: AppTypography.serifFontFamily,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: homeSize(5)),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: homeFontSize(12),
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: homeSize(12)),
                TextButton.icon(
                  onPressed: onAction,
                  icon: Icon(KeroseneIcons.next, size: homeSize(15)),
                  label: Text(actionLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size(0, homeSize(34)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: homeFontSize(14),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: homeSize(12)),
          Padding(
            padding: EdgeInsets.only(top: homeSize(2)),
            child: Icon(
              KeroseneIcons.chevronRight,
              size: homeSize(18),
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
