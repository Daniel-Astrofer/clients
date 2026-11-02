import 'dart:async';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/app/router/mobile_go_router.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_success_scene.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_components.dart';
import 'package:kerosene/storybook/storybook_mocks.dart'
    show MockAuthController;

class _LoginRepository implements AuthRepository {
  int calls = 0;
  final pending = Completer<Either<Failure, LoginResult>>();
  @override
  Future<Either<Failure, LoginResult>> login(
      {required String username, required String passphrase}) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignupController extends MockAuthController {
  _SignupController({this.optional = false})
      : super(initialOverride: const AuthUnauthenticated());
  final bool optional;
  int signupCalls = 0;
  int verifies = 0;
  bool successfulTotp = false;
  bool deviceBound = false;
  bool uncertainCompletion = false;
  int enrollmentCalls = 0;
  bool? unlinkConfirmed;
  late AuthRequiresTotpSetup setup;
  @override
  Future<void> signup(
      {required String username,
      required String password,
      String accountSecurity = 'STANDARD',
      int? shamirTotalShares,
      int? shamirThreshold,
      int? multisigThreshold}) async {
    signupCalls++;
    setup = AuthRequiresTotpSetup(
        username: username,
        passphrase: password,
        sessionId: 'signup-fixture',
        totpSecret: 'PUBLIC-FIXTURE',
        qrCodeUri: 'otpauth://fixture',
        backupCodes: const ['PUBLIC-FIXTURE'],
        totpOptional: optional);
    state = setup;
  }

  @override
  Future<void> verifyTotp(
      {required String username,
      required String passphrase,
      required String totpSecret,
      required String totpCode}) async {
    verifies++;
    if (successfulTotp) {
      state = AuthTotpVerified(setup.sessionId, setup.username);
      return;
    }
    state = AuthError('Código incorreto',
        errorCode: 'AUTH_008', statusCode: 401, resumeState: setup);
  }

  @override
  Future<void> registerPasskeyOnboarding(String sessionId,
      {bool confirmUnlinkDevice = false}) async {
    expect(sessionId, 'signup-fixture');
    enrollmentCalls++;
    unlinkConfirmed = confirmUnlinkDevice;
    if (uncertainCompletion) {
      state = AuthOnboardingOutcomeUnknown(setup.username);
      return;
    }
    state = AuthError('Não foi possível vincular o dispositivo.',
        errorCode:
            deviceBound && enrollmentCalls == 1 ? 'AUTH_024' : 'ERR_NETWORK',
        data: deviceBound ? const {'previousUsernameMasked': 'a***'} : null,
        resumeState: AuthTotpVerified(setup.sessionId, setup.username));
  }
}

Widget _app(Widget page, List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page));
Future<void> _tapButton(WidgetTester tester, int index) async {
  final button = find.byType(SignupPrimaryButton).at(index);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _enterSignupToTotp(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'alice');
  await _tapButton(tester, 0);
  await tester.enterText(find.byType(TextField).first, 'PublicPass123!');
  await tester.pump();
  await _tapButton(tester, 0);
  await tester.enterText(find.byType(TextField).first, 'PublicPass123!');
  final consent = find.byType(SignupRiskAcknowledgement);
  await tester.ensureVisible(consent);
  await tester.tap(consent);
  await tester.pump();
  await _tapButton(tester, 0);
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _tapSignupBack(WidgetTester tester) async {
  final back = find
      .descendant(
          of: find.byType(SignupTopBar), matching: find.byType(IconButton))
      .first;
  await tester.ensureVisible(back);
  await tester.pumpAndSettle();
  await tester.tap(back);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });
  testWidgets(
      'login double tap sends one request and native back is blocked while waiting',
      (tester) async {
    final repository = _LoginRepository();
    await tester.pumpWidget(_app(const LoginScreen(username: 'alice'), [
      authRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() =>
          MockAuthController(initialOverride: const AuthUnauthenticated()))
    ]));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'PublicPass123!');
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(repository.calls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    repository.pending.complete(const Left(NetworkFailure()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final optional in [false, true]) {
    testWidgets(
        'TOTP keeps its session and respects optional policy: $optional',
        (tester) async {
      final controller = _SignupController(optional: optional);
      await tester.pumpWidget(_app(const SignupFlowScreen(),
          [authControllerProvider.overrideWith(() => controller)]));
      await tester.pumpAndSettle();
      await _enterSignupToTotp(tester);
      expect(find.byType(TotpDigitBoxes), findsOneWidget);
      expect(find.byType(SignupPrimaryButton), findsNWidgets(optional ? 2 : 1));
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await _tapButton(tester, optional ? 1 : 0);
      expect(find.byType(TotpDigitBoxes), findsOneWidget);
      expect(controller.verifies, 1);
      // Top-bar back returns to the review, not an idle creation spinner.
      final back = find
          .descendant(
              of: find.byType(SignupTopBar), matching: find.byType(IconButton))
          .first;
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      await _tapButton(tester, 0);
      expect(find.byType(TotpDigitBoxes), findsOneWidget);
      expect(controller.signupCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'enrollment failure keeps the verified signup through back and retry',
      (tester) async {
    final controller = _SignupController()..successfulTotp = true;
    await tester.pumpWidget(_app(const SignupFlowScreen(),
        [authControllerProvider.overrideWith(() => controller)]));
    await tester.pumpAndSettle();
    await _enterSignupToTotp(tester);
    expect(find.text('Configure o autenticador'), findsOneWidget);
    expect(find.textContaining('(opcional)'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();
    await _tapButton(tester, 0);
    await _tapButton(tester, 0);
    expect(controller.enrollmentCalls, 1);
    expect(find.byType(TotpDigitBoxes), findsNothing);
    expect(find.byType(SignupSuccessScene), findsNothing);
    await _tapSignupBack(tester);
    expect(find.text('Guarde seus códigos de recuperação'), findsOneWidget);
    expect(find.byType(TotpDigitBoxes), findsNothing);
    expect(find.byType(TotpQrBox), findsNothing);
    await _tapSignupBack(tester);
    await _tapButton(tester, 0);
    await _tapButton(tester, 0);
    expect(controller.signupCalls, 1);
    expect(controller.verifies, 1);
    expect(controller.enrollmentCalls, 2);
    expect(find.byType(SignupSuccessScene), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final confirm in [false, true]) {
    testWidgets(
        'device unlink decision is preserved without restarting signup: $confirm',
        (tester) async {
      final controller = _SignupController()
        ..successfulTotp = true
        ..deviceBound = true;
      await tester.pumpWidget(_app(const SignupFlowScreen(),
          [authControllerProvider.overrideWith(() => controller)]));
      await tester.pumpAndSettle();
      await _enterSignupToTotp(tester);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await _tapButton(tester, 0);
      await _tapButton(tester, 0);
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final buttons =
          find.descendant(of: dialog, matching: find.byType(TextButton));
      await tester.tap(confirm ? buttons.last : buttons.first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.enrollmentCalls, confirm ? 2 : 1);
      expect(controller.unlinkConfirmed, confirm);
      expect(controller.signupCalls, 1);
      expect(controller.verifies, 1);
      expect(find.byType(SignupSuccessScene), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final navigation in ['action', 'header', 'system']) {
    testWidgets(
        'unknown signup result opens actual login with the same username: via $navigation',
        (tester) async {
      final controller = _SignupController()
        ..successfulTotp = true
        ..uncertainCompletion = true;
      final router = buildMobileGoRouter(
          privateRouteBuilder: (child) => child,
          root: const SignupFlowScreen());
      addTearDown(() {
        router.dispose();
        keroseneGoRouter = null;
      });
      await tester.pumpWidget(ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => controller)],
          child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('pt'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales)));
      await tester.pumpAndSettle();
      await _enterSignupToTotp(tester);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await _tapButton(tester, 0);
      await _tapButton(tester, 0);
      expect(find.text('Resultado ainda não confirmado'), findsOneWidget);
      expect(find.byType(SignupSuccessScene), findsNothing);
      expect(find.text('Verificar pelo login'), findsOneWidget);
      if (navigation == 'header') {
        await _tapSignupBack(tester);
      } else if (navigation == 'system') {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await _tapButton(tester, 0);
      }
      expect(find.byType(SignupFlowScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'alice');
      expect(controller.signupCalls, 1);
      expect(controller.enrollmentCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'success remains scrollable with enlarged text on a compact phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var continued = false;
    await tester.pumpWidget(_app(
        MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.7),
                disableAnimations: true),
            child: Scaffold(
                body: SignupSuccessScene(
                    appTitle: 'Kerosene',
                    title: 'Conta criada',
                    subtitle:
                        'Sua conta foi confirmada. Confira o próximo passo para usar o aplicativo.',
                    actionLabel: 'Continuar',
                    onContinue: () => continued = true))),
        []));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });
  for (final signup in [false, true]) {
    testWidgets(
        'auth viewport remains valid in landscape with keyboard: $signup',
        (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
          _app(signup ? const SignupFlowScreen() : const LoginScreen(), [
        authControllerProvider.overrideWith(() =>
            MockAuthController(initialOverride: const AuthUnauthenticated()))
      ]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
