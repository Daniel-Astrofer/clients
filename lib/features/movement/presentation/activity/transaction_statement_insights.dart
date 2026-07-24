import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/movement/data/entities/statement_report.dart';
import 'package:kerosene/features/movement/providers/statement_insights_provider.dart';

Color get _primary => KeroseneBrandTokens.textPrimary;
Color get _onSurfaceVariant => KeroseneBrandTokens.textSecondary;
Color get _surfaceVariant => KeroseneBrandTokens.surfaceElevated;
Color get _surface => KeroseneBrandTokens.surface;
Color get _border => KeroseneBrandTokens.border;
Color get _surfaceContainerLow => KeroseneBrandTokens.surfaceHigh;
Color get _singleWalletColor => KeroseneBrandTokens.textMuted;
const _chartMinimumFraction = 0.055;
const _positive = AppColors.hexFF63FEA7;
const _negative = AppColors.hexFFFF6B6B;
const _neutralAccent = AppColors.hexFFFFCC6E;

class TransactionStatementInsights extends ConsumerStatefulWidget {
  const TransactionStatementInsights({super.key});

  @override
  ConsumerState<TransactionStatementInsights> createState() =>
      _TransactionStatementInsightsState();
}

class _TransactionStatementInsightsState
    extends ConsumerState<TransactionStatementInsights> {
  StatementReportPeriod _period = StatementReportPeriod.monthly;

  void _setPeriod(StatementReportPeriod period) {
    if (_period == period) return;
    HapticFeedback.selectionClick();
    setState(() => _period = period);
  }

  @override
  Widget build(BuildContext context) {
    final asyncReport = ref.watch(statementInsightsReportProvider(_period));

    return asyncReport.when(
      loading: () => const SizedBox(
        height: 280,
        child: Center(child: TorLoadingDots()),
      ),
      error: (error, _) => _SoftPanel(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            Icon(KeroseneIcons.warning,
                color: _onSurfaceVariant, size: 28),
            const SizedBox(height: 12),
            Text(
              context.tr.financialStatementLoadErrorTitle,
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                color: _primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ErrorTranslator.translate(context.tr, error.toString()),
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                color: _onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      data: (report) {
        final view = _InsightViewModel.from(report);
        return TweenAnimationBuilder<double>(
          key: ValueKey(
            'statement-report-${_period.name}-${report.loadedTransactionCount}-${report.walletCount}',
          ),
          tween: Tween(begin: 0, end: 1),
          duration: KeroseneMotion.duration(context, KeroseneMotion.slow),
          curve: KeroseneMotion.standard,
          builder: (context, progress, child) {
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - progress)),
                child: child,
              ),
            );
          },
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final kpis = _KpiSummaryPanel(report: report);
                final volume = _MovementVolumePanel(
                  view: view,
                  period: _period,
                  onPeriodChanged: _setPeriod,
                );
                final monthly = _MonthlyMovementPanel(
                  report: report,
                  selected: _period,
                  onChanged: _setPeriod,
                );
                final distribution = _FundDistributionPanel(view: view);

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      kpis,
                      const SizedBox(height: 18),
                      volume,
                      const SizedBox(height: 18),
                      monthly,
                      const SizedBox(height: 18),
                      distribution,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kpis,
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: volume),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: distribution),
                      ],
                    ),
                    const SizedBox(height: 18),
                    monthly,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _KpiSummaryPanel extends StatelessWidget {
  final StatementReport report;

  const _KpiSummaryPanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final hasMovement = report.includedTransactionCount > 0 ||
        report.incomingSats > 0 ||
        report.outgoingSats > 0;

    return _SoftPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(KeroseneIcons.chart,
                  color: _onSurfaceVariant, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr.financialStatementReportTitle,
                  style: AppTypography.inter(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                _pluralPt(
                  report.includedTransactionCount,
                  'tx',
                  'txs',
                ),
                style: AppTypography.inter(
                  color: _onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (report.isPartial) ...[
            const SizedBox(height: 12),
            const _PartialHistoryBanner(),
          ],
          if (!hasMovement) ...[
            const SizedBox(height: 14),
            Text(
              context.tr.financialStatementEmptyMessage,
              style: AppTypography.inter(
                color: _onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 420;
                final items = [
                  _KpiTile(
                    icon: KeroseneIcons.down,
                    label: context.tr.financialStatementInflows,
                    value: _formatBtc(report.incomingSats),
                    accent: _positive,
                  ),
                  _KpiTile(
                    icon: KeroseneIcons.up,
                    label: context.tr.financialStatementOutflows,
                    value: _formatBtc(report.outgoingSats),
                    accent: _negative,
                  ),
                  _KpiTile(
                    icon: KeroseneIcons.fee,
                    label: 'Taxas',
                    value: _formatBtc(report.totalFeesSats),
                    accent: _neutralAccent,
                    subtitle: report.serviceFeeSats > 0
                        ? 'rede ${_formatCompactSats(report.feeSats)} · svc ${_formatCompactSats(report.serviceFeeSats)}'
                        : null,
                  ),
                  _KpiTile(
                    icon: KeroseneIcons.trendUp,
                    label: context.tr.statementInsightNet,
                    value: _formatSignedBtc(report.netSats),
                    accent: report.netSats >= 0 ? _positive : _negative,
                  ),
                ];

                if (twoCol) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: items[0]),
                          const SizedBox(width: 10),
                          Expanded(child: items[1]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: items[2]),
                          const SizedBox(width: 10),
                          Expanded(child: items[3]),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      items[i],
                    ],
                  ],
                );
              },
            ),
            if (report.internalTransferSats > 0) ...[
              const SizedBox(height: 12),
              _SecondaryMetricRow(
                icon: KeroseneIcons.swap,
                label: context.tr.statementInsightInternalTransfers,
                value: _formatBtc(report.internalTransferSats),
              ),
            ],
            if (report.unclassifiedTransactionCount > 0) ...[
              const SizedBox(height: 10),
              _SecondaryMetricRow(
                icon: KeroseneIcons.info,
                label: _pluralPt(
                  report.unclassifiedTransactionCount,
                  'sem carteira identificada',
                  'sem carteira identificada',
                ),
                value: '',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PartialHistoryBanner extends StatelessWidget {
  const _PartialHistoryBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _neutralAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _neutralAccent.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(KeroseneIcons.info, color: _neutralAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Histórico parcial — o período selecionado pode exceder o que está carregado no dispositivo.',
                style: AppTypography.inter(
                  color: _onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.inter(
                      color: _onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.financial(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.inter(
                  color: _onSurfaceVariant.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecondaryMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SecondaryMetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _onSurfaceVariant, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.inter(
              color: _onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: AppTypography.financial(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _MovementVolumePanel extends StatelessWidget {
  final _InsightViewModel view;
  final StatementReportPeriod period;
  final ValueChanged<StatementReportPeriod> onPeriodChanged;

  const _MovementVolumePanel({
    required this.view,
    required this.period,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      minHeight: 400,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.financialStatementMovementVolume,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    color: _primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                ),
              ),
              _RangeSelector(selected: period, onChanged: onPeriodChanged),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _MovementBarChart(view: view)),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final StatementReportPeriod selected;
  final ValueChanged<StatementReportPeriod> onChanged;

  const _RangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<StatementReportPeriod>(
      initialValue: selected,
      color: _surfaceContainerLow,
      elevation: 10,
      tooltip: context.tr.financialStatementPeriodTooltip,
      onSelected: onChanged,
      itemBuilder: (context) {
        return StatementReportPeriod.values
            .map(
              (value) => PopupMenuItem(
                value: value,
                child: Text(
                  _rangeLabel(context, value),
                  style: AppTypography.inter(
                    color: value == selected ? _primary : _onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _border.withValues(alpha: 0.9)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _rangeLabel(context, selected),
                style: AppTypography.inter(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                KeroseneIcons.chevronDown,
                color: _onSurfaceVariant,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementBarChart extends StatefulWidget {
  final _InsightViewModel view;

  const _MovementBarChart({required this.view});

  @override
  State<_MovementBarChart> createState() => _MovementBarChartState();
}

class _MovementBarChartState extends State<_MovementBarChart> {
  final ScrollController _barController = ScrollController();
  final ScrollController _labelController = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _barController.addListener(() => _sync(_barController, _labelController));
    _labelController.addListener(() => _sync(_labelController, _barController));
  }

  @override
  void dispose() {
    _barController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncing || !source.hasClients || !target.hasClients) return;
    final nextOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - nextOffset).abs() < 0.5) return;
    _syncing = true;
    target.jumpTo(nextOffset);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final axisValues = _axisValues(view.axisMaxSats);
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'movement-volume-${view.buckets.map((bucket) => bucket.values.map((value) => value.sats).join(':')).join('|')}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: KeroseneMotion.duration(context, KeroseneMotion.slow),
      curve: KeroseneMotion.standard,
      builder: (context, progress, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = math.max<double>(
              constraints.maxWidth - 48,
              view.buckets.length * math.max(44.0, view.walletCount * 18),
            );
            return Stack(
              children: [
                Positioned.fill(
                  right: 0,
                  bottom: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            axisValues.length,
                            (_) => Container(
                              height: 1,
                              color: _surfaceVariant.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: axisValues
                              .map(
                                (value) => Text(
                                  _formatCompactSats(value),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.financial(
                                    color: _onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  right: 48,
                  bottom: 28,
                  child: SingleChildScrollView(
                    controller: _barController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final bucket in view.buckets)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _WalletBarGroup(
                                  bucket: bucket,
                                  axisMaxSats: view.axisMaxSats,
                                  progress: progress,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 48,
                  bottom: 0,
                  height: 22,
                  child: SingleChildScrollView(
                    controller: _labelController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: Row(
                        children: [
                          for (final bucket in view.buckets)
                            Expanded(
                              child: Text(
                                bucket.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.financial(
                                  color: _onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WalletBarGroup extends StatelessWidget {
  final _MovementBucket bucket;
  final int axisMaxSats;
  final double progress;

  const _WalletBarGroup({
    required this.bucket,
    required this.axisMaxSats,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < bucket.values.length; index++) ...[
          if (index > 0) const SizedBox(width: 3),
          Expanded(
            child: FractionallySizedBox(
              heightFactor:
                  _barFraction(bucket.values[index].sats, axisMaxSats) *
                      progress,
              alignment: Alignment.bottomCenter,
              child: _GradientBar(
                topColor: bucket.values[index].color,
                bottomColor: bucket.values[index].color.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientBar extends StatelessWidget {
  final Color topColor;
  final Color bottomColor;

  const _GradientBar({required this.topColor, required this.bottomColor});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [bottomColor, topColor],
        ),
      ),
    );
  }
}

class _MonthlyMovementPanel extends StatelessWidget {
  final StatementReport report;
  final StatementReportPeriod selected;
  final ValueChanged<StatementReportPeriod> onChanged;

  const _MonthlyMovementPanel({
    required this.report,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      child: Column(
        children: [
          Text(
            context.tr.financialStatementMonthlyMovement,
            textAlign: TextAlign.center,
            style: AppTypography.newsreader(
              color: _primary,
              fontSize: 28,
              fontWeight: FontWeight.w200,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 13),
          _PeriodTabs(selected: selected, onChanged: onChanged),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 40,
            runSpacing: 20,
            children: [
              _MonthlyMetric(
                icon: KeroseneIcons.up,
                label: context.tr.financialStatementOutflows,
                value: _formatBtc(report.outgoingSats),
              ),
              _MonthlyMetric(
                icon: KeroseneIcons.down,
                label: context.tr.financialStatementInflows,
                value: _formatBtc(report.incomingSats),
              ),
              if (report.totalFeesSats > 0)
                _MonthlyMetric(
                  icon: KeroseneIcons.fee,
                  label: 'Taxas',
                  value: _formatBtc(report.totalFeesSats),
                ),
              _MonthlyMetric(
                icon: KeroseneIcons.trendUp,
                label: context.tr.statementInsightNet,
                value: _formatSignedBtc(report.netSats),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final StatementReportPeriod selected;
  final ValueChanged<StatementReportPeriod> onChanged;

  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: StatementReportPeriod.values.map((period) {
        final active = selected == period;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(period),
          child: AnimatedOpacity(
            opacity: active ? 1 : 0.5,
            duration: KeroseneMotion.duration(context, KeroseneMotion.short),
            child: Text(
              _periodTabLabel(context, period).toUpperCase(),
              style: AppTypography.inter(
                color: active ? _primary : _onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthlyMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MonthlyMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _onSurfaceVariant, size: 14),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.inter(
                  color: _onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.financial(
              color: _primary,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundDistributionPanel extends StatelessWidget {
  final _InsightViewModel view;

  const _FundDistributionPanel({required this.view});

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      minHeight: 400,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr.financialStatementFundDistribution,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              color: _primary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(child: _DistributionDonut(view: view)),
          ),
          const SizedBox(height: 16),
          for (final segment in view.distribution) _DistributionLegend(segment),
        ],
      ),
    );
  }
}

class _DistributionDonut extends StatelessWidget {
  final _InsightViewModel view;

  const _DistributionDonut({required this.view});

  @override
  Widget build(BuildContext context) {
    final dominant = view.dominantDistributionSegment;
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'fund-distribution-${view.distribution.map((segment) => segment.visualSats).join('|')}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: KeroseneMotion.duration(context, KeroseneMotion.slow),
      curve: KeroseneMotion.standard,
      builder: (context, progress, _) {
        return AnimatedScale(
          scale: 1 + (math.sin(progress * math.pi) * 0.03),
          duration: KeroseneMotion.duration(context, KeroseneMotion.short),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(214),
                painter: _DistributionDonutPainter(
                  segments: view.distribution,
                  progress: progress,
                ),
              ),
              SizedBox(
                width: 132,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dominant.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.financial(
                        color: _onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPercent(dominant.percent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.financial(
                        color: _primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DistributionDonutPainter extends CustomPainter {
  final List<_DistributionSegment> segments;
  final double progress;

  const _DistributionDonutPainter({
    required this.segments,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(22);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..color = _surfaceVariant.withValues(alpha: 0.22);

    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, basePaint);

    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.visualSats,
    );
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.visualSats <= 0) continue;
      final sweep = (segment.visualSats / total) * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt
        ..color = segment.color;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionDonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.segments != segments;
  }
}

class _DistributionLegend extends StatelessWidget {
  final _DistributionSegment segment;

  const _DistributionLegend(this.segment);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: segment.color,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    color: _onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (segment.isDominant) ...[
                  const SizedBox(height: 4),
                  const _DominantSliceBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBtc(segment.sats),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.financial(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${segment.percent.toStringAsFixed(1)}%',
                style: AppTypography.financial(
                  color: _onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DominantSliceBadge extends StatelessWidget {
  const _DominantSliceBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.hexFF63FEA7.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: AppColors.hexFF63FEA7.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(KeroseneIcons.trendUp,
                color: AppColors.hexFF63FEA7, size: 12),
            const SizedBox(width: 5),
            Text(
              'Maior fatia',
              style: AppTypography.inter(
                color: AppColors.hexFF63FEA7,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (minHeight != null) {
      return SizedBox(height: minHeight, child: panel);
    }
    return panel;
  }
}

class _InsightViewModel {
  final List<_MovementBucket> buckets;
  final List<_DistributionSegment> distribution;
  final int axisMaxSats;
  final int walletCount;
  final String dominantWalletName;

  const _InsightViewModel({
    required this.buckets,
    required this.distribution,
    required this.axisMaxSats,
    required this.walletCount,
    required this.dominantWalletName,
  });

  _DistributionSegment get dominantDistributionSegment {
    if (distribution.isEmpty) {
      return _DistributionSegment(
        label: dominantWalletName,
        sats: 0,
        visualSats: 0,
        percent: 0,
        color: _singleWalletColor,
        isDominant: true,
      );
    }
    return distribution.reduce((a, b) {
      if (b.sats != a.sats) return b.sats > a.sats ? b : a;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase()) <= 0
          ? a
          : b;
    });
  }

  factory _InsightViewModel.from(StatementReport report) {
    final colorsByWalletId = <String, Color>{};
    for (var index = 0; index < report.wallets.length; index++) {
      colorsByWalletId[report.wallets[index].id] =
          report.wallets.length == 1 ? _singleWalletColor : _walletColor(index);
    }

    final buckets = [
      for (final bucket in report.buckets)
        _MovementBucket(
          label: bucket.label,
          values: [
            for (final value in bucket.values)
              _WalletBucketValue(
                sats: value.sats,
                color: colorsByWalletId[value.walletId] ?? _singleWalletColor,
              ),
          ],
        ),
    ];

    final dominantId =
        report.distribution.isEmpty ? null : report.distribution.first.walletId;

    final distribution = [
      for (final segment in report.distribution)
        _DistributionSegment(
          label: segment.label,
          sats: segment.sats,
          visualSats: segment.visualSats,
          percent: segment.percent,
          color: colorsByWalletId[segment.walletId] ?? _singleWalletColor,
          isDominant:
              report.totalBalanceSats > 0 && segment.walletId == dominantId,
        ),
    ];

    return _InsightViewModel(
      buckets: buckets,
      distribution: distribution,
      axisMaxSats: report.axisMaxSats,
      walletCount: report.walletCount,
      dominantWalletName: report.dominantWalletName,
    );
  }
}

class _MovementBucket {
  final String label;
  final List<_WalletBucketValue> values;

  const _MovementBucket({required this.label, required this.values});
}

class _WalletBucketValue {
  final int sats;
  final Color color;

  const _WalletBucketValue({required this.sats, required this.color});
}

class _DistributionSegment {
  final String label;
  final int sats;
  final int visualSats;
  final double percent;
  final Color color;
  final bool isDominant;

  const _DistributionSegment({
    required this.label,
    required this.sats,
    required this.visualSats,
    required this.percent,
    required this.color,
    required this.isDominant,
  });
}

List<int> _axisValues(int maxSats) {
  final step = math.max(1, (maxSats / 5).ceil());
  return List.generate(6, (index) => math.max(0, maxSats - (step * index)));
}

double _barFraction(int sats, int axisMaxSats) {
  if (sats <= 0) return 0;
  return math.max(_chartMinimumFraction, sats / math.max(1, axisMaxSats));
}

Color _walletColor(int index) {
  return switch (index % 6) {
    0 => _primary,
    1 => AppColors.hexFF63FEA7,
    2 => AppColors.hexFFFFCC6E,
    3 => AppColors.hexFF8A8A8E,
    4 => AppColors.hexFFC4C4C4,
    _ => AppColors.hexFF444748,
  };
}

String _rangeLabel(BuildContext context, StatementReportPeriod period) {
  return switch (period) {
    StatementReportPeriod.monthly =>
      context.tr.financialStatementPeriodLastSixMonths,
    StatementReportPeriod.weekly =>
      context.tr.financialStatementPeriodYearToDate,
    StatementReportPeriod.annual => context.tr.financialStatementPeriodOneYear,
  };
}

String _periodTabLabel(BuildContext context, StatementReportPeriod period) {
  return switch (period) {
    StatementReportPeriod.monthly => context.tr.financialStatementPeriodMonthly,
    StatementReportPeriod.weekly => context.tr.financialStatementPeriodWeekly,
    StatementReportPeriod.annual => context.tr.financialStatementPeriodAnnual,
  };
}

String _formatCompactSats(int sats) {
  final abs = sats.abs();
  if (abs >= 100000000) {
    final btc = abs / 100000000.0;
    return '${btc.toStringAsFixed(btc >= 10 ? 0 : 1)} BTC';
  }
  if (abs >= 1000) {
    return '${(abs / 1000).round()}k';
  }
  return '$abs';
}

String _formatBtc(int sats) {
  final abs = sats.abs();
  if (abs == 0) return '0 BTC';
  if (abs < 10000) return '$abs sats';
  final btc = abs / 100000000.0;
  return '${btc.toStringAsFixed(btc >= 1 ? 4 : 6)} BTC';
}

String _formatSignedBtc(int sats) {
  if (sats == 0) return '0 BTC';
  final sign = sats > 0 ? '+' : '−';
  return '$sign${_formatBtc(sats.abs())}';
}

String _formatPercent(double percent) {
  if (percent.isNaN || percent.isInfinite || percent <= 0) return '0%';
  if ((percent - percent.round()).abs() < 0.05) {
    return '${percent.round()}%';
  }
  return '${percent.toStringAsFixed(1)}%';
}

String _pluralPt(int count, String singular, String plural) {
  final unit = count == 1 ? singular : plural;
  return '$count $unit';
}
