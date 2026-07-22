import 'package:flutter/material.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/design/home_design_tokens.dart';
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';

/// Linux/desktop often lacks color-emoji in serif/sans faces (Newsreader/Inter).
/// Without fallbacks, theater titles/bullets show tofu (□) or blank glyphs.
const List<String> kTheaterEmojiFontFallback = <String>[
  'Noto Color Emoji',
  'Noto Emoji',
  'Segoe UI Emoji',
  'Apple Color Emoji',
  'Twemoji Mozilla',
  'EmojiOne Color',
];

TextStyle _theaterStyle(TextStyle base) {
  final existing = base.fontFamilyFallback ?? const <String>[];
  return base.copyWith(
    fontFamilyFallback: <String>[
      ...existing,
      ...kTheaterEmojiFontFallback,
    ],
  );
}

/// Hierarchical theater copy: H1 / H2 / body / bullets / caption + bold spans.
///
/// Emojis are decorative leading glyphs; [semanticsLabel] concatenates plain text.
class RichTheaterText extends StatelessWidget {
  final String title;
  final List<TheaterTextBlock> blocks;
  final double maxHeight;

  /// When true, H1 is always shown from [title]; blocks skip role H1.
  final bool titleAsH1;

  const RichTheaterText({
    super.key,
    required this.title,
    required this.blocks,
    this.maxHeight = 320,
    this.titleAsH1 = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = context.responsive;

    final h1Size = responsive.compactFontSize(
      tiny: homeFontSize(18),
      compact: homeFontSize(20),
      regular: homeFontSize(22),
    );
    final h2Size = responsive.compactFontSize(
      tiny: homeFontSize(15),
      compact: homeFontSize(16),
      regular: homeFontSize(17),
    );
    final bodySize = responsive.compactFontSize(
      tiny: homeFontSize(13),
      compact: homeFontSize(14),
      regular: homeFontSize(15),
    );
    final captionSize = responsive.compactFontSize(
      tiny: homeFontSize(11),
      compact: homeFontSize(12),
      regular: homeFontSize(12),
    );

    final h1Style = _theaterStyle(AppTypography.newsreader(
      textStyle: theme.textTheme.titleLarge,
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: h1Size,
      fontWeight: FontWeight.w500,
      height: 1.25,
    ));
    final h2Style = _theaterStyle(
      theme.textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
            fontSize: h2Size,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ) ??
          TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.95),
            fontSize: h2Size,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
    );
    final bodyStyle = _theaterStyle(
      theme.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
            fontSize: bodySize,
            fontWeight: FontWeight.w300,
            height: 1.45,
          ) ??
          TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
            fontSize: bodySize,
            fontWeight: FontWeight.w300,
            height: 1.45,
          ),
    );
    final bulletStyle = bodyStyle.copyWith(
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.90),
    );
    final captionStyle = _theaterStyle(
      theme.textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
            fontSize: captionSize,
            fontWeight: FontWeight.w300,
            height: 1.35,
          ) ??
          TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
            fontSize: captionSize,
            fontWeight: FontWeight.w300,
            height: 1.35,
          ),
    );

    final children = <Widget>[];
    if (titleAsH1 && title.trim().isNotEmpty) {
      children.add(
        Text(
          title.trim(),
          style: h1Style,
          textAlign: TextAlign.start,
        ),
      );
    }

    for (final block in blocks) {
      if (block.role == TheaterBlockRole.spacer) {
        children.add(SizedBox(height: homeSize(8)));
        continue;
      }
      if (block.role == TheaterBlockRole.h1 && titleAsH1) {
        // Title already painted as H1.
        continue;
      }
      if (!block.hasVisibleText &&
          (block.emoji == null || block.emoji!.isEmpty)) {
        continue;
      }

      final style = switch (block.role) {
        TheaterBlockRole.h1 => h1Style,
        TheaterBlockRole.h2 => h2Style,
        TheaterBlockRole.caption => captionStyle,
        TheaterBlockRole.bullet => bulletStyle,
        TheaterBlockRole.body ||
        TheaterBlockRole.spacer ||
        TheaterBlockRole.unknown =>
          bodyStyle,
      };

      final topGap = switch (block.role) {
        TheaterBlockRole.h2 => children.isEmpty ? 0.0 : homeSize(8),
        TheaterBlockRole.body => homeSize(8),
        TheaterBlockRole.bullet => homeSize(4),
        TheaterBlockRole.caption => homeSize(8),
        TheaterBlockRole.h1 => homeSize(4),
        _ => homeSize(6),
      };

      children.add(SizedBox(height: topGap));
      children.add(
        _BlockRow(
          block: block,
          baseStyle: style,
          emojiSize: block.role == TheaterBlockRole.h2 ? h2Size : bodySize + 1,
        ),
      );
    }

    final semantics = _semanticsLabel(title, blocks);

    return Semantics(
      label: semantics,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  static String _semanticsLabel(String title, List<TheaterTextBlock> blocks) {
    final parts = <String>[];
    if (title.trim().isNotEmpty) parts.add(title.trim());
    for (final b in blocks) {
      if (!b.hasVisibleText) continue;
      parts.add(b.text.trim());
    }
    return parts.join('. ');
  }
}

class _BlockRow extends StatelessWidget {
  final TheaterTextBlock block;
  final TextStyle baseStyle;
  final double emojiSize;

  const _BlockRow({
    required this.block,
    required this.baseStyle,
    required this.emojiSize,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = (block.emoji ?? '').trim();
    final rich = _buildRichText(block.text, block.spans, baseStyle);

    if (emoji.isEmpty) {
      return rich;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: homeSize(emojiSize + 6),
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: emojiSize,
                height: 1.2,
                fontFamilyFallback: kTheaterEmojiFontFallback,
              ),
            ),
          ),
        ),
        SizedBox(width: homeSize(6)),
        Expanded(child: rich),
      ],
    );
  }

  Widget _buildRichText(
    String text,
    List<TheaterTextSpanMark> spans,
    TextStyle base,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();
    if (spans.isEmpty) {
      return Text(text, style: base, textAlign: TextAlign.start);
    }

    final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    final children = <InlineSpan>[];
    var cursor = 0;
    final runes = text.runes.toList();
    // Spans are code-unit based (Dart String indices) for catalog simplicity.
    for (final mark in sorted) {
      if (!mark.isValid) continue;
      final start = mark.start.clamp(0, text.length);
      final end = mark.end.clamp(0, text.length);
      if (end <= start || start < cursor) continue;
      if (start > cursor) {
        children
            .add(TextSpan(text: text.substring(cursor, start), style: base));
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: base.copyWith(
            fontWeight: switch (mark.weight) {
              TheaterTextWeight.regular => FontWeight.w400,
              TheaterTextWeight.medium => FontWeight.w600,
              TheaterTextWeight.bold ||
              TheaterTextWeight.unknown =>
                FontWeight.w700,
            },
            color: _toneColor(mark.tone) ?? base.color,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: base));
    }
    // Avoid unused warning if runes used for future grapheme-safe spans.
    assert(runes.isNotEmpty || text.isEmpty);

    return Text.rich(
      TextSpan(style: base, children: children),
      textAlign: TextAlign.start,
    );
  }

  Color? _toneColor(TheaterTextTone tone) {
    if (tone == TheaterTextTone.unknown) return null;
    final token = switch (tone) {
      TheaterTextTone.positive => 'positive',
      TheaterTextTone.danger => 'danger',
      TheaterTextTone.amber => 'amber',
      TheaterTextTone.muted => 'muted',
      TheaterTextTone.cold => 'cold',
      TheaterTextTone.brand => 'brand',
      TheaterTextTone.unknown => 'muted',
    };
    return resolveStageColorToken(token);
  }
}
