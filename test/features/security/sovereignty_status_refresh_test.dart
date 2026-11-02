import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/security/domain/entities/security_status.dart';
import 'package:kerosene/features/security/domain/entities/kfe_reserve_overview.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/sovereignty_status_screen.dart';

class _Owner extends Notifier<String> {
  @override
  String build() => 'owner-a';
  void change() => state = 'owner-b';
}

final _owner = NotifierProvider<_Owner, String>(_Owner.new);

const _healthyStatus = SecurityStatus(
  hardwareAttestation: {'status': 'VERIFIED', 'totalChecks': 12},
  networkConsensus: {
    'status': 'ACTIVE',
    'activeNodes': 3,
    'totalNodes': 3,
    'requiredNodes': 2
  },
  ledgerIntegrity: {'status': 'VALID', 'ledgerCount': 8},
  memoryProtection: {'status': 'LOCKED', 'diskPersistence': false},
  serverUptimeSeconds: 3600,
);

const _reserve = KfeReserveOverview(
  totalOnchainBtc: 1,
  lightningNodeBtc: 0.5,
  inboundLiquidityBtc: 0.3,
  outboundLiquidityBtc: 0.2,
  reservedOnchainBtc: 0.1,
  reservedLightningBtc: 0.1,
  availableOnchainBtc: 0.9,
  availableLightningBtc: 0.4,
  lightningSendsAllowed: true,
  liquidityState: 'HEALTHY',
);
const _auditStats = <String, dynamic>{
  'liability_to_users': 1.0,
  'actual_onchain_balance': 1.0,
  'actual_lightning_balance': 0.5,
  'actual_total_assets': 1.5,
  'is_solvent': true,
};

class _Responses<T> {
  final requests = <Completer<T>>[];
  Future<T> load() {
    final request = Completer<T>();
    requests.add(request);
    return request.future;
  }
}

class _Fixture {
  final status = _Responses<SecurityStatus>();
  final reserves = _Responses<KfeReserveOverview>();
  final audit = _Responses<Map<String, dynamic>>();
  late ProviderContainer container;

  void completeLatest() {
    if (!status.requests.last.isCompleted) {
      status.requests.last.complete(_healthyStatus);
    }
    if (!reserves.requests.last.isCompleted) {
      reserves.requests.last.complete(_reserve);
    }
    if (!audit.requests.last.isCompleted) {
      audit.requests.last.complete(_auditStats);
    }
  }
}

Future<_Fixture> _pump(WidgetTester tester,
    {double scale = 1, bool loaded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fixture = _Fixture();
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
        sovereigntyStatusProvider.overrideWith((ref) {
          ref.watch(sessionStorageScopeProvider);
          return fixture.status.load();
        }),
        kfeReserveOverviewProvider.overrideWith((ref) {
          ref.watch(sessionStorageScopeProvider);
          return fixture.reserves.load();
        }),
        auditStatsProvider.overrideWith((ref) {
          ref.watch(sessionStorageScopeProvider);
          return fixture.audit.load();
        }),
      ],
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SovereigntyStatusScreen(),
      )));
  fixture.container = ProviderScope.containerOf(
      tester.element(find.byType(SovereigntyStatusScreen)));
  if (loaded) {
    fixture.completeLatest();
    await tester.pumpAndSettle();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  return fixture;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });

  testWidgets(
      'refresh waits for every request and retains successful data on failure',
      (tester) async {
    final fixture = await _pump(tester);
    expect(find.text('Operação íntegra'), findsOneWidget);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    var finished = false;
    unawaited(refresh.then((_) => finished = true));
    await tester.pump();
    expect(find.text('Última leitura'), findsOneWidget);
    fixture.status.requests.last
        .completeError(StateError('private server stack detail'));
    await tester.pump();
    expect(
        find.textContaining(
            'Não foi possível atualizar os dados de segurança.'),
        findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.textContaining('private server stack detail'), findsNothing);
    expect(finished, isFalse);
    await tester.pump(const Duration(seconds: 24));
    expect(fixture.status.requests.length, 2,
        reason: 'polling must not restart pending requests');
    expect(fixture.reserves.requests.length, 2);
    expect(finished, isFalse);
    fixture.completeLatest();
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('sovereignty-refresh')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session change clears the previous account readouts',
      (tester) async {
    final fixture = await _pump(tester);
    fixture.container.read(_owner.notifier).change();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Sessão alterada'), findsOneWidget);
    expect(find.text('Operação íntegra'), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reopening starts a real consultation without dating cached data as fresh',
      (tester) async {
    final fixture = await _pump(tester);
    final context = tester.element(find.byType(SovereigntyStatusScreen));
    unawaited(Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const SovereigntyStatusScreen(),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fixture.status.requests.length, 2);
    expect(find.text('Última leitura'), findsOneWidget);
    expect(
        find.textContaining('Os dados anteriores ainda não foram atualizados.'),
        findsWidgets);
    fixture.completeLatest();
    await tester.pumpAndSettle();
    expect(find.text('Operação íntegra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic refresh pauses while the app is in the background',
      (tester) async {
    final fixture = await _pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 24));
    expect(fixture.status.requests.length, 1);
    expect(fixture.reserves.requests.length, 1);
    expect(fixture.audit.requests.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 12));
    expect(fixture.status.requests.length, 2);
    fixture.completeLatest();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'first failure offers a human retry without exposing technical errors',
      (tester) async {
    final fixture = await _pump(tester, loaded: false);
    fixture.status.requests.last
        .completeError(StateError('secret technical response'));
    fixture.reserves.requests.last
        .completeError(StateError('reserve unavailable'));
    fixture.audit.requests.last.completeError(StateError('audit unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Leitura indisponível'), findsOneWidget);
    expect(find.textContaining('secret technical response'), findsNothing);
    expect(
        find.textContaining('Não conseguimos consultar os dados de segurança'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps header actions accessible', (tester) async {
    await _pump(tester, scale: 1.8);
    expect(find.byTooltip('Atualizar'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(
        tester.getSize(find.byKey(const ValueKey('sovereignty-refresh'))).width,
        greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
