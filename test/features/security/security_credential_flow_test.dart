import 'package:kerosene/features/security/presentation/screens/settings_devices_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_security_pane.dart';
import 'package:kerosene/features/security/presentation/screens/security_app_pin_sheet.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/presentation/screens/settings_section_components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart'
    show securityStatusProvider;
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart'
    show AccountSecurityStatusResult;
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/security_credential_enrollment_screen.dart';
import 'package:kerosene/features/security/presentation/screens/security_profile_view.dart';
import '../../goldens/golden_harness.dart';

final credentialAlice = User(
    id: 'public-account-identifier-1234567890',
    username: 'alice',
    createdAt: DateTime(2020));
final credentialBob =
    User(id: 'bob-identifier', username: 'bob', createdAt: DateTime(2020));

class CredentialUiController extends AuthController {
  int calls = 0;
  final confirmations = <bool>[];
  Completer<PasskeyRegisterResult>? pending;
  final results = <PasskeyRegisterResult>[];
  bool throwError = false;
  @override
  AuthState build() => AuthAuthenticated(credentialAlice);
  @override
  Future<PasskeyRegisterResult> registerPasskey(
      {bool confirmUnlinkDevice = false}) async {
    calls++;
    confirmations.add(confirmUnlinkDevice);
    if (throwError) throw StateError('PRIVATE-STACK');
    if (pending != null) return pending!.future;
    return results.isNotEmpty
        ? results.removeAt(0)
        : const PasskeyRegisterResult.success();
  }

  void change(AuthState next) => state = next;
}

class CredentialProfileFixture {
  bool fail = false;
  Completer<AccountSecurityProfile>? pending;
  int reads = 0;
  Future<AccountSecurityProfile> load() async {
    reads++;
    if (fail) throw StateError('PRIVATE-PROFILE-STACK');
    return pending == null
        ? const AccountSecurityProfile(mode: AccountSecurityMode.standard)
        : await pending!.future;
  }
}

Future<ProviderContainer> pumpCredentialUi(
  WidgetTester tester, {
  required CredentialUiController controller,
  CredentialProfileFixture? profile,
  Widget? child,
  AppThemeVariant theme = AppThemeVariant.dark,
  double scale = 1,
  Future<AppPinStatus> Function()? pinLookup,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final data = profile ?? CredentialProfileFixture();
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sharedPreferencesProvider.overrideWithValue(goldenSharedPreferences),
    authControllerProvider.overrideWith(() => controller),
    sessionStorageScopeProvider.overrideWith((ref) {
      final auth = ref.watch(authControllerProvider);
      return auth is AuthAuthenticated
          ? sessionStorageScopeFromUser(
              userId: auth.user.id, username: auth.user.username)
          : null;
    }),
    accountSecurityProfileProvider.overrideWith((ref) {
      ref.watch(sessionStorageScopeProvider);
      return data.load();
    }),
    securityStatusProvider.overrideWith((ref) async =>
        const AccountSecurityStatusResult(passwordConfigured: true)),
    if (pinLookup != null)
      appPinManagementStatusProvider.overrideWith((ref) => pinLookup()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(theme),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          home: child ??
              Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => openCredentialEnrollment(context),
                          child: const Text('Start registration')))))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return container;
}

Future<void> startCredentialUi(WidgetTester tester,
    {bool twice = false}) async {
  final callback = tester
      .widget<TextButton>(find.widgetWithText(TextButton, 'Start registration'))
      .onPressed!;
  callback();
  if (twice) callback();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> finishCredentialUi(WidgetTester tester) async {
  AppScreenFeedbackBus.clear();
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    testWidgets(
        'enrollment waits for acknowledgement, preserves complete data and persistent result: $theme',
        (tester) async {
      final controller = CredentialUiController()
        ..pending = Completer<PasskeyRegisterResult>();
      await pumpCredentialUi(tester,
          controller: controller, theme: theme, scale: 1.6);
      await startCredentialUi(tester, twice: true);
      expect(controller.calls, 1);
      expect(find.byType(SecurityCredentialEnrollmentScreen), findsOneWidget);
      expect(find.text('Vinculando este aparelho'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text(credentialAlice.id), findsOneWidget);
      expect(find.text('Chave de acesso vinculada'), findsNothing);
      final route = ModalRoute.of(
          tester.element(find.byType(SecurityCredentialEnrollmentScreen)))!;
      expect(route.transitionDuration, Duration.zero);
      controller.pending!.complete(const PasskeyRegisterResult.success());
      await tester.pumpAndSettle();
      expect(find.text('Chave de acesso vinculada'), findsOneWidget);
      expect(
          find
              .byKey(const ValueKey('credential-enrollment-devices'))
              .hitTestable(),
          findsOneWidget);
      expect(
          find
              .byKey(const ValueKey('credential-enrollment-close'))
              .hitTestable(),
          findsOneWidget);
      await finishCredentialUi(tester);
    });
  }
  testWidgets(
      'a late success cannot display the previous account after a session switch',
      (tester) async {
    final controller = CredentialUiController()
      ..pending = Completer<PasskeyRegisterResult>();
    await pumpCredentialUi(tester, controller: controller);
    await startCredentialUi(tester);
    controller.change(AuthAuthenticated(credentialBob));
    await tester.pump();
    expect(find.text('alice'), findsNothing);
    expect(find.text(credentialAlice.id), findsNothing);
    controller.pending!.complete(const PasskeyRegisterResult.success());
    await tester.pumpAndSettle();
    expect(find.text('A sessão mudou'), findsOneWidget);
    expect(find.text('Chave de acesso vinculada'), findsNothing);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'conflict confirmation is account-bound and submits consent only once',
      (tester) async {
    final controller = CredentialUiController()
      ..results.addAll([
        const PasskeyRegisterResult.deviceConflict(
            message: 'PRIVATE-SERVER-GUIDANCE',
            data: {'previousUsernameMasked': 'al***'}),
        const PasskeyRegisterResult.success()
      ]);
    await pumpCredentialUi(tester, controller: controller);
    await startCredentialUi(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('al***'), findsOneWidget);
    expect(find.textContaining('PRIVATE-SERVER'), findsNothing);
    final confirm = find.byKey(const ValueKey('settings-account-confirm'));
    expect(confirm.hitTestable(), findsOneWidget);
    final callback = tester.widget<AppButton>(confirm).onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(controller.confirmations, [false, true]);
    expect(find.text('Chave de acesso vinculada'), findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'account switch while confirming conflict closes the dialog without retrying',
      (tester) async {
    final controller = CredentialUiController()
      ..results
          .add(const PasskeyRegisterResult.deviceConflict(message: 'conflict'));
    await pumpCredentialUi(tester, controller: controller);
    await startCredentialUi(tester);
    controller.change(AuthAuthenticated(credentialBob));
    await tester.pumpAndSettle();
    expect(controller.calls, 1);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('A sessão mudou'), findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'an exception produces a safe unconfirmed result and a deliberate retry',
      (tester) async {
    final controller = CredentialUiController()..throwError = true;
    await pumpCredentialUi(tester, controller: controller);
    await startCredentialUi(tester);
    await tester.pumpAndSettle();
    expect(find.text('Vinculação não confirmada'), findsOneWidget);
    expect(find.textContaining('PRIVATE-STACK'), findsNothing);
    controller.throwError = false;
    await tester.tap(find.byKey(const ValueKey('credential-enrollment-retry')));
    await tester.pumpAndSettle();
    expect(controller.calls, 2);
    expect(find.text('Chave de acesso vinculada'), findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets('missing local credentials explains the actual setup step',
      (tester) async {
    final controller = CredentialUiController()
      ..results.add(const PasskeyRegisterResult.failure(
          message: 'internal',
          errorCode: 'ERR_AUTH_DEVICE_KEY_NO_LOCAL_CREDENTIALS'));
    await pumpCredentialUi(tester, controller: controller);
    await startCredentialUi(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Configure a biometria ou o bloqueio de tela'),
        findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'security profile retains its last lookup on error and disables mutations until refresh',
      (tester) async {
    final profile = CredentialProfileFixture();
    final container = await pumpCredentialUi(tester,
        controller: CredentialUiController(),
        profile: profile,
        child: Scaffold(
            body: SingleChildScrollView(
                child: SecurityProfileView(
                    builder: (data, current) => Column(children: [
                          const Text('last known security'),
                          TextButton(
                              onPressed: current ? () {} : null,
                              child: const Text('Change security'))
                        ])))));
    expect(find.text('last known security'), findsOneWidget);
    profile.fail = true;
    container.invalidate(accountSecurityProfileProvider);
    await tester.pumpAndSettle();
    expect(find.text('last known security'), findsOneWidget);
    expect(find.textContaining('Última consulta:'), findsOneWidget);
    expect(
        find.textContaining('Não foi possível atualizar os dados de segurança'),
        findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Change security'))
            .onPressed,
        isNull);
    profile.fail = false;
    await tester.tap(find.byKey(const ValueKey('security-profile-retry')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Change security'))
            .onPressed,
        isNotNull);
    expect(
        find.textContaining('Não foi possível atualizar os dados de segurança'),
        findsNothing);
    await finishCredentialUi(tester);
  });
  testWidgets('security pane opens the same persistent enrollment flow',
      (tester) async {
    final controller = CredentialUiController()
      ..pending = Completer<PasskeyRegisterResult>();
    await pumpCredentialUi(tester,
        controller: controller,
        child: const Scaffold(
            body: SingleChildScrollView(child: SettingsSecurityPane())));
    final row = find
        .ancestor(
            of: find.text('Chave de acesso'),
            matching: find.byType(SettingsSectionRow))
        .first;
    final callback = tester.widget<SettingsSectionRow>(row).onTap!;
    callback();
    callback();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.calls, 1);
    expect(find.byType(SecurityCredentialEnrollmentScreen), findsOneWidget);
    controller.pending!.complete(const PasskeyRegisterResult.success());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('credential-enrollment-close')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSecurityPane), findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets('PIN entry stays single across a parent rebuild', (tester) async {
    late StateSetter rebuildParent;
    final lookup = Completer<AppPinStatus>();
    await pumpCredentialUi(tester,
        controller: CredentialUiController(),
        pinLookup: () => lookup.future,
        child: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          rebuildParent = setState;
          return SingleChildScrollView(child: SettingsSecurityPane());
        })));
    final tr =
        AppLocalizations.of(tester.element(find.byType(SettingsSecurityPane)))!;
    Finder pinRow() => find
        .ancestor(
            of: find.text(tr.settingsSecurityChangePinTitle,
                skipOffstage: false),
            matching: find.byType(SettingsSectionRow, skipOffstage: false))
        .first;
    tester.widget<SettingsSectionRow>(pinRow()).onTap!();
    await tester.pump();
    rebuildParent(() {});
    await tester.pump();
    tester.widget<SettingsSectionRow>(pinRow()).onTap!();
    await tester.pump();
    expect(find.byType(AppPinManagementSheet, skipOffstage: false),
        findsOneWidget);
    lookup.complete(const AppPinStatus());
    await tester.pumpAndSettle();
    await finishCredentialUi(tester);
  });
  testWidgets(
      'devices entry returns to its existing list instead of creating a duplicate',
      (tester) async {
    final controller = CredentialUiController();
    await pumpCredentialUi(tester,
        controller: controller, child: const SettingsDevicesScreen());
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Vincular este aparelho');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('credential-enrollment-devices')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDevicesScreen), findsOneWidget);
    expect(find.byType(SecurityCredentialEnrollmentScreen), findsNothing);
    expect(controller.calls, 1);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'devices refresh presents failure without leaking the future error',
      (tester) async {
    final profile = CredentialProfileFixture();
    await pumpCredentialUi(tester,
        controller: CredentialUiController(),
        profile: profile,
        child: const SettingsDevicesScreen());
    await tester.pumpAndSettle();
    profile.fail = true;
    final refreshing = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await expectLater(refreshing, completes);
    expect(find.textContaining('Última consulta:'), findsOneWidget);
    expect(find.textContaining('PRIVATE-PROFILE-STACK'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Vincular este aparelho'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    await finishCredentialUi(tester);
  });

  testWidgets('stale security data disables the actual enrollment entry',
      (tester) async {
    final profile = CredentialProfileFixture();
    final container = await pumpCredentialUi(tester,
        controller: CredentialUiController(),
        profile: profile,
        child: const Scaffold(
            body: SingleChildScrollView(child: SettingsSecurityPane())));
    profile.fail = true;
    container.invalidate(accountSecurityProfileProvider);
    await tester.pumpAndSettle();
    final row = find
        .ancestor(
            of: find.text('Chave de acesso'),
            matching: find.byType(SettingsSectionRow))
        .first;
    expect(tester.widget<SettingsSectionRow>(row).onTap, isNull);
    expect(find.textContaining('Última consulta:'), findsOneWidget);
    await finishCredentialUi(tester);
  });
  testWidgets(
      'old security data disappears immediately when a new account loads',
      (tester) async {
    final profile = CredentialProfileFixture();
    final controller = CredentialUiController();
    await pumpCredentialUi(tester,
        controller: controller,
        profile: profile,
        child: Scaffold(
            body: SecurityProfileView(
                builder: (_, __) => const Text('old account security'))));
    profile.pending = Completer<AccountSecurityProfile>();
    controller.change(AuthAuthenticated(credentialBob));
    await tester.pump();
    expect(find.text('old account security'), findsNothing);
    profile.pending!.complete(
        const AccountSecurityProfile(mode: AccountSecurityMode.standard));
    await tester.pumpAndSettle();
    await finishCredentialUi(tester);
  });
}
