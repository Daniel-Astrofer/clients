import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/services/bitcoin_market_chart_service.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/features/home/presentation/providers/home_bitcoin_market_chart_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_bitcoin_market_chart_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('market card uses flat tokens and banking numeric typography',
      (tester) async {
    const request = BitcoinMarketChartRequest(
      symbol: 'BTCBRL',
      quoteCurrency: Currency.brl,
      range: BitcoinMarketChartRange.oneDay,
    );
    final snapshot = BitcoinMarketChartSnapshot(
      request: request,
      points: [
        BitcoinMarketChartPoint(
          time: DateTime(2026, 9, 26, 10),
          price: 350000,
        ),
        BitcoinMarketChartPoint(
          time: DateTime(2026, 9, 26, 11),
          price: 352500,
        ),
      ],
      lastUpdatedAt: DateTime(2026, 9, 26, 11),
      isLive: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBitcoinMarketChartProvider.overrideWith(
            (ref) => Stream.value(snapshot),
          ),
          homeBitcoinMarketChartRequestProvider.overrideWithValue(request),
          moneyFormatConfigProvider.overrideWithValue(
            const MoneyFormatConfig(
              currency: Currency.brl,
              locale: Locale('pt', 'BR'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 390,
              child: HomeBitcoinMarketChartCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pair = tester.widget<Text>(find.text('BTC/BRL'));
    expect(pair.style!.fontFamily, AppTypography.numericFontFamily);

    final numericTexts = tester.widgetList<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('R\$') == true ||
                widget.data?.contains('%') == true),
      ),
    );
    expect(numericTexts, isNotEmpty);
    for (final text in numericTexts) {
      expect(text.style!.fontFamily, AppTypography.numericFontFamily);
      expect(text.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    }

    final selectedChip = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('1D'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = selectedChip.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNull);
    expect(decoration.color, HomeSurfaceTheme.dark.card);
    expect(decoration.border!.top.color, HomeSurfaceTheme.dark.surfaceBorder);
    expect(tester.takeException(), isNull);
  });
}
