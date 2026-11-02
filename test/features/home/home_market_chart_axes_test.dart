import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/services/bitcoin_market_chart_service.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/home/presentation/providers/home_bitcoin_market_chart_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_bitcoin_market_chart_card.dart';

import '../../goldens/golden_harness.dart';

Finder get _plot => find.byWidgetPredicate((widget) =>
    widget is CustomPaint &&
    widget.painter.runtimeType.toString() == '_BitcoinMarketChartPainter');

Future<void> _pumpChart(WidgetTester tester, double scale,
    {bool sameMinute = false}) async {
  const request = BitcoinMarketChartRequest(
    symbol: 'BTCBRL',
    quoteCurrency: Currency.brl,
    range: BitcoinMarketChartRange.oneDay,
  );
  final snapshot = BitcoinMarketChartSnapshot(
      request: request,
      points: [
        BitcoinMarketChartPoint(
            time: DateTime.utc(2020, 1, 1, 10), price: 350000),
        BitcoinMarketChartPoint(
            time: DateTime.utc(2020, 1, 1, sameMinute ? 10 : 11, 0, 30),
            price: 357000),
      ],
      lastUpdatedAt: DateTime.utc(2020, 1, 1, 11),
      isLive: false);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        homeBitcoinMarketChartProvider
            .overrideWith((ref) => Stream.value(snapshot)),
        homeBitcoinMarketChartRequestProvider.overrideWithValue(request),
        moneyFormatConfigProvider.overrideWithValue(const MoneyFormatConfig(
            currency: Currency.brl, locale: Locale('pt'))),
      ],
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          home: const Scaffold(
              body:
                  SizedBox(width: 390, child: HomeBitcoinMarketChartCard())))));
  await tester.pumpAndSettle();
}

List<Invocation> _paintLabels(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(_plot);
  final canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, tester.getSize(_plot));
  return canvas.invocations
      .map((call) => call.invocation)
      .where((call) => call.memberName == #drawParagraph)
      .toList();
}

void main() {
  setUpAll(initializeGoldenHarness);

  for (final scale in [1.0, 1.4, 2.0]) {
    testWidgets('axis prices are complete and sparse times unique at $scale',
        (tester) async {
      await _pumpChart(tester, scale);
      final labels = _paintLabels(tester);
      expect(labels, hasLength(5)); // Three prices, one time per real point.
      final size = tester.getSize(_plot);
      for (final call in labels) {
        final paragraph = call.positionalArguments[0] as ui.Paragraph;
        final position = call.positionalArguments[1] as Offset;
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(position.dx, greaterThanOrEqualTo(0));
        expect(
            position.dx + paragraph.longestLine, lessThanOrEqualTo(size.width));
        expect(position.dy + paragraph.height, lessThanOrEqualTo(size.height));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('same displayed minute is drawn once', (tester) async {
    await _pumpChart(tester, 1.4, sameMinute: true);
    expect(_paintLabels(tester), hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'large text keeps price prominent and range labels inside targets',
      (tester) async {
    await _pumpChart(tester, 2.0);
    final price = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('R\$') == true);
    final change = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('%') == true);
    expect(tester.getRect(price).height,
        greaterThanOrEqualTo(tester.getRect(change).height));
    final label = find.text('3D');
    final target =
        find.ancestor(of: label, matching: find.byType(InkWell)).first;
    final targetRect = tester.getRect(target);
    final labelRect = tester.getRect(label);
    final animatedChip = tester.widget<AnimatedContainer>(find
        .ancestor(of: label, matching: find.byType(AnimatedContainer))
        .first);
    expect(animatedChip.duration, Duration.zero);
    expect(targetRect.height, greaterThanOrEqualTo(48));
    expect(labelRect.top, greaterThanOrEqualTo(targetRect.top));
    expect(labelRect.bottom, lessThanOrEqualTo(targetRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch selection follows the responsive plot bounds',
      (tester) async {
    await _pumpChart(tester, 2.0);
    final widget = tester.widget<CustomPaint>(_plot);
    final dynamic painter = widget.painter;
    final padding = painter.padding as EdgeInsets;
    final plotSize = tester.getSize(_plot);
    final origin = tester.getTopLeft(_plot);
    await tester.tapAt(origin + Offset(padding.left, plotSize.height / 2));
    await tester.pumpAndSettle();
    final dynamic first = tester.widget<CustomPaint>(_plot).painter;
    expect(first.selectedIndex, 0);
    await tester.tapAt(
        origin + Offset(plotSize.width - padding.right, plotSize.height / 2));
    await tester.pumpAndSettle();
    final dynamic last = tester.widget<CustomPaint>(_plot).painter;
    expect(last.selectedIndex, 1);
    final tooltip = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ChartTooltip');
    final tooltipRect = tester.getRect(tooltip);
    final plotRect = tester.getRect(_plot);
    expect(tooltipRect.left, greaterThanOrEqualTo(plotRect.left));
    expect(tooltipRect.right, lessThanOrEqualTo(plotRect.right));
    for (final element in find
        .descendant(of: tooltip, matching: find.byType(Text))
        .evaluate()) {
      final paragraph = element.findRenderObject() as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
