import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/presentation/providers/home_greeting_playback_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';

/// Reactive greeting with backend-configured play policy.
///
/// EPHEMERAL / ONCE: show market marquee lines once → restore time-of-day + buttons.
/// LOOP / TICKER: keep rotating.
class HomeGreetingSlot extends ConsumerStatefulWidget {
  final String userName;

  const HomeGreetingSlot({super.key, required this.userName});

  @override
  ConsumerState<HomeGreetingSlot> createState() => _HomeGreetingSlotState();
}

class _HomeGreetingSlotState extends ConsumerState<HomeGreetingSlot>
    with SingleTickerProviderStateMixin {
  Timer? _advanceTimer;
  int _index = 0;
  bool _finishedOnce = false;
  String _sessionKey = '';
  AnimationController? _marquee;
  Animation<double>? _marqueeAnim;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _marquee?.dispose();
    // Don't touch ref after dispose if possible — schedule idle on next frame only if mounted path.
    super.dispose();
  }

  void _ensureMarquee({required int durationMs}) {
    final d = Duration(milliseconds: durationMs.clamp(4000, 14000));
    if (_marquee == null) {
      _marquee = AnimationController(vsync: this, duration: d)..repeat();
      _marqueeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _marquee!, curve: Curves.linear),
      );
    } else if (_marquee!.duration != d) {
      _marquee!.duration = d;
      if (!_marquee!.isAnimating) {
        _marquee!.repeat();
      }
    }
  }

  void _publishPlayback({
    required HomeGreetingConfig greeting,
    required bool playing,
  }) {
    final p = greeting.presentation;
    final notifier = ref.read(homeGreetingPlaybackProvider.notifier);
    if (!playing) {
      notifier.setIdle();
      return;
    }
    notifier.setPlaying(
      hideActions: p.hideActionsWhilePlaying,
      pushDownBalancePx:
          p.pushDownBalanceWhilePlaying ? p.pushDownBalancePx : 0,
      compressLayout: p.compressLayoutWhilePlaying,
    );
  }

  void _syncSession(HomeGreetingConfig greeting) {
    final active = greeting.activeMessages;
    final key =
        '${greeting.mode.name}|${greeting.presentation.playPolicy.name}|'
        '${active.map((m) => m.id).join(",")}|${greeting.rotation.intervalMs}|'
        '${greeting.rotation.loop}';
    if (key == _sessionKey) return;

    _sessionKey = key;
    _advanceTimer?.cancel();
    _index = 0;
    _finishedOnce = false;

    if (active.isEmpty) {
      _publishPlayback(greeting: greeting, playing: false);
      return;
    }

    final once = greeting.isEphemeralOnce;
    _publishPlayback(greeting: greeting, playing: true);
    _scheduleAdvance(greeting, once: once);
  }

  void _scheduleAdvance(HomeGreetingConfig greeting, {required bool once}) {
    _advanceTimer?.cancel();
    final active = greeting.activeMessages;
    if (active.isEmpty) return;

    final current = active[_index.clamp(0, active.length - 1)];
    final dwell = current.durationMs > 0
        ? current.durationMs
        : greeting.rotation.intervalMs;
    _ensureMarquee(durationMs: dwell);

    _advanceTimer = Timer(Duration(milliseconds: dwell.clamp(1000, 20000)), () {
      if (!mounted) return;
      final latest = ref.read(homeSurfaceProvider).header.greeting;
      final msgs = latest.activeMessages;
      if (msgs.isEmpty) {
        setState(() => _finishedOnce = true);
        _publishPlayback(greeting: latest, playing: false);
        return;
      }

      if (once) {
        if (_index >= msgs.length - 1) {
          setState(() {
            _finishedOnce = true;
            _index = 0;
          });
          if (latest.presentation.restoreActionsAfterPlay) {
            _publishPlayback(greeting: latest, playing: false);
          }
          return;
        }
        setState(() => _index += 1);
        _scheduleAdvance(latest, once: true);
        return;
      }

      // LOOP
      setState(() => _index = (_index + 1) % msgs.length);
      _scheduleAdvance(latest, once: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final greeting = ref.watch(
      homeSurfaceProvider.select((s) => s.header.greeting),
    );
    _syncSession(greeting);

    final active = greeting.activeMessages;
    final playing = !_finishedOnce &&
        active.isNotEmpty &&
        (greeting.mode == HomeGreetingMode.ephemeral ||
            greeting.mode == HomeGreetingMode.ticker ||
            greeting.mode == HomeGreetingMode.overrideMode ||
            greeting.isEphemeralOnce);

    final showMarket = playing && active.isNotEmpty;
    final message = showMarket
        ? active[_index.clamp(0, active.length - 1)]
        : null;
    final text = showMarket
        ? message!.resolveText(widget.userName)
        : _localizedTimeOfDay(context, widget.userName, greeting.fallback);
    final color = _resolveColor(message);
    final useMarquee = showMarket &&
        (message?.animation == HomeGreetingAnimation.marquee ||
            text.runes.length >= 28);

    final baseFontSize = responsive.compactFontSize(
      tiny: homeFontSize(20),
      compact: homeFontSize(22),
      regular: homeFontSize(24),
    );

    final textStyle = AppTypography.newsreader(
      textStyle: theme.textTheme.titleLarge,
      color: color,
      fontSize: baseFontSize,
      fontWeight: FontWeight.w300,
      height: 1.15,
      letterSpacing: 0,
    );

    if (useMarquee) {
      final dwell = message?.durationMs ?? greeting.rotation.intervalMs;
      _ensureMarquee(durationMs: dwell);
      return AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: baseFontSize * 1.4,
          width: double.infinity,
          child: _MarqueeText(
            key: ValueKey('mq-$text'),
            text: text,
            style: textStyle,
            animation: _marqueeAnim!,
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }

  Color _resolveColor(HomeGreetingMessage? message) {
    final token = message?.style.colorToken ?? 'white';
    return switch (token) {
      'positive' => homePositiveColor,
      'danger' => AppColors.hexFFFF5A67,
      'amber' => homeAmberColor,
      'muted' => homeMutedTextColor,
      _ => Colors.white,
    };
  }

  static String _localizedTimeOfDay(
    BuildContext context,
    String userName,
    HomeGreetingFallback fallback,
  ) {
    final includeName = fallback.includeName;
    final hour = DateTime.now().hour;
    if (!includeName) {
      if (hour < 12) {
        return context.tr
            .homeGreetingMorning('')
            .trim()
            .replaceAll(RegExp(r'[,\s]+$'), '');
      }
      if (hour < 18) {
        return context.tr
            .homeGreetingAfternoon('')
            .trim()
            .replaceAll(RegExp(r'[,\s]+$'), '');
      }
      return context.tr
          .homeGreetingEvening('')
          .trim()
          .replaceAll(RegExp(r'[,\s]+$'), '');
    }
    if (hour < 12) return context.tr.homeGreetingMorning(userName);
    if (hour < 18) return context.tr.homeGreetingAfternoon(userName);
    return context.tr.homeGreetingEvening(userName);
  }
}

class _MarqueeText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Animation<double> animation;

  const _MarqueeText({
    super.key,
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

        final gap = 56.0;
        final loopWidth = textWidth + gap;

        return ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
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
