import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/cold_wallet_creation_screen.dart';
import 'package:kerosene/storybook/stories/bitcoin_advanced_stories.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bitcoin advanced stories include cold wallet creation flow', () {
    final storyNames = bitcoinAdvancedStories().map((story) => story.name);

    expect(storyNames, contains('Bitcoin/Cold Wallet/Create Flow'));
    expect(storyNames, contains('Bitcoin/Cards Surface'));
  });

  testWidgets('cards surface story renders card tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BitcoinCardsSurfaceStoryPreview(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BitcoinAccountsScreen), findsOneWidget);
    expect(find.text('Saldo Atual'), findsOneWidget);
    expect(find.text('Usuário'), findsWidgets);
    expect(find.text('Carteira assegurada'), findsOneWidget);
    expect(find.text('DISPONÍVEL'), findsWidgets);
    expect(find.text('Adicionar\ncarteira'), findsOneWidget);
  });

  testWidgets('cold wallet creation story renders the first flow screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ColdWalletCreationStoryPreview(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.byType(ColdWalletCreationScreen), findsOneWidget);
    expect(find.text('Nível de segurança'), findsWidgets);
    expect(find.text('Gerar palavras'), findsOneWidget);
  });
}
