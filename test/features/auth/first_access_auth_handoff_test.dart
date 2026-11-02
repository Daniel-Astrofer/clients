import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/domain/entities/login_result.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_progress.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/passkey_verification_components.dart';
import 'package:kerosene/features/auth/presentation/screens/passkey_verification_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_components.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_success_scene.dart';
import 'package:kerosene/features/auth/presentation/widgets/totp_input_container.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PrimaryRepository implements AuthRepository {
  _PrimaryRepository({this.requiresTotp = false});
  final bool requiresTotp;
  int totpCalls = 0;

  @override
  Future<Either<Failure, LoginResult>> login({
    required String username,
    required String passphrase,
  }) async =>
      Right(LoginResult(requiresTotp: requiresTotp, jwt: 'public-token'));

  @override
  Future<Either<Failure, User>> verifyLoginTotp({
    required String username,
    required String passphrase,
    required String totpCode,
    String? preAuthToken,
  }) async {
    totpCalls++;
    return Right(mockAuthenticatedState.user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RequiredPasskeyController extends MockAuthController {
  _RequiredPasskeyController(
      {AuthState initial = const AuthUnauthenticated(),
      this.loginError = const AuthError('No local credential',
          errorCode: 'ERR_AUTH_PASSKEY_NO_LOCAL_CREDENTIALS')})
      : super(initialOverride: initial);

  final AuthError loginError;

  int passkeyCalls = 0;
  int passwordSessionCalls = 0;
  int enrollmentCalls = 0;

  @override
  Future<void> loginWithPasskey(String username,
      {int remainingChallengeRenewals = 2}) async {
    passkeyCalls++;
    state = loginError;
  }

  @override
  Future<void> establishSessionAfterPasswordLogin() async {
    passwordSessionCalls++;
    state = mockAuthenticatedState;
  }

  @override
  Future<void> registerPasskeyOnboarding(String sessionId,
      {bool confirmUnlinkDevice = false}) async {
    expect(sessionId, 'public-signup-session');
    enrollmentCalls++;
    state = const AuthLoading();
  }

  void failEnrollment() {
    state = const AuthError('Registration canceled',
        errorCode: 'ERR_AUTH_PASSKEY_USER_CANCELLED',
        resumeState: AuthTotpVerified('public-signup-session', 'alice'));
  }

  void completeEnrollment() => state = mockAuthenticatedState;
}

Widget _app(Widget page, _RequiredPasskeyController controller,
        {_PrimaryRepository? repository, SharedPreferences? preferences}) =>
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
        if (preferences != null)
          sharedPreferencesProvider.overrideWithValue(preferences),
        if (repository != null)
          authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });

  for (final requiresTotp in [false, true]) {
    testWidgets('primary auth still requires passkey: TOTP $requiresTotp',
        (tester) async {
      final repository = _PrimaryRepository(requiresTotp: requiresTotp);
      final controller = _RequiredPasskeyController();
      await tester.pumpWidget(_app(
          const LoginScreen(username: 'alice'), controller,
          repository: repository));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'PublicPassword123!');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      if (requiresTotp) {
        expect(controller.passkeyCalls, 0);
        final totpField = find.descendant(
            of: find.byType(TotpInputContainer),
            matching: find.byType(TextField));
        await tester.enterText(totpField, '123456');
        await tester.pump();
        await tester.pumpAndSettle();
        expect(repository.totpCalls, 1);
      }
      expect(find.byType(PasskeyVerificationScreen), findsOneWidget);
      expect(controller.passkeyCalls, 1);
      expect(controller.passwordSessionCalls, 0);
      expect(find.text('Recuperar conta'), findsOneWidget);
      expect(find.text('USAR TOTP'), findsNothing);
      expect(controller.state, isNot(isA<AuthAuthenticated>()));
      expect(tester.takeException(), isNull);
    });
  }

  for (final errorCode in [
    'ERR_AUTH_PASSKEY_NO_LOCAL_CREDENTIALS',
    'ERR_AUTH_PASSKEY_USER_CANCELLED'
  ]) {
    testWidgets(
        'passkey error never falls back to password session: $errorCode',
        (tester) async {
      final controller = _RequiredPasskeyController(
          loginError: AuthError('Passkey not completed', errorCode: errorCode));
      await tester.pumpWidget(_app(
          const PasskeyVerificationScreen(
            username: 'alice',
            fallbackPassphrase: 'PublicPassword123!',
            fallbackPreAuthToken: 'public-preauth',
          ),
          controller));
      await tester.pumpAndSettle();
      expect(controller.passwordSessionCalls, 0);
      final issue =
          tester.widget<PasskeyIssueView>(find.byType(PasskeyIssueView));
      expect(issue.canUseTotp, isFalse);
      expect(controller.state, isA<AuthError>());
    });
  }

  testWidgets(
      'successful signup checkpoints account choice before leaving success',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = _RequiredPasskeyController(
        initial: const AuthTotpVerified('public-signup-session', 'alice'));
    await tester.pumpWidget(
        _app(const SignupFlowScreen(), controller, preferences: preferences));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SignupPrimaryButton));
    await tester.tap(find.byType(SignupPrimaryButton));
    await tester.pump();
    expect(find.byType(SignupSuccessScene), findsNothing);
    controller.completeEnrollment();
    await tester.pumpAndSettle();
    expect(find.byType(SignupSuccessScene), findsOneWidget);
    expect(
        FirstAccessProgress.shouldShow(
            preferences, mockAuthenticatedState.user.id,
            hasWallets: true),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired challenge is not retried while app is backgrounded',
      (tester) async {
    final controller = _RequiredPasskeyController(
        loginError: const AuthError('Expired', errorCode: 'AUTH_012'));
    await tester.pumpWidget(
        _app(const PasskeyVerificationScreen(username: 'alice'), controller));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.passkeyCalls, 1);
    expect(controller.passwordSessionCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening auth while inactive offers an explicit foreground retry',
      (tester) async {
    final controller = _RequiredPasskeyController();
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    // A paused app does not render frames: the screen would only mount after
    // resuming. Inactive is non-interactive but still renders, so this exercises
    // the foreground guard during actual screen initialization.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(
        _app(const PasskeyVerificationScreen(username: 'alice'), controller));
    await tester.pump();
    expect(find.byType(PasskeyVerificationScreen), findsOneWidget);
    expect(tester.binding.lifecycleState, AppLifecycleState.inactive);
    expect(find.text('Confirme sua entrada'), findsOneWidget);
    expect(controller.passkeyCalls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.passkeyCalls, 0);
    await tester.ensureVisible(find.text('TENTAR NOVAMENTE'));
    await tester.tap(find.text('TENTAR NOVAMENTE'));
    await tester.pumpAndSettle();
    expect(controller.passkeyCalls, 1);
    expect(controller.passwordSessionCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified signup resumes actual mandatory passkey enrollment',
      (tester) async {
    final controller = _RequiredPasskeyController(
        initial: const AuthTotpVerified('public-signup-session', 'alice'));
    await tester.pumpWidget(_app(const SignupFlowScreen(), controller));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Sua passkey é obrigatória'), findsOneWidget);
    final button = find.byType(SignupPrimaryButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.enrollmentCalls, 1);
    expect(find.text('Confirmando passkey'), findsOneWidget);
    expect(find.byType(SignupSuccessScene), findsNothing);
    controller.failEnrollment();
    await tester.pumpAndSettle();
    expect(find.byType(SignupSuccessScene), findsNothing);
    await tester.ensureVisible(find.byType(SignupPrimaryButton));
    await tester.tap(find.byType(SignupPrimaryButton));
    await tester.pump();
    expect(controller.enrollmentCalls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'unverified signup resumes server-required TOTP without skipping it',
      (tester) async {
    final controller = _RequiredPasskeyController(
        initial: const AuthRequiresTotpSetup(
      username: 'alice',
      passphrase: 'PublicPassword123!',
      sessionId: 'public-signup-session',
      totpSecret: 'PUBLIC-FIXTURE',
      qrCodeUri: 'otpauth://fixture',
      totpOptional: false,
    ));
    await tester.pumpWidget(_app(const SignupFlowScreen(), controller));
    await tester.pumpAndSettle();
    expect(find.byType(TotpDigitBoxes), findsOneWidget);
    expect(find.byType(SignupPrimaryButton), findsOneWidget);
    expect(controller.enrollmentCalls, 0);
    expect(find.byType(SignupSuccessScene), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
