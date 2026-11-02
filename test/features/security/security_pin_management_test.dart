import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/domain/repositories/security_repository.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/security_app_pin_sheet.dart';
import 'package:kerosene/features/security/presentation/screens/security_change_result_screen.dart';
import '../../goldens/golden_harness.dart';

class PinManagementRepository implements SecurityRepository {
  int calls = 0;
  int reads = 0;
  bool readError = false;
  Completer<AppPinStatus>? pendingRead;
  AppPinStatus remoteStatus = const AppPinStatus();
  @override
  Future<Either<Failure, AppPinStatus>> getAppPinStatus() async {
    reads++;
    if (readError) return const Left(NetworkFailure());
    return Right(
        pendingRead == null ? remoteStatus : await pendingRead!.future);
  }

  bool throwError = false;
  AppPinStatus returned = const AppPinStatus(enabled: true, configured: true);
  Completer<void>? pending;
  String? submittedPin, submittedCurrent, submittedTotp;
  @override
  Future<Either<Failure, AppPinStatus>> configureAppPin(
      {required bool enabled,
      String? pin,
      String? currentPin,
      String? totpCode}) async {
    calls++;
    submittedPin = pin;
    submittedCurrent = currentPin;
    submittedTotp = totpCode;
    await pending?.future;
    if (throwError) throw StateError('PRIVATE-PIN-STACK');
    remoteStatus = returned;
    return Right(returned);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final pinManagementOwner =
    NotifierProvider<PinManagementOwner, String?>(PinManagementOwner.new);

class PinManagementOwner extends Notifier<String?> {
  @override
  String? build() => 'pin-owner-a';
  void change(String? value) => state = value;
}

Future<ProviderContainer> pumpPinManagement(
  WidgetTester tester, {
  required PinManagementRepository repository,
  AppPinSheetMode mode = AppPinSheetMode.enable,
  AppPinStatus initial = const AppPinStatus(),
  AppThemeVariant theme = AppThemeVariant.dark,
  double scale = 1,
}) async {
  repository.remoteStatus = initial;
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sharedPreferencesProvider.overrideWithValue(goldenSharedPreferences),
    sessionStorageScopeProvider
        .overrideWith((ref) => ref.watch(pinManagementOwner)),
    securityRepositoryProvider.overrideWithValue(repository),
    appPinStatusProvider.overrideWith((ref) async => repository.returned),
    accountSecurityProfileProvider.overrideWith((ref) async =>
        const AccountSecurityProfile(mode: AccountSecurityMode.standard)),
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
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => AppPinManagementSheet(
                              initialStatus: initial, mode: mode)),
                      child: const Text('Open PIN')))))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open PIN'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> fillPinManagement(WidgetTester tester,
    {String pin = '5678',
    String confirm = '5678',
    String? current,
    String? totp}) async {
  if (current != null) {
    await tester.enterText(
        find.byKey(const ValueKey('security-current-pin')), current);
  }
  if (totp != null) {
    await tester.enterText(
        find.byKey(const ValueKey('security-pin-totp')), totp);
  }
  if (find.byKey(const ValueKey('security-new-pin')).evaluate().isNotEmpty) {
    await tester.enterText(find.byKey(const ValueKey('security-new-pin')), pin);
    await tester.enterText(
        find.byKey(const ValueKey('security-confirm-pin')), confirm);
  }
  await tester.pump();
}

Future<void> submitPinManagement(WidgetTester tester,
    {bool duplicate = false}) async {
  final button = find.byKey(const ValueKey('security-save-pin'));
  await tester.ensureVisible(button);
  await tester.pump();
  final callback = tester.widget<FilledButton>(button).onPressed!;
  callback();
  if (duplicate) callback();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> finishPinManagement(WidgetTester tester) async {
  AppScreenFeedbackBus.clear();
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized()
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
  testWidgets(
      'local entry hints cannot enable management before a remote lookup',
      (tester) async {
    final repo = PinManagementRepository()
      ..pendingRead = Completer<AppPinStatus>();
    await pumpPinManagement(tester, repository: repo);
    expect(repo.reads, 1);
    expect(find.byType(TextField), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('security-save-pin')))
            .onPressed,
        isNull);
    repo.pendingRead!.complete(const AppPinStatus());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security-new-pin')), findsOneWidget);
    await finishPinManagement(tester);
  });

  testWidgets('failed first PIN query has a safe retry and no invented setup',
      (tester) async {
    final repo = PinManagementRepository()..readError = true;
    await pumpPinManagement(tester, repository: repo);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('PRIVATE'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('security-save-pin')))
            .onPressed,
        isNull);
    repo.readError = false;
    await tester.tap(find.byKey(const ValueKey('security-pin-status-retry')));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(find.byKey(const ValueKey('security-new-pin')), findsOneWidget);
    await finishPinManagement(tester);
  });

  testWidgets(
      'a captured submit cannot use stale PIN limits or omit new authorization',
      (tester) async {
    final repo = PinManagementRepository();
    final container = await pumpPinManagement(tester, repository: repo);
    await fillPinManagement(tester);
    final callback = tester
        .widget<FilledButton>(find.byKey(const ValueKey('security-save-pin')))
        .onPressed!;
    repo.pendingRead = Completer<AppPinStatus>();
    container.invalidate(appPinManagementStatusProvider);
    callback();
    await tester.pump();
    expect(repo.calls, 0);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('security-new-pin')))
            .enabled,
        isFalse);
    repo.pendingRead!.complete(const AppPinStatus(
        enabled: true, configured: true, minPinLength: 6, maxPinLength: 6));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security-current-pin')), findsOneWidget);
    expect(find.text('Alterar PIN'), findsOneWidget);
    await fillPinManagement(tester, pin: '123456', confirm: '123456');
    await submitPinManagement(tester);
    expect(repo.calls, 0);
    expect(find.textContaining('PIN atual'), findsWidgets);
    await finishPinManagement(tester);
  });

  testWidgets(
      'a failed write clears inputs and cannot be repeated without lookup',
      (tester) async {
    final repo = PinManagementRepository()..throwError = true;
    await pumpPinManagement(tester, repository: repo);
    await fillPinManagement(tester);
    final callback = tester
        .widget<FilledButton>(find.byKey(const ValueKey('security-save-pin')))
        .onPressed!;
    callback();
    await tester.pumpAndSettle();
    callback();
    await tester.pump();
    expect(repo.calls, 1);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('security-new-pin')))
            .controller!
            .text,
        isEmpty);
    expect(find.byKey(const ValueKey('security-pin-recheck')), findsOneWidget);
    expect(find.byType(SecurityChangeResultScreen), findsNothing);
    await finishPinManagement(tester);
  });

  testWidgets('invalid server limits do not build invalid text inputs',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial: const AppPinStatus(minPinLength: 8, maxPinLength: -1));
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SecurityChangeResultScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await finishPinManagement(tester);
  });

  testWidgets(
      'a locked PIN has no editable mutation until a fresh status unlocks it',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial:
            const AppPinStatus(enabled: true, configured: true, locked: true));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('security-save-pin')))
            .onPressed,
        isNull);
    repo.remoteStatus = const AppPinStatus(enabled: true, configured: true);
    await tester
        .ensureVisible(find.byKey(const ValueKey('security-pin-lock-refresh')));
    await tester.tap(find.byKey(const ValueKey('security-pin-lock-refresh')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('security-save-pin')))
            .onPressed,
        isNotNull);
    expect(repo.calls, 0);
    await finishPinManagement(tester);
  });

  testWidgets(
      'locked PIN reset uses the confirmed TOTP option and no current PIN',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial: const AppPinStatus(
            enabled: true,
            configured: true,
            locked: true,
            resettableWithTotp: true));
    await fillPinManagement(tester, current: '1234');
    await submitPinManagement(tester);
    expect(repo.calls, 0);
    await fillPinManagement(tester, totp: '123456');
    await submitPinManagement(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.submittedCurrent, isNull);
    expect(repo.submittedTotp, '123456');
    await finishPinManagement(tester);
  });

  for (final theme in AppThemeVariant.values) {
    testWidgets(
        'PIN waits for acknowledged status and displays a persistent result: $theme',
        (tester) async {
      final repo = PinManagementRepository()..pending = Completer<void>();
      await pumpPinManagement(tester,
          repository: repo, theme: theme, scale: 1.6);
      await fillPinManagement(tester);
      await submitPinManagement(tester, duplicate: true);
      expect(repo.calls, 1);
      expect(find.byType(SecurityChangeResultScreen), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('security-save-pin')))
              .onPressed,
          isNull);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('PIN configurado'), findsOneWidget);
      expect(find.byKey(const ValueKey('security-result-done')).hitTestable(),
          findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await finishPinManagement(tester);
    });
  }
  for (final status in [
    const AppPinStatus(enabled: false),
    const AppPinStatus(enabled: true, configured: false)
  ]) {
    testWidgets(
        'inconsistent server PIN state never announces success: ${status.enabled}',
        (tester) async {
      final repo = PinManagementRepository()..returned = status;
      await pumpPinManagement(tester, repository: repo);
      await fillPinManagement(tester);
      await submitPinManagement(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SecurityChangeResultScreen), findsNothing);
      expect(find.textContaining('Não foi possível confirmar a alteração'),
          findsOneWidget);
      await finishPinManagement(tester);
    });
  }
  testWidgets(
      'transport exception restores the action and exposes a safe error',
      (tester) async {
    final repo = PinManagementRepository()..throwError = true;
    await pumpPinManagement(tester, repository: repo);
    await fillPinManagement(tester);
    await submitPinManagement(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-PIN'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('security-save-pin')))
            .onPressed,
        isNull);
    repo.throwError = false;
    await tester
        .ensureVisible(find.byKey(const ValueKey('security-pin-recheck')));
    await tester.tap(find.byKey(const ValueKey('security-pin-recheck')));
    await tester.pumpAndSettle();
    await fillPinManagement(tester);
    await submitPinManagement(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('PIN configurado'), findsOneWidget);
    await finishPinManagement(tester);
  });
  testWidgets(
      'server length bounds and confirmation are validated before sending',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial: const AppPinStatus(minPinLength: 6, maxPinLength: 6));
    await fillPinManagement(tester, pin: '1234', confirm: '1234');
    await submitPinManagement(tester);
    expect(repo.calls, 0);
    expect(find.textContaining('Use de 6 a 6 dígitos'), findsOneWidget);
    await fillPinManagement(tester, pin: '123456', confirm: '123457');
    await submitPinManagement(tester);
    expect(repo.calls, 0);
    await finishPinManagement(tester);
  });
  testWidgets(
      'a configured PIN requires authorization even when its enabled preference is false',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial: const AppPinStatus(configured: true),
        mode: AppPinSheetMode.change);
    await fillPinManagement(tester);
    await submitPinManagement(tester);
    expect(repo.calls, 0);
    await fillPinManagement(tester, current: '1234');
    await submitPinManagement(tester);
    await tester.pumpAndSettle();
    expect(repo.submittedCurrent, '1234');
    expect(find.text('PIN atualizado'), findsOneWidget);
    await finishPinManagement(tester);
  });
  testWidgets(
      'TOTP reset preserves its required factor and does not send a partial current PIN',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester,
        repository: repo,
        initial: const AppPinStatus(
            enabled: true, configured: true, resettableWithTotp: true),
        mode: AppPinSheetMode.change);
    await fillPinManagement(tester, current: '1', totp: '123456');
    await submitPinManagement(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.submittedCurrent, isNull);
    expect(repo.submittedTotp, '123456');
    await finishPinManagement(tester);
  });
  testWidgets(
      'a late reply cannot display success or old inputs under another account',
      (tester) async {
    final repo = PinManagementRepository()..pending = Completer<void>();
    final container = await pumpPinManagement(tester, repository: repo);
    await fillPinManagement(tester);
    await submitPinManagement(tester);
    container.read(pinManagementOwner.notifier).change('pin-owner-b');
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SecurityChangeResultScreen), findsNothing);
    await finishPinManagement(tester);
  });
  testWidgets('background clears PIN inputs and requires explicit input again',
      (tester) async {
    final repo = PinManagementRepository();
    await pumpPinManagement(tester, repository: repo);
    await fillPinManagement(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('security-new-pin')))
            .controller!
            .text,
        isEmpty);
    await finishPinManagement(tester);
  });
}
