import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:intl/intl.dart' as intl;
import 'package:kerosene/core/services/bitcoin_market_chart_service.dart';
import 'package:kerosene/features/home/presentation/providers/home_bitcoin_market_chart_provider.dart';
import 'home_bitcoin_market_chart_motion.dart';
import '../screens/home_screen_dependencies.dart';
import '../screens/home_screen.dart';

class HomeBitcoinMarketChartCard extends ConsumerStatefulWidget {
  const HomeBitcoinMarketChartCard({super.key});

  @override
  ConsumerState<HomeBitcoinMarketChartCard> createState() =>
      _HomeBitcoinMarketChartCardState();
}

class _HomeBitcoinMarketChartCardState
    extends ConsumerState<HomeBitcoinMarketChartCard> {
  static const EdgeInsets _chartPadding = EdgeInsets.fromLTRB(46, 10, 8, 24);
  /// Stroke was 2.4 → −30% ≈ 1.68
  static const double _lineStrokeWidth = 1.68;
  /// Glow stroke was 5 → −30% ≈ 3.5; alpha was 0.18 → −40% ≈ 0.108
  static const double _lineGlowWidth = 3.5;
  static const double _lineGlowAlpha = 0.108;

  int? _selectedIndex;
  DateTime? _lastSelectionHapticAt;
  BitcoinMarketChartSnapshot? _lastGoodSnapshot;
  Offset? _panStartLocal;
  bool _scrubbing = false;

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(homeBitcoinMarketChartProvider);
    final selectedRange = ref.watch(homeBitcoinMarketChartRangeProvider);
    final customDays = ref.watch(homeBitcoinMarketChartCustomDaysProvider);

    ref.listen<BitcoinMarketChartRequest>(
      homeBitcoinMarketChartRequestProvider,
      (previous, next) {
        if (previous != null && previous != next && mounted) {
          setState(() => _selectedIndex = null);
        }
      },
    );

    ref.listen(homeBitcoinMarketChartProvider, (previous, next) {
      next.whenData((snapshot) {
        if (snapshot.points.isNotEmpty) {
          _lastGoodSnapshot = snapshot;
        }
      });
    });

    // Keep the current chart while a new range loads — never flash the mock loader.
    final activeRequest = ref.watch(homeBitcoinMarketChartRequestProvider);
    final snapshot = chartAsync.asData?.value ?? _lastGoodSnapshot;
    if (snapshot != null && snapshot.points.isNotEmpty) {
      _lastGoodSnapshot = snapshot;
      final awaitingNewRange =
          !_sameChartSeries(snapshot.request, activeRequest);
      return _buildLoadedCard(
        context,
        snapshot: snapshot,
        selectedRange: selectedRange,
        customDays: customDays,
        awaitingNewRange: awaitingNewRange,
      );
    }

    if (chartAsync.hasError) {
      return _buildErrorCard(
        context,
        selectedRange: selectedRange,
        customDays: customDays,
      );
    }

    // First open only — no previous series yet.
    return _buildLoadingCard(
      context,
      selectedRange: selectedRange,
      customDays: customDays,
    );
  }

  Widget _buildLoadedCard(
    BuildContext context, {
    required BitcoinMarketChartSnapshot snapshot,
    required BitcoinMarketChartRange selectedRange,
    required int? customDays,
    bool awaitingNewRange = false,
  }) {
    final points = snapshot.points;
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPoint = _selectedPoint(snapshot);
    final displayPoint =
        selectedPoint ?? (points.isNotEmpty ? points.last : null);
    final isPositive = snapshot.isPositivePeriod;
    final trendColor = isPositive ? homePositiveColor : AppColors.hexFFFF5A67;


    final displayPrice = displayPoint?.price ?? snapshot.lastPrice;
    final money = ref.watch(moneyFormatConfigProvider);

    // Stable shell key so range changes don't remount the whole card into loading.
    return _ChartCardShell(
      key: const ValueKey('btc-chart-shell'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bitcoin',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontFamily: AppTypography.fontFamily,
                        fontSize: homeFontSize(12),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: homeSize(6)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: HomeBitcoinPriceTicker(
                        price: displayPrice,
                        formatter: (value) => money.format(
                          amount: value,
                          currency: snapshot.request.quoteCurrency,
                          decimalPlaces: 2,
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: AppTypography.financialFontFamily,
                          fontSize: homeFontSize(28),
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: homeSize(8)),

                  ],
                ),
              ),
              SizedBox(width: homeSize(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox.shrink(),
                  SizedBox(height: homeSize(6)),
                  Text(
                    snapshot.request.pairLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontFamily: AppTypography.financialFontFamily,
                      fontSize: homeFontSize(10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                ],
              ),
            ],
          ),
          SizedBox(height: homeSize(14)),
          SizedBox(
            height: homeBitcoinChartHeight(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final selectedX = _selectedX(snapshot, size);
                // Single detector: pan = scrub; fast fling without scrub = cycle range.
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _panStartLocal = event.localPosition;
                    _scrubbing = false;
                    _selectPoint(event.localPosition, size, snapshot);
                  },
                  onPointerMove: (event) {
                    final start = _panStartLocal;
                    if (start != null &&
                        (event.localPosition - start).distance > 6) {
                      _scrubbing = true;
                    }
                    _selectPoint(event.localPosition, size, snapshot);
                  },
                  onPointerUp: (_) {
                    _panStartLocal = null;
                  },
                  onPointerCancel: (_) {
                    _panStartLocal = null;
                    _scrubbing = false;
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      // Fling to change range only when not scrubbing the series.
                      if (_scrubbing || v.abs() < 900) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIndex = null);
                      cycleHomeBitcoinChartRange(ref, forward: v < 0);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: HomeBitcoinChartDrawOn(
                              seriesKey: Object.hash(
                                snapshot.request.symbol,
                                snapshot.request.rangeLabel,
                                snapshot.request.customStart,
                                points.length > 2 ? points.first.timeMillis : 0,
                              ),
                            builder: (context, progress) {
                              return CustomPaint(
                                painter: _BitcoinMarketChartPainter(
                                  snapshot: snapshot,
                                  selectedIndex: _safeSelectedIndex(snapshot),
                                  padding: _chartPadding,
                                  lineColor: trendColor,
                                  drawProgress: progress,
                                  lineStrokeWidth: _lineStrokeWidth,
                                  lineGlowWidth: _lineGlowWidth,
                                  lineGlowAlpha: _lineGlowAlpha,
                                  labelColor:
                                      Colors.white.withValues(alpha: 0.42),
                                  priceLabelFormatter: (value) => _compactPrice(
                                    value,
                                    snapshot.request.quoteCurrency,
                                  ),
                                  timeLabelFormatter: (time) => _timeLabel(
                                    time,
                                    snapshot.request.range,
                                    locale: Localizations.localeOf(context)
                                        .toLanguageTag(),
                                  ),
                                ),
                              );
                            },
                          ),
                         ),
                        ),
                        if (awaitingNewRange)
                          Positioned(
                            right: homeSize(8),
                            top: homeSize(4),
                            child: SizedBox(
                              width: homeSize(12),
                              height: homeSize(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        if (selectedPoint != null && selectedX != null)
                          Positioned(
                            left: _tooltipLeft(selectedX, size.width),
                            top: 0,
                            child: _ChartTooltip(
                              price: money.format(
                                amount: selectedPoint.price,
                                currency: snapshot.request.quoteCurrency,
                                decimalPlaces: 2,
                              ),
                              time: _tooltipTime(
                                selectedPoint.time,
                                snapshot.request.range,
                                locale: Localizations.localeOf(context)
                                    .toLanguageTag(),
                              ),
                              accent: trendColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: homeSize(14)),
          _RangeSelector(
            selectedRange: selectedRange,
            customDays: customDays,
            accent: trendColor,
            onCustomTap: () => _openCustomDaysSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(
    BuildContext context, {
    required BitcoinMarketChartRange selectedRange,
    required int? customDays,
  }) {
    return _ChartCardShell(
      key: ValueKey('btc-chart-loading-${selectedRange.label}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(width: homeSize(82), height: homeSize(12)),
                    SizedBox(height: homeSize(10)),
                    _SkeletonBlock(width: homeSize(188), height: homeSize(28)),
                  ],
                ),
              ),
              _SkeletonBlock(width: homeSize(74), height: homeSize(24)),
            ],
          ),
          SizedBox(height: homeSize(18)),
          SizedBox(
            height: homeBitcoinChartHeight(context),
            child: HomeBitcoinChartAmbientPulse(
              child: CustomPaint(
                painter: _BitcoinLoadingChartPainter(
                  padding: _chartPadding,
                  lineColor: homePositiveColor.withValues(alpha: 0.4),
                  gridColor: AppColors.hexFF2A2A2A,
                ),
              ),
            ),
          ),
          SizedBox(height: homeSize(14)),
          _RangeSelector(
            selectedRange: selectedRange,
            customDays: customDays,
            accent: homePositiveColor,
            onCustomTap: () => _openCustomDaysSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context, {
    required BitcoinMarketChartRange selectedRange,
    required int? customDays,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.invalidate(homeBitcoinMarketChartProvider);
      },
      child: _ChartCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bitcoin',
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.fontFamily,
                fontSize: homeFontSize(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: homeSize(22)),
            Container(
              height: homeBitcoinChartHeight(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(homeSize(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr.homeChartUnavailable,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontFamily: AppTypography.fontFamily,
                      fontSize: homeFontSize(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: homeSize(6)),
                  Text(
                    context.tr.homeChartRetry,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontFamily: AppTypography.fontFamily,
                      fontSize: homeFontSize(12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: homeSize(14)),
            _RangeSelector(
              selectedRange: selectedRange,
              customDays: customDays,
              accent: Colors.white54,
              onCustomTap: () => _openCustomDaysSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomDaysSheet(BuildContext context) async {
    final current =
        ref.read(homeBitcoinMarketChartCustomDaysProvider) ?? 90;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.hexFF0E0E0E,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(homeSize(16))),
      ),
      builder: (context) {
        return _CustomDaysSheet(initialDays: current.clamp(2, 730));
      },
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    ref.read(homeBitcoinMarketChartCustomDaysProvider.notifier).state = picked;
    // Align preset chip to nearest window for label consistency.
    ref.read(homeBitcoinMarketChartRangeProvider.notifier).state =
        picked <= 3
            ? BitcoinMarketChartRange.threeDays
            : picked <= 7
                ? BitcoinMarketChartRange.oneWeek
                : picked <= 31
                    ? BitcoinMarketChartRange.oneMonth
                    : picked <= 90
                        ? BitcoinMarketChartRange.ninetyDays
                        : picked <= 366
                            ? BitcoinMarketChartRange.oneYear
                            : BitcoinMarketChartRange.all;
  }

  BitcoinMarketChartPoint? _selectedPoint(BitcoinMarketChartSnapshot snapshot) {
    final index = _safeSelectedIndex(snapshot);
    if (index == null) return null;
    return snapshot.points[index];
  }

  int? _safeSelectedIndex(BitcoinMarketChartSnapshot snapshot) {
    final selected = _selectedIndex;
    if (selected == null || snapshot.points.isEmpty) return null;
    return selected.clamp(0, snapshot.points.length - 1).toInt();
  }

  void _selectPoint(
    Offset localPosition,
    Size size,
    BitcoinMarketChartSnapshot snapshot,
  ) {
    if (snapshot.points.isEmpty) return;
    final plotWidth = size.width - _chartPadding.left - _chartPadding.right;
    if (plotWidth <= 0) return;
    // Allow scrubbing slightly outside the plot horizontally (easier drag).
    final raw = (localPosition.dx - _chartPadding.left) / plotWidth;
    final normalized = raw.clamp(0.0, 1.0).toDouble();
    final nextIndex = (normalized * (snapshot.points.length - 1)).round();
    if (_selectedIndex != nextIndex) {
      _selectionHaptic();
      setState(() => _selectedIndex = nextIndex);
    } else if (_selectedIndex == null) {
      setState(() => _selectedIndex = nextIndex);
    }
  }

  void _selectionHaptic() {
    final now = DateTime.now();
    final last = _lastSelectionHapticAt;
    if (last != null && now.difference(last).inMilliseconds < 48) return;
    _lastSelectionHapticAt = now;
    HapticFeedback.selectionClick();
  }

  double? _selectedX(BitcoinMarketChartSnapshot snapshot, Size size) {
    final index = _safeSelectedIndex(snapshot);
    if (index == null || snapshot.points.length < 2) return null;
    final plotWidth = size.width - _chartPadding.left - _chartPadding.right;
    if (plotWidth <= 0) return null;
    return _chartPadding.left +
        (index / (snapshot.points.length - 1)) * plotWidth;
  }

  double _tooltipLeft(double selectedX, double width) {
    const tooltipWidth = 132.0;
    return (selectedX - tooltipWidth / 2)
        .clamp(
          _chartPadding.left,
          math.max(_chartPadding.left, width - tooltipWidth),
        )
        .toDouble();
  }

  /// Ignore [degraded] flag — service may downgrade limits without a UI wait.
  bool _sameChartSeries(
    BitcoinMarketChartRequest a,
    BitcoinMarketChartRequest b,
  ) {
    return a.symbol == b.symbol &&
        a.quoteCurrency == b.quoteCurrency &&
        a.range == b.range &&
        a.customStart == b.customStart &&
        a.customEnd == b.customEnd;
  }
}



class _ChartCardShell extends StatelessWidget {
  final Widget child;
  const _ChartCardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(homeSize(18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(homeSize(20)),
        child: child,
      ),
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  final BitcoinMarketChartRange selectedRange;
  final int? customDays;
  final Color accent;
  final VoidCallback onCustomTap;

  const _RangeSelector({
    required this.selectedRange,
    required this.customDays,
    required this.accent,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Horizontal chips — always visible; swipeable list for more presets.
    final presets = BitcoinMarketChartRange.values;
    return SizedBox(
      height: homeSize(36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: homeSize(4)),
        itemBuilder: (context, index) {
          if (index == presets.length) {
            final selected = customDays != null;
            return _RangeChip(
              label: customDays != null ? '${customDays}D' : context.tr.homeChartCustom,
              selected: selected,
              accent: accent,
              onTap: onCustomTap,
            );
          }
          final range = presets[index];
          final selected = customDays == null && range == selectedRange;
          return _RangeChip(
            label: range.label,
            selected: selected,
            accent: accent,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(homeBitcoinMarketChartCustomDaysProvider.notifier).state =
                  null;
              ref.read(homeBitcoinMarketChartRangeProvider.notifier).state =
                  range;
            },
          );
        },
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(homeSize(8)),
        child: AnimatedContainer(
          duration: KeroseneMotion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: homeSize(12),
            vertical: homeSize(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.45),
              fontFamily: AppTypography.fontFamily,
              fontSize: homeFontSize(11),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDaysSheet extends StatefulWidget {
  final int initialDays;
  const _CustomDaysSheet({required this.initialDays});

  @override
  State<_CustomDaysSheet> createState() => _CustomDaysSheetState();
}

class _CustomDaysSheetState extends State<_CustomDaysSheet> {
  late double _days;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days.round().clamp(2, 730);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          homeSize(20),
          homeSize(16),
          homeSize(20),
          homeSize(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr.homeChartCustomPeriod,
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.fontFamily,
                fontSize: homeFontSize(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: homeSize(8)),
            Text(
              'Últimos $days dias',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontFamily: AppTypography.financialFontFamily,
                fontSize: homeFontSize(14),
              ),
            ),
            Slider(
              value: _days.clamp(2, 730),
              min: 2,
              max: 730,
              divisions: 145,
              activeColor: homePositiveColor,
              onChanged: (v) => setState(() => _days = v),
            ),
            Wrap(
              spacing: homeSize(8),
              children: [
                for (final d in const [7, 30, 90, 180, 365])
                  ActionChip(
                    label: Text('${d}d'),
                    onPressed: () => setState(() => _days = d.toDouble()),
                  ),
              ],
            ),
            SizedBox(height: homeSize(12)),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(days),
              child: Text(context.tr.homeChartApply),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  final String price;
  final String time;
  final Color accent;

  const _ChartTooltip({
    required this.price,
    required this.time,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: homeSize(9),
          vertical: homeSize(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              price,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.financialFontFamily,
                fontSize: homeFontSize(11),
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            SizedBox(height: homeSize(4)),
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontFamily: AppTypography.financialFontFamily,
                fontSize: homeFontSize(9),
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBlock({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(homeSize(8)),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _BitcoinMarketChartPainter extends CustomPainter {
  final BitcoinMarketChartSnapshot snapshot;
  final int? selectedIndex;
  final EdgeInsets padding;
  final Color lineColor;
  final double drawProgress;
  final double lineStrokeWidth;
  final double lineGlowWidth;
  final double lineGlowAlpha;
  final Color labelColor;
  final String Function(double value) priceLabelFormatter;
  final String Function(DateTime time) timeLabelFormatter;

  const _BitcoinMarketChartPainter({
    required this.snapshot,
    required this.selectedIndex,
    required this.padding,
    required this.lineColor,
    required this.drawProgress,
    required this.lineStrokeWidth,
    required this.lineGlowWidth,
    required this.lineGlowAlpha,
    required this.labelColor,
    required this.priceLabelFormatter,
    required this.timeLabelFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = snapshot.points;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0, size.width - padding.left - padding.right),
      math.max(0, size.height - padding.top - padding.bottom),
    );
    if (plotRect.width <= 0 || plotRect.height <= 0) return;

    final minPrice = snapshot.lowPrice;
    final maxPrice = snapshot.highPrice;
    final spread = math.max(0.01, maxPrice - minPrice);
    final top = maxPrice + spread * 0.06;
    final bottom = minPrice - spread * 0.06;
    final adjustedSpread = math.max(0.01, top - bottom);

    // Labels only — no background grid lines.
    _drawLabels(canvas, size, plotRect, bottom, top);
    if (points.length < 2) return;

    final offsets = <Offset>[
      for (var index = 0; index < points.length; index++)
        Offset(
          plotRect.left + (index / (points.length - 1)) * plotRect.width,
          plotRect.top +
              ((top - points[index].price) / adjustedSpread) * plotRect.height,
        ),
    ];

    final path = _straightPath(offsets);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLen =
        metrics.fold<double>(0, (sum, m) => sum + m.length);
    final visibleLen = totalLen * drawProgress.clamp(0.0, 1.0);

    // Fill under the (partial) path.
    final extract = _extractPath(metrics, visibleLen);
    if (extract != null) {
      final fillPath = Path.from(extract)
        ..lineTo(extract.getBounds().right, plotRect.bottom)
        ..lineTo(plotRect.left, plotRect.bottom)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.16),
              lineColor.withValues(alpha: 0.01),
            ],
          ).createShader(plotRect),
      );

      // Soft glow (reduced)
      canvas.drawPath(
        extract,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineGlowWidth
          ..strokeCap = StrokeCap.round
          ..color = lineColor.withValues(alpha: lineGlowAlpha)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
      );

      canvas.drawPath(
        extract,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = lineColor
          ..isAntiAlias = true,
      );
    }

    final selected = selectedIndex;
    if (selected != null &&
        selected >= 0 &&
        selected < offsets.length &&
        drawProgress > 0.92) {
      _drawSelection(canvas, plotRect, offsets[selected], lineColor);
    }
  }

  Path? _extractPath(List<ui.PathMetric> metrics, double length) {
    if (length <= 0) return null;
    final out = Path();
    var remaining = length;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      out.addPath(metric.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return out;
  }

  void _drawLabels(
    Canvas canvas,
    Size size,
    Rect plotRect,
    double bottom,
    double top,
  ) {

    final labelStyle = TextStyle(
      color: labelColor,
      fontFamily: AppTypography.financialFontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final timeStyle =
        labelStyle.copyWith(color: labelColor.withValues(alpha: 0.82));
    final labels = _timeLabels(plotRect.width);
    for (final item in labels) {
      final painter = TextPainter(
        text: TextSpan(text: timeLabelFormatter(item.time), style: timeStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 72);
      final x = plotRect.left + item.position * plotRect.width;
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2)
              .clamp(plotRect.left, plotRect.right - painter.width)
              .toDouble(),
          size.height - painter.height,
        ),
      );
    }
  }



  List<_ChartTimeLabel> _timeLabels(double width) {
    final points = snapshot.points;
    if (points.isEmpty) return const [];
    if (points.length == 1) {
      return [_ChartTimeLabel(position: 0, time: points.first.time)];
    }
    final count = (width / 92).clamp(2, 6).round();
    return [
      for (var index = 0; index < count; index++)
        _ChartTimeLabel(
          position: index / math.max(1, count - 1),
          time: points[
                  ((index / math.max(1, count - 1)) * (points.length - 1))
                      .round()]
              .time,
        ),
    ];
  }

  void _drawSelection(
    Canvas canvas,
    Rect plotRect,
    Offset offset,
    Color accent,
  ) {
    final selectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(offset.dx, plotRect.top),
      Offset(offset.dx, plotRect.bottom),
      selectionPaint,
    );
    canvas.drawCircle(offset, 5.5, Paint()..color = AppColors.hexFF0E0E0E);
    canvas.drawCircle(offset, 4.0, Paint()..color = Colors.white);
    canvas.drawCircle(offset, 2.6, Paint()..color = accent);
  }

  Path _straightPath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var index = 1; index < offsets.length; index++) {
      path.lineTo(offsets[index].dx, offsets[index].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _BitcoinMarketChartPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.lineStrokeWidth != lineStrokeWidth ||
        oldDelegate.lineGlowAlpha != lineGlowAlpha ||
        oldDelegate.labelColor != labelColor;
  }
}

class _BitcoinLoadingChartPainter extends CustomPainter {
  final EdgeInsets padding;
  final Color lineColor;
  final Color gridColor;

  const _BitcoinLoadingChartPainter({
    required this.padding,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0, size.width - padding.left - padding.right),
      math.max(0, size.height - padding.top - padding.bottom),
    );
    final path = Path()
      ..moveTo(plotRect.left, plotRect.bottom - plotRect.height * 0.24)
      ..cubicTo(
        plotRect.left + plotRect.width * 0.18,
        plotRect.bottom - plotRect.height * 0.10,
        plotRect.left + plotRect.width * 0.30,
        plotRect.top + plotRect.height * 0.68,
        plotRect.left + plotRect.width * 0.44,
        plotRect.top + plotRect.height * 0.48,
      )
      ..cubicTo(
        plotRect.left + plotRect.width * 0.58,
        plotRect.top + plotRect.height * 0.28,
        plotRect.left + plotRect.width * 0.70,
        plotRect.top + plotRect.height * 0.34,
        plotRect.left + plotRect.width * 0.82,
        plotRect.top + plotRect.height * 0.22,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _BitcoinLoadingChartPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _ChartTimeLabel {
  final double position;
  final DateTime time;
  const _ChartTimeLabel({required this.position, required this.time});
}

String _compactPrice(double value, Currency currency) {
  final symbol = MoneyDisplay.tickerSymbolFor(currency);
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '$symbol ${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (absValue >= 1000) {
    return '$symbol ${(value / 1000).toStringAsFixed(0)}k';
  }
  return '$symbol ${value.toStringAsFixed(0)}';
}

String _timeLabel(
  DateTime time,
  BitcoinMarketChartRange range, {
  String? locale,
}) {
  final loc = locale;
  switch (range) {
    case BitcoinMarketChartRange.oneDay:
    case BitcoinMarketChartRange.threeDays:
      return intl.DateFormat('HH:mm', loc).format(time);
    case BitcoinMarketChartRange.oneWeek:
    case BitcoinMarketChartRange.oneMonth:
    case BitcoinMarketChartRange.ninetyDays:
      return intl.DateFormat('dd/MM', loc).format(time);
    case BitcoinMarketChartRange.oneYear:
      return intl.DateFormat('MMM', loc).format(time);
    case BitcoinMarketChartRange.all:
      return intl.DateFormat('yyyy', loc).format(time);
  }
}

String _tooltipTime(
  DateTime time,
  BitcoinMarketChartRange range, {
  String? locale,
}) {
  final loc = locale;
  switch (range) {
    case BitcoinMarketChartRange.oneDay:
    case BitcoinMarketChartRange.threeDays:
      return intl.DateFormat('dd/MM HH:mm', loc).format(time);
    case BitcoinMarketChartRange.oneWeek:
    case BitcoinMarketChartRange.oneMonth:
    case BitcoinMarketChartRange.ninetyDays:
      return intl.DateFormat('dd/MM HH:mm', loc).format(time);
    case BitcoinMarketChartRange.oneYear:
      return intl.DateFormat('dd/MM/yyyy', loc).format(time);
    case BitcoinMarketChartRange.all:
      return intl.DateFormat('MM/yyyy', loc).format(time);
  }
}
