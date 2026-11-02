import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/application/providers/emergency_recovery_service_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/data/emergency_recovery_service.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'support/emergency_recovery_fixtures.dart';

final _scope = NotifierProvider<_Scope, String?>(_Scope.new);

class _Scope extends Notifier<String?> {
  @override
  String? build() => 'origin';
  void change() => state = 'another-session';
}

class _Service implements EmergencyRecoveryService {
  int starts = 0;
  int finishes = 0;
  Object? startError;
  Object? finishError;
  Completer<EmergencyRecoveryStartResult>? pendingStart;
  Completer<EmergencyRecoveryFinishResult>? pendingFinish;
  EmergencyRecoveryStartResult startResult = recoveryFixtureStart;
  EmergencyRecoveryFinishResult finishResult = recoveryFixtureFinish;
  String? submittedUsername;
  @override
  Future<EmergencyRecoveryStartResult> start(
      EmergencyRecoveryStartDraft draft) async {
    starts++;
    if (startError != null) throw startError!;
    if (pendingStart != null) return pendingStart!.future;
    return startResult;
  }

  @override
  Future<EmergencyRecoveryFinishResult> finish(
      {required String username,
      required EmergencyRecoveryStartResult started,
      required String totpCode}) async {
    finishes++;
    submittedUsername = username;
    if (finishError != null) throw finishError!;
    if (pendingFinish != null) return pendingFinish!.future;
    return finishResult;
  }
}

void main() {
  late _Service service;
  late DateTime now;
  late GoRouter router;
  final secureCalls = <bool>[];
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    GoogleFonts.config.allowRuntimeFetching = false;
    service = _Service();
    now = DateTime.utc(2026, 10, 11);
    secureCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.kerosene.app/secure_screen'),
            (call) async {
      secureCalls.add((call.arguments as Map)['enabled'] as bool);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.kerosene.app/secure_screen'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    router.dispose();
  });
  Future<void> open(WidgetTester tester,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    router = GoRouter(initialLocation: '/login', routes: [
      GoRoute(
          path: '/login',
          builder: (context, _) => Scaffold(
                  body: Column(children: [
                const Text('LOGIN_DESTINATION'),
                TextButton(
                    onPressed: () => context.push('/recover'),
                    child: const Text('OPEN_RECOVERY'))
              ]))),
      GoRoute(
          path: '/recover',
          builder: (_, __) => const EmergencyRecoveryScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          emergencyRecoveryServiceProvider.overrideWithValue(service),
          emergencyRecoveryClockProvider.overrideWithValue(() => now),
          emergencyRecoverySessionExitProvider
              .overrideWithValue(() async => true),
          sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_scope)),
        ],
        child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_RECOVERY'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    final fields = find.byType(TextField);
    for (final entry in [
      recoveryFixtureUsername,
      'PUBLIC_FIXTURE_PASSWORD',
      'PUBLIC_FIXTURE_PASSWORD',
      '01010101',
      '02020202',
      '03030303'
    ].asMap().entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(AppButton, 'Iniciar recuperação'));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await fill(tester);
    await tester.tap(find.text('Iniciar recuperação'));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '123456');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(AppButton, 'Confirmar nova chave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar nova chave'));
    await tester.pumpAndSettle();
  }

  testWidgets('duplicate start callbacks cannot send two requests',
      (tester) async {
    service.pendingStart = Completer();
    await open(tester);
    await fill(tester);
    final action = tester
        .widget<AppButton>(
            find.widgetWithText(AppButton, 'Iniciar recuperação'))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(service.starts, 1);
    await router.routerDelegate.navigatorKey.currentState!.maybePop();
    await tester.pump();
    expect(find.byType(EmergencyRecoveryScreen), findsOneWidget);
    service.pendingStart!.complete(recoveryFixtureStart);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('start clears secrets and never renders the raw enrollment URI',
      (tester) async {
    await open(tester);
    await start(tester);
    expect(secureCalls, contains(true));
    expect(find.text(recoveryFixtureStart.otpUri), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.ensureVisible(find.text('Voltar e revisar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar e revisar dados'));
    await tester.pumpAndSettle();
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, recoveryFixtureUsername);
    expect(fields.skip(1).every((field) => field.controller!.text.isEmpty),
        isTrue);
  });
  testWidgets('expired session removes QR and cannot confirm', (tester) async {
    await open(tester);
    await start(tester);
    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Esta sessão terminou'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Confirmar nova chave'), findsNothing);
    expect(service.finishes, 0);
  });
  testWidgets('deadline includes the latency of the start request',
      (tester) async {
    service.pendingStart = Completer();
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('Iniciar recuperação'));
    now = now.add(const Duration(minutes: 11));
    service.pendingStart!.complete(recoveryFixtureStart);
    await tester.pumpAndSettle();
    expect(find.text('Esta sessão terminou'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets('background hides enrollment and resume needs explicit reveal',
      (tester) async {
    await open(tester);
    await start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    await tester.ensureVisible(find.text('Mostrar dados da recuperação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar dados da recuperação'));
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
  });
  testWidgets('completion is single flight and cannot be dismissed during I/O',
      (tester) async {
    service.pendingFinish = Completer();
    await open(tester);
    await start(tester);
    await tester.enterText(find.byType(TextField), '123456');
    final action = tester
        .widget<AppButton>(
            find.widgetWithText(AppButton, 'Confirmar nova chave'))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(service.finishes, 1);
    expect(service.submittedUsername, recoveryFixtureUsername);
    await router.routerDelegate.navigatorKey.currentState!.maybePop();
    await tester.pump();
    expect(find.byType(EmergencyRecoveryScreen), findsOneWidget);
    service.pendingFinish!.complete(recoveryFixtureFinish);
    await tester.pumpAndSettle();
    expect(find.text('Recuperação concluída'), findsOneWidget);
  });

  testWidgets('resume after expiry does not reveal a stale QR', (tester) async {
    await open(tester);
    await start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Esta sessão terminou'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(service.finishes, 0);
  });
  testWidgets('successful completion requires saving codes before sign-in',
      (tester) async {
    await open(tester);
    await start(tester);
    await finish(tester);
    expect(find.text(recoveryFixtureCodes.first), findsOneWidget);
    await router.routerDelegate.navigatorKey.currentState!.maybePop();
    await tester.pump();
    expect(find.byType(EmergencyRecoveryScreen), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Entrar novamente'))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Entrar novamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN_DESTINATION'), findsOneWidget);
    expect(service.finishes, 1);
    expect(secureCalls.last, isFalse);
  });

  testWidgets(
      'a valid delayed completion survives expiry while awaiting the server',
      (tester) async {
    service.pendingFinish = Completer();
    await open(tester);
    await start(tester);
    await tester.enterText(find.byType(TextField), '123456');
    tester
        .widget<AppButton>(
            find.widgetWithText(AppButton, 'Confirmar nova chave'))
        .onPressed!();
    await tester.pump();
    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Confirmando a recuperação'), findsOneWidget);
    expect(find.text('Esta sessão terminou'), findsNothing);
    service.pendingFinish!.complete(recoveryFixtureFinish);
    await tester.pumpAndSettle();
    expect(find.text('Recuperação concluída'), findsOneWidget);
    expect(service.finishes, 1);
  });

  testWidgets('a late start cannot expose enrollment after account change',
      (tester) async {
    service.pendingStart = Completer();
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('Iniciar recuperação'));
    await tester.pump();
    ProviderScope.containerOf(
            tester.element(find.byType(EmergencyRecoveryScreen)),
            listen: false)
        .read(_scope.notifier)
        .change();
    await tester.pump();
    service.pendingStart!.complete(recoveryFixtureStart);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Recupere o acesso à conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final code in ['RECOVERY_REJECTED', 'RECOVERY_SESSION_EXPIRED']) {
    testWidgets(
        '$code closes the one-time session instead of repeating confirmation',
        (tester) async {
      service.finishError = ServerException(
          message: 'technical failure',
          statusCode: code == 'RECOVERY_REJECTED' ? 401 : 410,
          errorCode: code);
      await open(tester);
      await start(tester);
      await finish(tester);
      expect(find.text('Esta sessão terminou'), findsOneWidget);
      expect(find.text('Confirmar nova chave'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('technical failure'), findsNothing);
      expect(service.finishes, 1);
    });
  }
  testWidgets(
      'an unknown completion does not claim success or allow automatic restart',
      (tester) async {
    service.finishError = const EmergencyRecoveryResultUnknownException();
    await open(tester);
    await start(tester);
    await finish(tester);
    expect(find.text('Resultado ainda não confirmado'), findsOneWidget);
    expect(find.text('Recuperação concluída'), findsNothing);
    expect(find.text('Reiniciar recuperação'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    expect(service.finishes, 1);
  });
  testWidgets('malformed finish cannot display completed recovery',
      (tester) async {
    service.finishResult = const EmergencyRecoveryFinishResult(
        username: recoveryFixtureUsername, newBackupCodes: []);
    await open(tester);
    await start(tester);
    await finish(tester);
    expect(find.text('Resultado ainda não confirmado'), findsOneWidget);
    expect(find.text('Acesso atualizado'), findsNothing);
  });
  testWidgets('local enrollment error preserves the unsubmitted session',
      (tester) async {
    service.finishError = Exception('LOCAL_FIXTURE_CANCEL');
    await open(tester);
    await start(tester);
    await finish(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Confirmar nova chave'), findsOneWidget);
    expect(find.text('Resultado ainda não confirmado'), findsNothing);
  });
  testWidgets('a late reply cannot expose codes after account change',
      (tester) async {
    service.pendingFinish = Completer();
    await open(tester);
    await start(tester);
    await tester.enterText(find.byType(TextField), '123456');
    tester
        .widget<AppButton>(
            find.widgetWithText(AppButton, 'Confirmar nova chave'))
        .onPressed!();
    await tester.pump();
    ProviderScope.containerOf(
            tester.element(find.byType(EmergencyRecoveryScreen)),
            listen: false)
        .read(_scope.notifier)
        .change();
    await tester.pump();
    service.pendingFinish!.complete(recoveryFixtureFinish);
    await tester.pumpAndSettle();
    expect(find.text(recoveryFixtureCodes.first), findsNothing);
    expect(find.text('Recupere o acesso à conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('copy failure is visible and never reports copied',
      (tester) async {
    await open(tester);
    await start(tester);
    await finish(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'fixture-copy-failure');
      }
      return null;
    });
    await tester.ensureVisible(find.text('Copiar novos códigos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar novos códigos'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível copiar os códigos. Tente novamente.'),
        findsOneWidget);
    expect(find.text('Copiado.'), findsNothing);
    expect(find.text('Recuperação concluída'), findsOneWidget);
    expect(find.text('Não foi possível continuar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'compact large-text recovery can reach confirmation and code saving without overflow',
      (tester) async {
    await open(tester, size: const Size(320, 720), textScale: 1.4);
    await start(tester);
    expect(tester.takeException(), isNull);
    await finish(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Guardei os novos códigos de recuperação em um local seguro.'),
        findsOneWidget);
  });
}
