import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeFontSize, homeSize;
import 'package:kerosene/features/home/scene/models/home_scene.dart';

/// Soft dark halo so light copy stays legible on bright receive/aurora blooms.
const List<Shadow> kTheaterTextShadowsDark = <Shadow>[
  Shadow(
    color: Color(0xE6000000),
    blurRadius: 10,
    offset: Offset(0, 1),
  ),
  Shadow(
    color: Color(0x99000000),
    blurRadius: 22,
    offset: Offset(0, 2),
  ),
];

/// Soft light halo for dark ink on bright aurora blooms in light mode.
const List<Shadow> kTheaterTextShadowsLight = <Shadow>[
  Shadow(
    color: Color(0x66FFFFFF),
    blurRadius: 10,
    offset: Offset(0, 1),
  ),
  Shadow(
    color: Color(0x33FFFFFF),
    blurRadius: 18,
    offset: Offset(0, 2),
  ),
];

/// Backward-compatible alias (dark theater default).
const List<Shadow> kTheaterTextShadows = kTheaterTextShadowsDark;

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

    final semanticsLabel = [
      if (title.isNotEmpty) title,
      if (subtitle.isNotEmpty) subtitle,
      if (body.isNotEmpty && body != subtitle) body,
    ].join('. ');

    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = scheme.onSurface;
    final shadows = isLight ? kTheaterTextShadowsLight : kTheaterTextShadowsDark;

    // Dark theater: near-white on OLED. Light: scaffold ink + soft halo on blooms.
    final titleStyle = AppTypography.h1.copyWith(
      color: isLight ? ink : const Color(0xFFFFFFF2),
      height: 1.12,
      fontSize: compact ? homeFontSize(26) : homeFontSize(32),
      shadows: shadows,
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Segoe UI Emoji',
        'Apple Color Emoji',
      ],
    );

    final subtitleStyle = AppTypography.h2.copyWith(
      color: isLight
          ? ink.withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.92),
      height: 1.28,
      fontSize: compact ? homeFontSize(16) : homeFontSize(18),
      fontWeight: FontWeight.w600,
      shadows: shadows,
    );

    final bodyStyle = AppTypography.bodyMedium.copyWith(
      color: isLight
          ? scheme.onSurfaceVariant
          : Colors.white.withValues(alpha: 0.82),
      height: 1.4,
      fontSize: homeFontSize(15),
      shadows: shadows,
    );

    final child = switch (content.textMode) {
      SceneTextMode.typewriter => _TypewriterReveal(
          fullText: full,
          titleStyle: titleStyle,
          bodyStyle: subtitle.isNotEmpty || body.isNotEmpty
              ? subtitleStyle
              : bodyStyle,
          durationMs: showDurationMs,
          align: align,
          caretColor: isLight
              ? ink.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.55),
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
          subtitleStyle: subtitleStyle,
          bodyStyle: bodyStyle,
          align: align,
        ),
    };

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: child,
    );
  }
}

class _StaticBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final TextStyle bodyStyle;
  final TextAlign align;

  const _StaticBlock({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.titleStyle,
    required this.subtitleStyle,
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
          Text(
            title,
            style: titleStyle,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: homeSize(6)),
          Text(
            subtitle,
            style: subtitleStyle,
            textAlign: align,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (body.isNotEmpty && body != subtitle) ...[
          SizedBox(height: homeSize(6)),
          Text(
            body,
            style: bodyStyle,
            textAlign: align,
            maxLines: 6,
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
  final Color caretColor;

  const _TypewriterReveal({
    required this.fullText,
    required this.titleStyle,
    required this.bodyStyle,
    required this.durationMs,
    this.align = TextAlign.start,
    this.caretColor = const Color(0x8CFFFFFF),
  });

  @override
  State<_TypewriterReveal> createState() => _TypewriterRevealState();
}

class _TypewriterRevealState extends State<_TypewriterReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<int> _visibleCharacters = ValueNotifier<int>(0);
  List<int> _runes = const [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_syncText);
    _restart();
  }

  @override
  void didUpdateWidget(covariant _TypewriterReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText == widget.fullText &&
        oldWidget.durationMs == widget.durationMs) {
      return;
    }
    // SSE growth: new text is a prefix extension of the old — keep progress.
    if (widget.fullText.startsWith(oldWidget.fullText) &&
        oldWidget.fullText.isNotEmpty) {
      _extend(oldWidget.fullText);
      return;
    }
    _restart();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncText)
      ..dispose();
    _visibleCharacters.dispose();
    super.dispose();
  }

  void _restart() {
    _controller.stop();
    _runes = widget.fullText.runes.toList(growable: false);
    _visibleCharacters.value = 0;
    if (_runes.isEmpty) return;
    final typeWindow = (widget.durationMs * 0.55).round().clamp(4000, 14000);
    _controller.duration = Duration(milliseconds: typeWindow);
    _controller.forward(from: 0);
  }

  /// Grow target text without flashing back to zero (token stream).
  void _extend(String previousText) {
    final kept = _visibleCharacters.value.clamp(0, previousText.runes.length);
    _runes = widget.fullText.runes.toList(growable: false);
    if (_runes.isEmpty) {
      _visibleCharacters.value = 0;
      _controller.stop();
      return;
    }
    _visibleCharacters.value = kept.clamp(0, _runes.length);
    if (kept >= _runes.length) {
      _controller.value = 1;
      return;
    }
    final typeWindow = (widget.durationMs * 0.55).round().clamp(4000, 14000);
    _controller.duration = Duration(milliseconds: typeWindow);
    // Resume from current visible fraction so append keeps typing forward.
    final from = (kept / _runes.length).clamp(0.0, 1.0);
    if (!_controller.isAnimating) {
      _controller.forward(from: from);
    } else {
      // Re-target duration while mid-flight without resetting visible runes.
      final t = _controller.value;
      _controller
        ..stop()
        ..forward(from: t < from ? from : t);
    }
  }

  void _syncText() {
    if (_runes.isEmpty) {
      if (_visibleCharacters.value != 0) {
        _visibleCharacters.value = 0;
      }
      return;
    }
    final next =
        (_controller.value * _runes.length).floor().clamp(0, _runes.length);
    // Never shrink during an extend (protects against mid-frame races).
    if (next > _visibleCharacters.value) {
      _visibleCharacters.value = next;
    } else if (next == _runes.length &&
        _visibleCharacters.value != _runes.length) {
      _visibleCharacters.value = _runes.length;
    }
  }

  Widget _paragraph(String text, {required bool caret}) {
    final parts = text.split('\n\n');
    final title = parts.isNotEmpty ? parts.first : text;
    final body = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
    final caretStyle = widget.bodyStyle.copyWith(
      color: widget.caretColor,
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
        ValueListenableBuilder<int>(
          valueListenable: _visibleCharacters,
          builder: (context, count, child) {
            final visible = String.fromCharCodes(_runes.take(count));
            return _paragraph(visible, caret: count < _runes.length);
          },
        ),
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
