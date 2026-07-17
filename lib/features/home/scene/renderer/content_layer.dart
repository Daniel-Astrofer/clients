import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeFontSize, homeSize;
import 'package:kerosene/features/home/scene/models/home_scene.dart';

/// Title / subtitle / body — supports static, typewriter, marquee presets.
class SceneContentLayer extends StatelessWidget {
  final SceneContent content;
  final String userName;
  final TextAlign align;
  final bool compact;
  final int showDurationMs;

  const SceneContentLayer({
    super.key,
    required this.content,
    this.userName = '',
    this.align = TextAlign.start,
    this.compact = false,
    this.showDurationMs = 15000,
  });

  @override
  Widget build(BuildContext context) {
    if (!content.hasText) return const SizedBox.shrink();

    final title = content.resolveTitle(userName).trim();
    final subtitle = content.subtitle.trim();
    final body = (content.body ?? '').trim();
    final full = body.isNotEmpty
        ? (subtitle.isNotEmpty
            ? '$title\n\n$subtitle\n\n$body'
            : '$title\n\n$body')
        : (subtitle.isNotEmpty ? '$title\n\n$subtitle' : title);

    final titleStyle = (compact ? AppTypography.h3Small : AppTypography.h3)
        .copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      height: 1.25,
      fontSize: compact ? homeFontSize(18) : homeFontSize(22),
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Segoe UI Emoji',
        'Apple Color Emoji',
      ],
    );

    final bodyStyle = AppTypography.bodyMedium.copyWith(
      color: Colors.white.withValues(alpha: 0.86),
      height: 1.4,
      fontSize: homeFontSize(15),
    );

    return switch (content.textMode) {
      SceneTextMode.typewriter => _TypewriterReveal(
          fullText: full,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
          durationMs: showDurationMs,
          align: align,
        ),
      SceneTextMode.marquee => _MarqueeLine(
          text: title,
          style: titleStyle,
          durationMs: showDurationMs.clamp(12000, 45000),
        ),
      SceneTextMode.staticText => _StaticBlock(
          title: title,
          subtitle: subtitle,
          body: body,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
          align: align,
        ),
    };
  }
}

class _StaticBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextAlign align;

  const _StaticBlock({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.titleStyle,
    required this.bodyStyle,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(title, style: titleStyle, textAlign: align),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: homeSize(6)),
          Text(
            subtitle,
            style: bodyStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
            textAlign: align,
          ),
        ],
        if (body.isNotEmpty && body != subtitle) ...[
          SizedBox(height: homeSize(8)),
          Text(
            body,
            style: bodyStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
            textAlign: align,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Typewriter that **never grows layout**: full text is laid out invisibly
/// (ghost) so height is reserved from frame 0; visible prefix paints on top.
class _TypewriterReveal extends StatefulWidget {
  final String fullText;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final int durationMs;
  final TextAlign align;

  const _TypewriterReveal({
    required this.fullText,
    required this.titleStyle,
    required this.bodyStyle,
    required this.durationMs,
    this.align = TextAlign.start,
  });

  @override
  State<_TypewriterReveal> createState() => _TypewriterRevealState();
}

class _TypewriterRevealState extends State<_TypewriterReveal> {
  Timer? _timer;
  int _chars = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _TypewriterReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _chars = 0;
    final total = widget.fullText.runes.length;
    if (total == 0) return;
    final typeWindow = (widget.durationMs * 0.55).round().clamp(4000, 14000);
    final stepMs = (typeWindow / total).round().clamp(18, 80);
    _timer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _chars = (_chars + 1).clamp(0, total));
      if (_chars >= total) t.cancel();
    });
  }

  Widget _paragraph(String text, {required bool caret}) {
    final parts = text.split('\n\n');
    final title = parts.isNotEmpty ? parts.first : text;
    final body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
    final caretStyle = widget.bodyStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.55),
    );
    final cross = widget.align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    Widget titleW = caret && body.isEmpty
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: widget.titleStyle),
                TextSpan(text: '▌', style: caretStyle),
              ],
            ),
            textAlign: widget.align,
          )
        : Text(title, style: widget.titleStyle, textAlign: widget.align);

    if (body.isEmpty) return titleW;

    final bodyW = caret
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: body, style: widget.bodyStyle),
                TextSpan(text: '▌', style: caretStyle),
              ],
            ),
            textAlign: widget.align,
          )
        : Text(body, style: widget.bodyStyle, textAlign: widget.align);

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleW,
        SizedBox(height: homeSize(10)),
        bodyW,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.fullText;
    final visible = String.fromCharCodes(full.runes.take(_chars));
    final stillTyping = _chars < full.runes.length;

    // Ghost full text reserves height from the first frame — balance below
    // never shifts while characters appear.
    return Stack(
      alignment: widget.align == TextAlign.center
          ? Alignment.topCenter
          : Alignment.topLeft,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: _paragraph(full, caret: false),
            ),
          ),
        ),
        _paragraph(visible, caret: stillTyping),
      ],
    );
  }
}

class _MarqueeLine extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int durationMs;

  const _MarqueeLine({
    required this.text,
    required this.style,
    required this.durationMs,
  });

  @override
  State<_MarqueeLine> createState() => _MarqueeLineState();
}

class _MarqueeLineState extends State<_MarqueeLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs.clamp(8000, 60000)),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _MarqueeLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationMs != widget.durationMs) {
      _ctrl.duration =
          Duration(milliseconds: widget.durationMs.clamp(8000, 60000));
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (widget.style.fontSize ?? 20) * 1.5,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final textWidth = painter.width;
          final viewport = constraints.maxWidth;
          if (textWidth <= viewport) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.text, maxLines: 1, style: widget.style),
            );
          }
          const gap = 80.0;
          final loopWidth = textWidth + gap;
          return ClipRect(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = -_ctrl.value * loopWidth;
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child:
                          Text(widget.text, maxLines: 1, style: widget.style),
                    ),
                    Transform.translate(
                      offset: Offset(dx + loopWidth, 0),
                      child:
                          Text(widget.text, maxLines: 1, style: widget.style),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
