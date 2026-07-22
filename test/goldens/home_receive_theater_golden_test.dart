import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_scroll_busy_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_communication_stage.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';
import 'package:kerosene/features/home/scene/providers/scene_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StaticHomeSurface extends HomeSurfaceNotifier {
  @override
  HomeSurface build() => HomeSurface.localDefaults();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences shared;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    SharedPreferences.setMockInitialValues(const {});
    shared = await SharedPreferences.getInstance();
  });

  overrides() => [
        sharedPreferencesProvider.overrideWithValue(shared),
        homeSurfaceProvider.overrideWith(_StaticHomeSurface.new),
      ];

  testGoldens('home receive theater settled open', (tester) async {
    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-golden',
        amountLabel: 'R\$ 148,32',
        walletName: 'Financeiro',
        networkLabel: 'Onchain',
      ),
      lang: 'pt',
    );
    final scene = homeSceneFromStage(stage);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            backgroundColor: Color(0xFF050508),
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeCommunicationStage(userName: 'Daniel'),
                    SizedBox(height: 24),
                    SizedBox(
                      height: 72,
                      child: Center(
                        child: Text(
                          '0,00293126 BTC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeCommunicationStage)),
    );
    container.read(homeSceneProvider.notifier).present(scene);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Recebido'), findsOneWidget);
    expect(find.textContaining('Transferência recebida'), findsOneWidget);

    await screenMatchesGolden(tester, 'home_receive_theater');
  });

  testWidgets('receive theater copy survives scroll-busy header band',
      (tester) async {
    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-busy',
        amountLabel: 'R\$ 20,00',
        walletName: 'Principal',
        networkLabel: 'Interna',
      ),
      lang: 'pt',
    );
    final scene = homeSceneFromStage(stage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(homeScrollBusyProvider);
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: HomeCommunicationStage(userName: 'Daniel'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeCommunicationStage)),
    );
    container.read(homeScrollBusyProvider.notifier).setBusy(true);
    container.read(homeSceneProvider.notifier).present(scene);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Recebido'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Recebido.*Transferência recebida')),
      findsOneWidget,
    );
  });
}
