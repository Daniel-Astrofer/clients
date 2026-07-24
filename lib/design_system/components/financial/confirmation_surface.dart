import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Row model for financial confirmation / review surfaces.
class MovementConfirmationRow {
  final String label;
  final String value;
  final bool numeric;
  final bool technical;
  final bool emphasize;

  const MovementConfirmationRow({
    required this.label,
    required this.value,
    this.numeric = false,
    this.technical = false,
    this.emphasize = false,
  });
}

/// Hero confirmation layout: title, tabular amount, supporting fiat, detail rows.
class MovementConfirmationSurface extends StatelessWidget {
  final String title;
  final String amountLabel;
  final String supportingLabel;
  final List<MovementConfirmationRow> rows;
  final Widget? leading;
  final bool compactRows;

  const MovementConfirmationSurface({
    super.key,
    required this.title,
    required this.amountLabel,
    this.supportingLabel = '',
    required this.rows,
    this.leading,
    this.compactRows = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final titleFontSize = width < 360 ? 28.0 : 34.0;
        final amountFontSize = width < 360 ? 40.0 : 48.0;
        final ink = KeroseneBrandTokens.textPrimary;
        final muted = KeroseneBrandTokens.textMuted;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(height: 28),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.newsreader(
                color: ink,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w200,
                height: 1.12,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 28),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amountLabel,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: AppTypography.amountLarge.copyWith(
                  color: ink,
                  fontSize: amountFontSize,
                  height: 1.05,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            if (supportingLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                supportingLabel,
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 32),
            for (final row in rows)
              _MovementConfirmationDetailRow(
                row: row,
                compact: compactRows,
              ),
          ],
        );
      },
    );
  }
}

/// Compact row list without title/amount hero (for collapsible details).
class MovementConfirmationRows extends StatelessWidget {
  final List<MovementConfirmationRow> rows;
  final bool compact;

  const MovementConfirmationRows({
    super.key,
    required this.rows,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          _MovementConfirmationDetailRow(row: row, compact: compact),
      ],
    );
  }
}

class _MovementConfirmationDetailRow extends StatelessWidget {
  final MovementConfirmationRow row;
  final bool compact;

  const _MovementConfirmationDetailRow({
    required this.row,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final ink = KeroseneBrandTokens.textPrimary;
    final muted = KeroseneBrandTokens.textMuted;
    final border = KeroseneBrandTokens.border;
    final labelColor = row.emphasize ? ink : muted;
    final valueStyle = row.numeric || row.technical
        ? AppTypography.financial(
            color: ink,
            fontSize:
                row.emphasize ? (compact ? 15.0 : 16.0) : (compact ? 13.5 : 14),
            fontWeight: row.emphasize ? FontWeight.w700 : FontWeight.w600,
            height: 1.3,
          )
        : AppTypography.inter(
            color: ink,
            fontSize:
                row.emphasize ? (compact ? 15.0 : 16.0) : (compact ? 13.5 : 14),
            fontWeight: row.emphasize ? FontWeight.w700 : FontWeight.w400,
            height: 1.3,
          );

    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: row.emphasize ? border.withValues(alpha: 0) : border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 120 : 136,
            child: Text(
              // Sentence case — softer than bank micro-caps.
              row.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.inter(
                color: labelColor,
                fontSize: compact ? 12.5 : 13,
                fontWeight: row.emphasize ? FontWeight.w600 : FontWeight.w400,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                row.value,
                maxLines: row.technical ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: valueStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
