import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';
import 'package:kerosene/features/home/scene/renderer/home_scene_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('incoming theater shows Recebido title via scene present',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-widget-test',
        amountLabel: 'R\$ 10,00',
        walletName: 'Financeiro',
        networkLabel: 'Onchain',
      ),
      lang: 'pt',
    );
    final scene = homeSceneFromStage(stage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            backgroundColor: Colors.black,
            body: HomeSceneHost(userName: 'Daniel'),
          ),
        ),
      ),
    );

    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeSceneHost)),
    );
    container.read(homeSceneProvider.notifier).present(scene);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Recebido'), findsOneWidget);
    expect(find.textContaining('Transferência recebida'), findsOneWidget);
  });

  testWidgets('presentLocalStage does not throw circular dependency',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-circ',
        amountLabel: 'R\$ 5,00',
        walletName: 'Principal',
        networkLabel: 'Interna',
      ),
      lang: 'pt',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            backgroundColor: Colors.black,
            body: HomeSceneHost(userName: 'Daniel'),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeSceneHost)),
    );

    expect(
      () =>
          container.read(homeSurfaceProvider.notifier).presentLocalStage(stage),
      returnsNormally,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Recebido'), findsOneWidget);
    expect(find.textContaining('Transferência recebida'), findsOneWidget);
  });

  testWidgets('theater text paints even when ancestor tickers are muted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-muted',
        amountLabel: 'R\$ 1,00',
        walletName: 'Financeiro',
        networkLabel: 'Onchain',
      ),
      lang: 'pt',
    );
    final scene = homeSceneFromStage(stage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: TickerMode(
              enabled: false,
              child: const HomeSceneHost(userName: 'Daniel'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeSceneHost)),
    );
    container.read(homeSceneProvider.notifier).present(scene);

    await tester.pump();

    expect(find.text('Recebido'), findsOneWidget);
    expect(find.textContaining('Transferência recebida'), findsOneWidget);
  });

  testWidgets('resting header renders only configured chrome actions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeSurfaceProvider.overrideWith(
            () => _FixedHomeSurfaceNotifier(
              HomeSurface.localDefaults().copyWith(
                restingHeader: const HomeRestingHeader(
                  balanceVisibility: false,
                  notifications: true,
                  settings: false,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            backgroundColor: Colors.black,
            body: HomeSceneHost(userName: 'Daniel'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(KeroseneIcons.notifications), findsOneWidget);
    expect(find.byIcon(KeroseneIcons.settings), findsNothing);
    expect(find.byIcon(KeroseneIcons.eye), findsNothing);
    expect(find.byIcon(KeroseneIcons.eyeOff), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FixedHomeSurfaceNotifier extends HomeSurfaceNotifier {
  _FixedHomeSurfaceNotifier(this.initial);

  final HomeSurface initial;

  @override
  HomeSurface build() => initial;
}
