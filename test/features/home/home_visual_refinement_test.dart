import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/features/home/presentation/design/home_market_change.dart';
import 'package:kerosene/features/home/presentation/providers/onboarding_progress_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_education.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_transactions.dart';
import 'package:kerosene/features/home/presentation/widgets/animated_balance_display.dart';
import 'package:kerosene/features/home/presentation/widgets/home_onboarding_progress_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('missing, nonfinite and rounded zero changes have neutral direction',
      () {
    for (final value in <double?>[
      null,
      double.nan,
      double.infinity,
      0,
      -0.004,
      0.004
    ]) {
      final change = HomeMarketChange(value);
      expect(change.direction, 0);
      expect(change.sign, '');
    }
    expect(HomeMarketChange(null).absoluteLabel(decimalComma: true), isNull);
    expect(HomeMarketChange(-0.004).absoluteLabel(decimalComma: true), '0,00');
  });

  test('sign follows market change, independent of a zero portfolio balance',
      () {
    expect(HomeMarketChange(-2.345).direction, -1);
    expect(HomeMarketChange(-2.345).sign, '-');
    expect(HomeMarketChange(2.345).direction, 1);
    expect(HomeMarketChange(2.345).sign, '+');
    expect(HomeMarketChange(1.25).absoluteLabel(decimalComma: true), '1,25');
    expect(HomeMarketChange(1.25).absoluteLabel(decimalComma: false), '1.25');
  });

  test('operational heading and metadata use coherent type tokens', () {
    expect(
        HomeTypography.sectionHeader().fontFamily, contains('PlusJakartaSans'));
    expect(HomeTypography.sectionHeader().fontWeight, FontWeight.w600);
    expect(HomeTypography.smallLabelSize, greaterThanOrEqualTo(12));
    expect(HomeRadius.card, 20);
    expect(HomeMotion.entrance.inMilliseconds, lessThanOrEqualTo(300));
  });

  test('home chart and activation copy is localized in all supported languages',
      () {
    final pt = lookupAppLocalizations(const Locale('pt'));
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));

    expect(pt.homeChartNoDataForPeriod, 'Sem dados para este período');
    expect(en.homeChartNoDataForPeriod, 'No data for this period');
    expect(es.homeChartNoDataForPeriod, 'No hay datos para este período');
    expect(pt.homeChartLastNDays(30), 'Últimos 30 dias');
    expect(en.homeChartLastNDays(30), 'Last 30 days');
    expect(es.homeChartLastNDays(30), 'Últimos 30 días');
    expect(es.onboardingProgressCount(2), '2 de 3 completados');
  });

  testWidgets('activation progress card follows the active locale',
      (tester) async {
    for (final locale in const [Locale('pt'), Locale('en'), Locale('es')]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingProgressProvider.overrideWithValue(
              const OnboardingProgress(
                hasCustodialWallet: true,
                hasDeposit: false,
                hasInternalTransfer: false,
              ),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: HomeOnboardingProgressCard()),
          ),
        ),
      );
      await tester.pump();
      final copy = lookupAppLocalizations(locale);
      expect(find.text(copy.onboardingJourneyTitle), findsOneWidget);
      expect(find.text(copy.onboardingProgressCount(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('home empty surfaces use canonical tokens in $brightness',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.themeFor(AppThemeVariant.light),
          home: Scaffold(
            body: ListView(
              children: [
                HomeEmptyTransactionsPanel(
                  icon: Icons.receipt_long,
                  title: 'Atividades',
                  description: 'Sem atividades',
                  actionLabel: 'Criar',
                  actionIcon: Icons.add,
                  onAction: () {},
                  showAction: false,
                ),
                const HomeDistributionEmptyState(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final panel = tester.widget<HomeGlassPanel>(find.byType(HomeGlassPanel));
      expect(panel.borderRadius,
          BorderRadius.circular(HomeSurfaceTokens.radiusCard));

      final distribution = find.byType(HomeDistributionEmptyState);
      final containers = find.descendant(
        of: distribution,
        matching: find.byType(Container),
      );
      final surface = HomeSurfaceTheme.of(tester.element(distribution));
      final outer = tester.widget<Container>(containers.at(0));
      final iconWell = tester.widget<Container>(containers.at(1));
      expect((outer.decoration! as BoxDecoration).color, surface.surfaceDim);
      expect((outer.decoration! as BoxDecoration).border!.top.color,
          surface.surfaceBorder);
      expect((iconWell.decoration! as BoxDecoration).color, surface.card);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'actions remain readable and tappable in $brightness with large text',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.themeFor(AppThemeVariant.light),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 280,
                      child: Row(children: [
                        Expanded(
                            child: HomeBalanceActionButton(
                                icon: Icons.south,
                                label: 'Receber',
                                onTap: () => taps++,
                                primary: true)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: HomeBalanceActionButton(
                                icon: Icons.north,
                                label: 'Enviar',
                                onTap: () => taps++,
                                primary: false)),
                      ])))),
        ),
      ));
      await tester.pump();
      expect(find.text('Receber'), findsOneWidget);
      expect(tester.getSize(find.byType(HomeBalanceActionButton).first).height,
          greaterThanOrEqualTo(52));
      await tester.tap(find.text('Receber'));
      await tester.tap(find.text('Enviar'));
      expect(taps, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('balance supports full BTC precision, scaling and reduced motion',
      (tester) async {
    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: const Scaffold(
            body: Center(
                child: SizedBox(
                    width: 280,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedBalanceDisplay(
                          balance: 123456.12345678,
                          decimalPlaces: 8,
                          locale: 'pt_BR',
                          decimalScaleFactor: 0.9,
                          separatorScaleFactor: 0.9,
                          style: TextStyle(fontSize: 48),
                          animateInitialValue: false),
                    )))),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedBalanceDisplay), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
