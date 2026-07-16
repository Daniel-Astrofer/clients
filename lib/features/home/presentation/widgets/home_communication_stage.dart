import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_settings_provider.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_stage_playback_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart';
import 'package:kerosene/features/home/presentation/widgets/home_stage_media.dart';
import 'package:kerosene/features/home/presentation/widgets/rich_theater_text.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';

/// Region A — backend communication theater.
class HomeCommunicationStage extends ConsumerStatefulWidget {
  final String userName;
  final GlobalKey? notificationButtonKey;

  const HomeCommunicationStage({
    super.key,
    required this.userName,
    this.notificationButtonKey,
  });

  @override
  ConsumerState<HomeCommunicationStage> createState() =>
      _HomeCommunicationStageState();
}

class _HomeCommunicationStageState extends ConsumerState<HomeCommunicationStage>
    with TickerProviderStateMixin {
  Timer? _lifecycleTimer;
  Timer? _typeTimer;
  String _sessionId = '';
  bool _finished = false;
  AnimationController? _enterCtrl;
  AnimationController? _marqueeCtrl;
  late final GlobalKey _localNotifKey = GlobalKey();

  /// Typewriter visible character count for first reveal.
  int _typeChars = 0;
  String _typeFull = '';

  @override
  void dispose() {
    _lifecycleTimer?.cancel();
    _typeTimer?.cancel();
    _enterCtrl?.dispose();
    _marqueeCtrl?.dispose();
    super.dispose();
  }

  void _ensureControllers(HomeStage stage) {
    final enterMs = stage.motion.enter.durationMs;
    _enterCtrl ??= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: enterMs),
    );
    if (_enterCtrl!.duration?.inMilliseconds != enterMs) {
      _enterCtrl!.duration = Duration(milliseconds: enterMs);
    }

    // Marquee slow: prefer long content duration (min 12s for long news).
    final contentMs = stage.motion.content.durationMs.clamp(12000, 45000);
    _marqueeCtrl ??= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: contentMs),
    )..repeat();
    if (_marqueeCtrl!.duration?.inMilliseconds != contentMs) {
      _marqueeCtrl!.duration = Duration(milliseconds: contentMs);
      if (!_marqueeCtrl!.isAnimating) _marqueeCtrl!.repeat();
    }
  }

  void _startTypewriter(String full, {required int durationMs}) {
    _typeTimer?.cancel();
    _typeFull = full;
    _typeChars = 0;
    if (full.isEmpty) return;
    final total = full.runes.length;
    // Aim to finish typing in ~55% of show duration (min 4s, max 14s).
    final typeWindow = (durationMs * 0.55).round().clamp(4000, 14000);
    final stepMs = (typeWindow / total).round().clamp(18, 80);
    _typeTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _typeChars = (_typeChars + 1).clamp(0, total);
      });
      if (_typeChars >= total) t.cancel();
    });
  }

  void _syncStage(HomeStage stage) {
    final id = '${stage.id}|${stage.kind.name}|${stage.content.title}|${stage.content.body}';
    if (id == _sessionId) return;
    _sessionId = id;
    _lifecycleTimer?.cancel();
    _typeTimer?.cancel();
    _finished = false;
    _typeChars = 0;

    final playback = ref.read(homeStagePlaybackProvider.notifier);
    if (!stage.isActive) {
      playback.clear();
      return;
    }

    _ensureControllers(stage);
    playback.play(stage);
    _enterCtrl?.forward(from: 0);

    final title = stage.content.resolveTitle(widget.userName);
    final body = (stage.content.body ?? '').trim();
    final full = body.isNotEmpty ? '$title\n\n$body' : title;
    final showMs = stage.lifecycle.showDurationMs.clamp(12000, 60000);

    final mode = stage.content.textMode;
    // Typewriter only when backend asks (TYPEWRITER). News can also marquee.
    final useTypewriter = mode == HomeStageTextMode.typewriter;

    if (useTypewriter) {
      _startTypewriter(full, durationMs: showMs);
    } else {
      _typeFull = full;
      _typeChars = full.runes.length;
    }

    final once = stage.playPolicy == HomeStagePlayPolicy.once;
    if (once && stage.media.type != HomeStageMediaType.video) {
      _lifecycleTimer = Timer(Duration(milliseconds: showMs), () {
        if (!mounted) return;
        _complete(stage);
      });
    }
  }

  void _complete(HomeStage stage) {
    if (_finished) return;
    _finished = true;
    _lifecycleTimer?.cancel();
    _typeTimer?.cancel();
    if (stage.lifecycle.restoreOnComplete) {
      ref.read(homeStagePlaybackProvider.notifier).clear();
    }
    // Tell backend + local cache this edition was received/read (ONCE only).
    // ignore: discarded_futures
    ref.read(homeSurfaceProvider.notifier).acknowledgeStageRead(stage);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final surface = ref.watch(homeSurfaceProvider);
    final stage = surface.stage;
    final playback = ref.watch(homeStagePlaybackProvider);
    _syncStage(stage);

    final showTheater = stage.isActive && !_finished;
    if (!showTheater) {
      return _RestingHeaderRow(
        userName: widget.userName,
        resting: surface.restingHeader,
        notificationButtonKey:
            widget.notificationButtonKey ?? _localNotifKey,
      );
    }

    _ensureControllers(stage);
    final placement = playback.actionsPlacement;
    final title = stage.content.resolveTitle(widget.userName);
    final body = (stage.content.body ?? '').trim();

    final useTypewriter =
        stage.content.textMode == HomeStageTextMode.typewriter;

    final useMarquee = !useTypewriter &&
        (stage.content.textMode == HomeStageTextMode.marquee ||
            stage.motion.content.type == HomeStageMotionType.marquee ||
            // Long single-line titles without body still marquee.
            (body.isEmpty && title.runes.length >= 28));

    // Vertical scroll for multi-line news when not typewriter/marquee line.
    final useParagraphScroll = !useTypewriter &&
        !useMarquee &&
        (body.isNotEmpty || title.contains('\n'));

    final visible = useTypewriter
        ? String.fromCharCodes(_typeFull.runes.take(_typeChars))
        : (body.isNotEmpty ? '$title\n\n$body' : title);

    final enterCurve = resolveStageCurve(stage.motion.enter.curve);
    final enterAnim = CurvedAnimation(parent: _enterCtrl!, curve: enterCurve);

    Widget content = _StageBody(
      stage: stage,
      title: title,
      body: body,
      visibleText: visible,
      useMarquee: useMarquee,
      useTypewriter: useTypewriter,
      useParagraphScroll: useParagraphScroll,
      marquee: _marqueeCtrl!,
      onVideoComplete: () {
        if (stage.playPolicy == HomeStagePlayPolicy.once) {
          _complete(stage);
        }
      },
    );

    content = FadeTransition(
      opacity: enterAnim,
      child: stage.motion.enter.type == HomeStageMotionType.fadeSlideDown
          ? SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(enterAnim),
              child: content,
            )
          : content,
    );

    final actionsBar = placement == HomeStageActionsPlacement.hidden
        ? const SizedBox.shrink()
        : _StageActionsBar(
            placement: placement,
            notificationButtonKey:
                widget.notificationButtonKey ?? _localNotifKey,
          );

    if (placement == HomeStageActionsPlacement.trailing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              actionsBar,
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (placement != HomeStageActionsPlacement.hidden) ...[
          SizedBox(height: homeSize(stage.layout.gap.clamp(8, 16))),
          actionsBar,
        ],
      ],
    );
  }
}

class _StageBody extends StatelessWidget {
  final HomeStage stage;
  final String title;
  final String body;
  final String visibleText;
  final bool useMarquee;
  final bool useTypewriter;
  final bool useParagraphScroll;
  final AnimationController marquee;
  final VoidCallback? onVideoComplete;

  const _StageBody({
    required this.stage,
    required this.title,
    required this.body,
    required this.visibleText,
    required this.useMarquee,
    required this.useTypewriter,
    this.useParagraphScroll = false,
    required this.marquee,
    this.onVideoComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final titleSize = responsive.compactFontSize(
      tiny: homeFontSize(18),
      compact: homeFontSize(20),
      regular: homeFontSize(22),
    );
    final bodySize = responsive.compactFontSize(
      tiny: homeFontSize(14),
      compact: homeFontSize(15),
      regular: homeFontSize(16),
    );

    final titleStyle = AppTypography.newsreader(
      textStyle: theme.textTheme.titleLarge,
      color: Colors.white,
      fontSize: titleSize,
      fontWeight: FontWeight.w400,
      height: 1.25,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: bodySize,
          fontWeight: FontWeight.w300,
          height: 1.45,
        ) ??
        TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: bodySize,
          height: 1.45,
        );

    final media = stage.media;
    final screenH = MediaQuery.sizeOf(context).height;
    // Soft ceiling only for pathological payloads — normal news must fit fully.
    // Never use backend maxHeight as a hard clip (that was cutting text).
    final softCeiling = (screenH * 0.42).clamp(220.0, 420.0);
    final minH = stage.layout.minHeight > 0
        ? homeSize(stage.layout.minHeight.clamp(0, softCeiling))
        : 0.0;

    final padT = homeSize(stage.layout.paddingTop.clamp(0, 16));
    final padB = homeSize(stage.layout.paddingBottom.clamp(4, 16));
    final padH = homeSize(4);
    final gap = homeSize(stage.layout.gap);
    final hasMedia = media.hasVisual;

    Widget textBlock;
    final richBlocks = stage.content.hasRichBlocks;
    if (richBlocks && !useMarquee) {
      // Structured H1/H2/body/bullets — preferred for education tips.
      textBlock = RichTheaterText(
        title: title,
        blocks: stage.content.blocks,
        maxHeight: softCeiling,
        titleAsH1: true,
      );
    } else if (useMarquee && !useTypewriter) {
      textBlock = SizedBox(
        height: titleSize * 1.5,
        width: double.infinity,
        child: _StageMarquee(
          text: title,
          style: titleStyle,
          animation: marquee,
        ),
      );
    } else if (useTypewriter) {
      // Ghost full text reserves final height — zero vertical jump while typing.
      // Expand to full content; softCeiling only if absurdly long.
      final full = body.isNotEmpty ? '$title\n\n$body' : title;
      final stillTyping = visibleText.runes.length < full.runes.length;
      textBlock = _TypewriterBlock(
        fullText: full,
        visibleText: visibleText,
        titleStyle: titleStyle,
        bodyStyle: bodyStyle,
        gap: homeSize(10),
        showCaret: stillTyping,
        maxHeight: softCeiling,
      );
    } else {
      textBlock = _StaticParagraphBlock(
        title: title,
        body: body,
        titleStyle: titleStyle,
        bodyStyle: bodyStyle,
        gap: homeSize(10),
        maxHeight: softCeiling,
        allowScroll: true,
      );
    }

    final bg = _bgColor(stage.layout.backgroundToken);
    Widget core;
    switch (stage.layout.preset) {
      case HomeStagePreset.mediaLeft:
        core = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasMedia) ...[
              HomeStageMediaView(
                media: media,
                maxHeight: 72,
                onVideoComplete: onVideoComplete,
              ),
              SizedBox(width: gap),
            ],
            Expanded(child: textBlock),
          ],
        );
      case HomeStagePreset.mediaTop:
      case HomeStagePreset.videoFocus:
        core = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
              HomeStageMediaView(
                media: media,
                maxHeight: 140,
                onVideoComplete: onVideoComplete,
              ),
            if (hasMedia) SizedBox(height: gap),
            textBlock,
          ],
        );
      default:
        core = textBlock;
    }

    final cta = stage.content.cta;
    Widget column = core;
    if (cta != null && cta.isNavigate && cta.label.trim().isNotEmpty) {
      column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          core,
          SizedBox(height: homeSize(10)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                padding: EdgeInsets.symmetric(
                  horizontal: homeSize(14),
                  vertical: homeSize(8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(homeSize(20)),
                ),
              ),
              onPressed: () {
                final target = cta.target.trim();
                if (target.isEmpty) return;
                Navigator.of(context).pushNamed(target);
              },
              child: Text(
                cta.label.trim(),
                style: TextStyle(
                  fontSize: bodySize * 0.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Natural height = full text. No maxHeight clip. No center alignment.
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minH),
      padding: EdgeInsets.fromLTRB(padH, padT, padH, padB),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(homeSize(14)),
      ),
      clipBehavior: Clip.none,
      child: column,
    );
  }

  Color? _bgColor(String token) {
    return switch (token) {
      'glass' || 'surface.elevated' => Colors.white.withValues(alpha: 0.06),
      'tint.positive' => homePositiveColor.withValues(alpha: 0.10),
      'tint.danger' => Colors.red.withValues(alpha: 0.10),
      _ => null,
    };
  }
}

/// Typewriter with [maintainSize] semantics: full ghost text reserves height
/// and wrapping from frame 0; visible prefix paints on top. No vertical jump.
class _TypewriterBlock extends StatelessWidget {
  final String fullText;
  final String visibleText;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final double gap;
  final bool showCaret;
  final double maxHeight;

  const _TypewriterBlock({
    required this.fullText,
    required this.visibleText,
    required this.titleStyle,
    required this.bodyStyle,
    required this.gap,
    required this.showCaret,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final ghost = _buildParagraph(
          fullText,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
          gap: gap,
          caret: false,
        );
        final visible = _buildParagraph(
          visibleText,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
          gap: gap,
          caret: showCaret,
        );

        // Measure full height so the slot never changes while typing.
        final measured = _measureParagraphHeight(
          fullText,
          maxWidth: maxW,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
          gap: gap,
        );
        final needsScroll = measured > maxHeight + 0.5;

        final stack = Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: [
            // Ghost: reserves layout / wrapping (invisible).
            ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(opacity: 0, child: ghost),
              ),
            ),
            // Visible reveal, same top-left origin as ghost.
            visible,
          ],
        );

        // Prefer growing with content so nothing is cut. Scroll only for
        // pathological lengths above softCeiling.
        if (!needsScroll) {
          return SizedBox(
            width: maxW.isFinite ? maxW : double.infinity,
            // Exact full height — never less than measured (that clips).
            height: measured,
            child: stack,
          );
        }

        return SizedBox(
          width: maxW.isFinite ? maxW : double.infinity,
          height: maxHeight,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: stack,
          ),
        );
      },
    );
  }

  /// Split title/body on first blank line pair; caret is an inline suffix
  /// so it never adds a new layout row.
  static Widget _buildParagraph(
    String text, {
    required TextStyle titleStyle,
    required TextStyle bodyStyle,
    required double gap,
    required bool caret,
  }) {
    final parts = text.split('\n\n');
    final title = parts.isNotEmpty ? parts.first : text;
    final body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
    final caretStyle = bodyStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.55),
    );

    Widget titleWidget;
    if (caret && body.isEmpty) {
      titleWidget = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title, style: titleStyle),
            TextSpan(text: '▌', style: caretStyle),
          ],
        ),
        textAlign: TextAlign.left,
      );
    } else {
      titleWidget = Text(title, textAlign: TextAlign.left, style: titleStyle);
    }

    if (body.isEmpty) {
      return titleWidget;
    }

    final bodyWidget = caret
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: body, style: bodyStyle),
                TextSpan(text: '▌', style: caretStyle),
              ],
            ),
            textAlign: TextAlign.left,
          )
        : Text(body, textAlign: TextAlign.left, style: bodyStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleWidget,
        SizedBox(height: gap),
        bodyWidget,
      ],
    );
  }

  static double _measureParagraphHeight(
    String text, {
    required double maxWidth,
    required TextStyle titleStyle,
    required TextStyle bodyStyle,
    required double gap,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      maxWidth = 360;
    }
    final parts = text.split('\n\n');
    final title = parts.isNotEmpty ? parts.first : text;
    final body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    if (body.isEmpty) return titlePainter.height;

    final bodyPainter = TextPainter(
      text: TextSpan(text: body, style: bodyStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return titlePainter.height + gap + bodyPainter.height;
  }
}

/// Static title/body: height = content (capped); scroll only on overflow.
class _StaticParagraphBlock extends StatelessWidget {
  final String title;
  final String body;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final double gap;
  final double maxHeight;
  final bool allowScroll;

  const _StaticParagraphBlock({
    required this.title,
    required this.body,
    required this.titleStyle,
    required this.bodyStyle,
    required this.gap,
    required this.maxHeight,
    required this.allowScroll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.left, style: titleStyle),
            if (body.isNotEmpty) ...[
              SizedBox(height: gap),
              Text(body, textAlign: TextAlign.left, style: bodyStyle),
            ],
          ],
        );

        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxW);
        var h = titlePainter.height;
        if (body.isNotEmpty) {
          final bodyPainter = TextPainter(
            text: TextSpan(text: body, style: bodyStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxW);
          h += gap + bodyPainter.height;
        }

        // Grow with content — no artificial clip for normal news lengths.
        if (h <= maxHeight + 0.5 || !allowScroll) {
          return Align(
            alignment: Alignment.topLeft,
            child: content,
          );
        }

        return SizedBox(
          height: maxHeight,
          width: double.infinity,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: content,
          ),
        );
      },
    );
  }
}

class _StageMarquee extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Animation<double> animation;

  const _StageMarquee({
    required this.text,
    required this.style,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final textWidth = painter.width;
        final viewport = constraints.maxWidth;
        if (textWidth <= viewport) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(text, maxLines: 1, style: style),
          );
        }
        final gap = 80.0;
        final loopWidth = textWidth + gap;
        return ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              // Slower feel: use half of controller for scroll speed.
              final dx = -animation.value * loopWidth;
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: Text(text, maxLines: 1, style: style),
                  ),
                  Transform.translate(
                    offset: Offset(dx + loopWidth, 0),
                    child: Text(text, maxLines: 1, style: style),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StageActionsBar extends ConsumerWidget {
  final HomeStageActionsPlacement placement;
  final GlobalKey notificationButtonKey;

  const _StageActionsBar({
    required this.placement,
    required this.notificationButtonKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final notificationCount = ref.watch(sessionNotificationUnreadCountProvider);
    final gap = homeSize(8);

    final buttons = [
      HomeHeaderIconButton(
        icon: balanceSettings.isHidden
            ? KeroseneIcons.eyeOff
            : KeroseneIcons.eye,
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(balanceSettingsProvider.notifier).toggleVisibility();
        },
      ),
      SizedBox(width: gap),
      HomeHeaderIconButton(
        key: notificationButtonKey,
        icon: KeroseneIcons.notifications,
        hasBadge: notificationCount > 0,
        onTap: () async {
          HapticFeedback.selectionClick();
          await openNotificationCenter(
            context,
            originKey: notificationButtonKey,
          );
        },
      ),
      SizedBox(width: gap),
      HomeHeaderIconButton(
        icon: KeroseneIcons.settings,
        onTap: () {
          HapticFeedback.selectionClick();
          AppPrimaryNavigationBar.navigateTo(
            context,
            AppPrimaryDestination.settings,
          );
        },
      ),
    ];

    if (placement == HomeStageActionsPlacement.belowStage) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: buttons,
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

class _RestingHeaderRow extends ConsumerWidget {
  final String userName;
  final HomeRestingHeader resting;
  final GlobalKey notificationButtonKey;

  const _RestingHeaderRow({
    required this.userName,
    required this.resting,
    required this.notificationButtonKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final notificationCount = ref.watch(sessionNotificationUnreadCountProvider);
    final hour = DateTime.now().hour;
    final text = !resting.includeName
        ? (hour < 12
            ? context.tr.homeGreetingMorning('').trim()
            : hour < 18
                ? context.tr.homeGreetingAfternoon('').trim()
                : context.tr.homeGreetingEvening('').trim())
        : hour < 12
            ? context.tr.homeGreetingMorning(userName)
            : hour < 18
                ? context.tr.homeGreetingAfternoon(userName)
                : context.tr.homeGreetingEvening(userName);

    final fontSize = responsive.compactFontSize(
      tiny: homeFontSize(22),
      compact: homeFontSize(24),
      regular: homeFontSize(25),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.newsreader(
              textStyle: theme.textTheme.titleLarge,
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              height: 1.1,
            ),
          ),
        ),
        if (resting.balanceVisibility) ...[
          SizedBox(width: homeSize(8)),
          HomeHeaderIconButton(
            icon: balanceSettings.isHidden
                ? KeroseneIcons.eyeOff
                : KeroseneIcons.eye,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(balanceSettingsProvider.notifier).toggleVisibility();
            },
          ),
        ],
        if (resting.notifications) ...[
          SizedBox(width: homeSize(8)),
          HomeHeaderIconButton(
            key: notificationButtonKey,
            icon: KeroseneIcons.notifications,
            hasBadge: notificationCount > 0,
            onTap: () async {
              HapticFeedback.selectionClick();
              await openNotificationCenter(
                context,
                originKey: notificationButtonKey,
              );
            },
          ),
        ],
        if (resting.settings) ...[
          SizedBox(width: homeSize(8)),
          HomeHeaderIconButton(
            icon: KeroseneIcons.settings,
            onTap: () {
              HapticFeedback.selectionClick();
              AppPrimaryNavigationBar.navigateTo(
                context,
                AppPrimaryDestination.settings,
              );
            },
          ),
        ],
      ],
    );
  }
}
