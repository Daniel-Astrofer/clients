import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_display_pane.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'app_locale': 'pt', 'app_currency': 'USD'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('currency preference survives a new provider container', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    await first
        .read(appDisplayPreferencesProvider.notifier)
        .setCurrency(Currency.brl);
    expect(prefs.getString('app_currency'), 'BRL');
    first.dispose();
    final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(next.read(appDisplayPreferencesProvider).currency, Currency.brl);
    next.dispose();
  });

  testWidgets('failed save stays visible and keeps the previous selection',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDisplayPreferencesProvider.overrideWith(_FailedPreference.new),
      ],
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
            body: SingleChildScrollView(child: SettingsDisplayPane())),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('R\$ BRL'));
    await tester.tap(find.text('R\$ BRL'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDisplayPane)));
    expect(
        container.read(appDisplayPreferencesProvider).currency, Currency.usd);
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(prefs.getString('app_currency'), 'USD');
    expect(tester.takeException(), isNull);
  });
}

class _FailedPreference extends AppDisplayPreferencesNotifier {
  @override
  AppDisplayPreferencesState build() => const AppDisplayPreferencesState(
        locale: Locale('pt'),
        currency: Currency.usd,
        timeZoneId: 'America/Sao_Paulo',
        timeZoneFollowDevice: true,
      );

  @override
  Future<void> setCurrency(Currency currency) async =>
      throw StateError('storage unavailable');
}
