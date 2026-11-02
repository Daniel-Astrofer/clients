import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/security/application/app_pin_recovery_service.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/app_pin_recovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _owner = User(
    id: 'pin-owner',
    username: 'fixture-user',
    createdAt: DateTime.utc(2026, 1));
final _other = User(
    id: 'another-owner',
    username: 'fixture-other',
    createdAt: DateTime.utc(2026, 1));

class _Auth extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_owner);
  void changeAccount() => state = AuthAuthenticated(_other);
  void signOut() => state = const AuthUnauthenticated();
}

class _Recovery {
  int challenges = 0;
  int signatures = 0;
  int posts = 0;
  Completer<void>? pendingSign;
  Completer<void>? pendingPost;
  Object? signError;
  Object? postError;
  Map<String, dynamic>? body;
  Map<String, dynamic> response = {
    'configured': true,
    'enabled': true,
    'locked': false
  };

  late final service = AppPinRecoveryService(
    challenge: (_) async {
      challenges++;
      return {'challengeId': 'PUBLIC_FIXTURE_CHALLENGE'};
    },
    sign: (_, __) async {
      signatures++;
      await pendingSign?.future;
      if (signError case final error?) throw error;
      return {'signature': 'PUBLIC_FIXTURE_SIGNATURE'};
    },
    recover: (payload) async {
      posts++;
      body = payload;
      await pendingPost?.future;
      if (postError case final error?) throw error;
      return response;
    },
  );
}

void main() {
  late _Recovery recovery;
  late SharedPreferences prefs;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    GoogleFonts.config.allowRuntimeFetching = false;
    AppEntryPinSession.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    recovery = _Recovery();
  });

  tearDown(() {
    router.dispose();
    container.dispose();
    AppEntryPinSession.clear();
  });

  Future<void> open(WidgetTester tester,
      {Size size = const Size(390, 844),
      double scale = 1,
      bool reduced = true}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appPinRecoveryServiceProvider.overrideWithValue(recovery.service),
    ]);
    router = GoRouter(initialLocation: '/lock', routes: [
      GoRoute(
          path: '/lock',
          builder: (context, _) => Scaffold(
                  body: Column(children: [
                const Text('PIN_LOCK_SCREEN'),
                TextButton(
                    onPressed: () => context.push('/recovery/app-pin'),
                    child: const Text('OPEN_RECOVERY')),
              ]))),
      GoRoute(
          path: '/recovery/app-pin',
          builder: (_, __) => const AppPinRecoveryScreen()),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('LOGIN_SCREEN'))),
      GoRoute(
          path: '/home_loading',
          builder: (_, __) => const Scaffold(body: Text('PIN_LOCK_SCREEN'))),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced),
            child: child!),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_RECOVERY'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester,
      {String password = 'PUBLIC_FIXTURE_PASSWORD',
      String pin = '1234',
      String confirm = '1234'}) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), password);
    await tester.enterText(fields.at(1), pin);
    await tester.enterText(fields.at(2), confirm);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, {bool duplicate = false}) async {
    final button = find.widgetWithText(FilledButton, 'Confirmar com passkey');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final action = tester.widget<FilledButton>(button).onPressed!;
    action();
    if (duplicate) action();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'requires account password and matching four-digit PIN before calling passkey',
      (tester) async {
    await open(tester);
    await submit(tester);
    expect(find.text('Digite a senha da conta.'), findsOneWidget);
    expect(recovery.challenges, 0);
    await fill(tester, pin: '123', confirm: '123');
    await submit(tester);
    expect(recovery.challenges, 0);
    await fill(tester, pin: '1234', confirm: '1235');
    await submit(tester);
    expect(find.text('Os PINs não coincidem.'), findsOneWidget);
    expect(recovery.challenges, 0);
    expect(recovery.posts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native fields limit PINs to four digits and success still requires unlocking',
      (tester) async {
    await open(tester);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    await fill(tester, pin: '12a345', confirm: '12345');
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[1].controller!.text, '1234');
    expect(fields[2].controller!.text, '1234');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(recovery.posts, 1);
    expect(recovery.body!['newPin'], '1234');
    expect(find.text('PIN redefinido'), findsOneWidget);
    final scope = container.read(sessionStorageScopeProvider)!;
    expect(prefs.getInt(appPinLengthPrefsKey(scope)), 4);
    expect(prefs.getBool(appPinConfiguredPrefsKey(scope)), isTrue);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(AppEntryPinSession.unlocked, isFalse);
    await tester.ensureVisible(find.text('Voltar para entrar'));
    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();
    expect(find.text('PIN_LOCK_SCREEN'), findsOneWidget);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
  });

  testWidgets(
      'duplicate submits and route back cannot multiply an in-flight request',
      (tester) async {
    recovery.pendingSign = Completer<void>();
    await open(tester);
    await fill(tester);
    await submit(tester, duplicate: true);
    expect(recovery.challenges, 1);
    expect(recovery.signatures, 1);
    expect(recovery.posts, 0);
    await router.routerDelegate.navigatorKey.currentState!.maybePop();
    await tester.pump();
    expect(find.byType(AppPinRecoveryScreen), findsOneWidget);
    recovery.pendingSign!.complete();
    await tester.pumpAndSettle();
    expect(recovery.posts, 1);
    expect(find.text('PIN redefinido'), findsOneWidget);
  });

  testWidgets(
      'cancelled platform passkey clears secrets without a recovery POST',
      (tester) async {
    recovery.signError = const DeviceKeyException(
        'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED', 'PUBLIC_FIXTURE_CANCELLED');
    await open(tester);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(recovery.posts, 0);
    expect(find.text('PIN redefinido'), findsNothing);
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text, isEmpty);
      expect(field.enabled, isTrue);
    }
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account change while passkey waits cannot transmit recovery',
      (tester) async {
    recovery.pendingSign = Completer<void>();
    await open(tester);
    await fill(tester);
    await submit(tester);
    (container.read(authControllerProvider.notifier) as _Auth).changeAccount();
    await tester.pump();
    recovery.pendingSign!.complete();
    await tester.pumpAndSettle();
    expect(recovery.posts, 0);
    expect(find.text('PIN redefinido'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    final scope = container.read(sessionStorageScopeProvider)!;
    expect(prefs.getBool(appPinConfiguredPrefsKey(scope)), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a captured action after signout cannot start recovery',
      (tester) async {
    await open(tester);
    await fill(tester);
    final action = tester
        .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar com passkey'))
        .onPressed!;
    (container.read(authControllerProvider.notifier) as _Auth).signOut();
    await tester.pumpAndSettle();
    action();
    await tester.pump();
    expect(recovery.challenges, 0);
    expect(recovery.posts, 0);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'late POST success after account change cannot write another account hints',
      (tester) async {
    recovery.pendingPost = Completer<void>();
    await open(tester);
    await fill(tester);
    await submit(tester);
    expect(recovery.posts, 1);
    final originalScope = container.read(sessionStorageScopeProvider)!;
    (container.read(authControllerProvider.notifier) as _Auth).changeAccount();
    await tester.pump();
    recovery.pendingPost!.complete();
    await tester.pumpAndSettle();
    expect(find.text('PIN redefinido'), findsNothing);
    expect(prefs.getBool(appPinConfiguredPrefsKey(originalScope)), isNull);
    final nextScope = container.read(sessionStorageScopeProvider)!;
    expect(prefs.getBool(appPinConfiguredPrefsKey(nextScope)), isNull);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backgrounding while passkey waits clears drafts and ignores completion',
      (tester) async {
    recovery.pendingSign = Completer<void>();
    await open(tester);
    await fill(tester);
    await submit(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    recovery.pendingSign!.complete();
    await tester.pumpAndSettle();
    expect(recovery.posts, 0);
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text, isEmpty);
    }
    expect(find.text('PIN redefinido'), findsNothing);
    expect(
        find.textContaining('A recuperação foi interrompida'), findsOneWidget);
    expect(container.read(appEntryPinUnlockedProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final malformed in [false, true]) {
    testWidgets(
        'failed or malformed response cannot claim completion: malformed=$malformed',
        (tester) async {
      if (malformed) {
        recovery.response = {};
      } else {
        recovery.postError = const NetworkException();
      }
      await open(tester);
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(recovery.posts, 1);
      expect(find.text('PIN redefinido'), findsNothing);
      expect(find.textContaining('Se a confirmação foi interrompida'),
          findsOneWidget);
      expect(container.read(appEntryPinUnlockedProvider), isFalse);
      final scope = container.read(sessionStorageScopeProvider)!;
      expect(prefs.getBool(appPinConfiguredPrefsKey(scope)), isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'remains usable on narrow windows with large text and motion enabled',
      (tester) async {
    await open(tester, size: const Size(320, 568), scale: 2, reduced: false);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('PIN redefinido'), findsOneWidget);
    await tester.ensureVisible(find.text('Voltar para entrar'));
    expect(tester.takeException(), isNull);
  });
}
