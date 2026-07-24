// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'home_screen_dependencies.dart';

/// Pure OLED black body. Top accent color is owned solely by
/// [HomeStageFixedAtmosphere] (fixed stack layer — does not scroll).
class HomePageBackground extends StatelessWidget {
  const HomePageBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
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

/// Standard card panel for home feed / distribution / empty states.
///
/// Uses [HomeSurfaceTheme] tokens so the look stays consistent across
/// dark OLED and light modes.
class HomeGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  const HomeGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(HomeRadius.card)),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final surface = HomeSurfaceTheme.of(context);
    final resolvedBg = backgroundColor ?? surface.card;
    final resolvedBorder = surface.surfaceBorder;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: resolvedBg,
        border: Border.all(color: resolvedBorder),
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
      child: Center(
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
    this.borderRadius =
        const BorderRadius.all(Radius.circular(HomeRadius.small)),
  });

  @override
  Widget build(BuildContext context) {
    // Flat matte placeholder — no metallic shimmer.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: borderRadius,
      ),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
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
                border: Border.all(
                    color: Theme.of(context).dividerColor, width: 1.5),
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
    final borderRadius = BorderRadius.circular(homeSize(16));
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: homeFontSize(15),
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    final Widget panel;
    if (primary) {
      // Receber: solid white chrome with live glyph cutouts — text/icon expose
      // exactly whatever is scrolling behind the button (aurora / stage glow).
      panel = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: homeSize(52),
          width: double.infinity,
          child: CustomPaint(
            painter: _ReceiveLiveGlassCutoutPainter(
              icon: icon,
              label: label,
              iconSize: homeSize(20),
              gap: homeSize(8),
              fontSize: homeFontSize(15),
              fontWeight: FontWeight.w600,
              fontFamily: labelStyle?.fontFamily,
              fontFamilyFallback: labelStyle?.fontFamilyFallback,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    } else {
      final surface = HomeSurfaceTheme.of(context);
      final content = Container(
        constraints: BoxConstraints(minHeight: homeSize(52)),
        padding: EdgeInsets.symmetric(horizontal: homeSize(16)),
        decoration: BoxDecoration(
          color: surface.surfaceDim,
          borderRadius: borderRadius,
          border: Border.all(
            color: surface.surfaceBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: homeSize(20), color: Theme.of(context).colorScheme.onSurface),
            SizedBox(width: homeSize(8)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        ),
      );
      panel = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ActionGlassGlowPainter(context)),
            ),
            content,
          ],
        ),
      );
    }

    return BouncingButtonWrapper(
      onTap: onTap,
      child: RepaintBoundary(child: panel),
    );
  }
}

/// White button fill with punched-through glyphs.
///
/// Transparent letterforms composite over the home stack, so aurora / stage
/// glow scrolling behind is visible live through the text and icon — not a
/// baked ShaderMask gradient.
class _ReceiveLiveGlassCutoutPainter extends CustomPainter {
  final IconData icon;
  final String label;
  final double iconSize;
  final double gap;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  const _ReceiveLiveGlassCutoutPainter({
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.gap,
    required this.fontSize,
    required this.fontWeight,
    required this.fontFamily,
    required this.fontFamilyFallback,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    canvas.drawRect(bounds, Paint()..color = const Color(0xFFFFFFFF));

    // Punch opaque glyphs out of the white fill → live backdrop shows through.
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstOut);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: const Color(0xFF000000),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          color: const Color(0xFF000000),
          height: 1.1,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0.0, size.width - iconSize - gap - 32));

    final totalWidth = iconPainter.width + gap + labelPainter.width;
    final startX = (size.width - totalWidth) / 2;
    iconPainter.paint(
      canvas,
      Offset(startX, (size.height - iconPainter.height) / 2),
    );
    labelPainter.paint(
      canvas,
      Offset(
        startX + iconPainter.width + gap,
        (size.height - labelPainter.height) / 2,
      ),
    );

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReceiveLiveGlassCutoutPainter oldDelegate) {
    return oldDelegate.icon != icon ||
        oldDelegate.label != label ||
        oldDelegate.iconSize != iconSize ||
        oldDelegate.gap != gap ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.fontWeight != fontWeight ||
        oldDelegate.fontFamily != fontFamily;
  }
}

class _ActionGlassGlowPainter extends CustomPainter {
  final BuildContext context;
  const _ActionGlassGlowPainter(this.context);

  @override
  void paint(Canvas canvas, Size size) {
    void haze(Offset center, double radius, double peak) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [
              Theme.of(context).colorScheme.onSurface.withValues(alpha: peak),
              Theme.of(context).colorScheme.onSurface.withValues(alpha: peak * 0.35),
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }

    haze(Offset(size.width * 0.18, 0), size.width * 0.34, 0.07);
    haze(Offset(size.width * 0.86, size.height), size.width * 0.38, 0.04);
  }

  @override
  bool shouldRepaint(covariant _ActionGlassGlowPainter oldDelegate) => false;
}

/// Home pagination dots with two visual styles:
/// - [HomePaginationDotStyle.circle]: round 6dp dots (education carousel, feeds).
/// - [HomePaginationDotStyle.pill]: animated pill with accent color (balance carousel).
enum HomePaginationDotStyle { circle, pill }

class HomePaginationDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final List<Color>? accents;
  final ValueChanged<int>? onDotTap;
  final HomePaginationDotStyle style;

  const HomePaginationDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.accents,
    this.onDotTap,
    this.style = HomePaginationDotStyle.circle,
  });

  @override
  Widget build(BuildContext context) {
    final isPill = style == HomePaginationDotStyle.pill;

    return Semantics(
      label: 'Página ${activeIndex + 1} de $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) SizedBox(width: isPill ? homeSize(4) : homeSize(6)),
            _buildDot(context, index, isPill),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int index, bool isPill) {
    final active = index == activeIndex;
    final accent = accents != null && index < accents!.length ? accents![index] : null;

    final dot = isPill
        ? AnimatedContainer(
            duration: HomeMotion.short,
            curve: Curves.easeOutCubic,
            width: active ? homeSize(18) : homeSize(7),
            height: homeSize(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(homeSize(999)),
              color: active
                  ? (accent?.withValues(alpha: 0.95) ??
                      Theme.of(context).colorScheme.onSurface)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
            ),
          )
        : AnimatedContainer(
            duration: HomeMotion.short,
            curve: Curves.easeOutCubic,
            width: homeSize(6),
            height: homeSize(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          );

    if (onDotTap != null) {
      return GestureDetector(
        onTap: () => onDotTap!(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isPill ? homeSize(4) : 0),
          child: dot,
        ),
      );
    }

    return dot;
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
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
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
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: homeFontSize(15),
                    fontFamily: AppTypography.serifFontFamily,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: homeSize(5)),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
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
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
