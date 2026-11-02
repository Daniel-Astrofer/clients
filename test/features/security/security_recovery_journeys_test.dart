import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/features/security/presentation/screens/security_change_result_screen.dart';
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/feedback/app_screen_feedback_host.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/domain/entities/account_security_change_factors.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';
import 'package:kerosene/features/security/application/security_change_authorizer.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';
import 'package:kerosene/features/security/domain/repositories/security_repository.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_pin_authorization.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/security_totp_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_backup_codes_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_recovery_hub_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_section_components.dart';
import 'package:kerosene/features/auth/presentation/screens/emergency_recovery_screen.dart';
import 'package:kerosene/features/security/presentation/widgets/recovery_codes_sheet.dart';

final _scopeProvider = NotifierProvider<_Scope, String?>(_Scope.new);

class _Scope extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change(String next) => state = next;
}

const _codes = [
  'PUB-0001',
  'PUB-0002',
  'PUB-0003',
  'PUB-0004',
  'PUB-0005',
  'PUB-0006',
  'PUB-0007',
  'PUB-0008',
  'PUB-0009',
  'PUB-0010'
];

class _Repository implements AuthRepository {
  bool enabled = false;
  Completer<Either<Failure, AccountSecurityStatusResult>>? pendingSecurity;
  Completer<Either<Failure, BackupCodesStatusResult>>? pendingBackup;
  int verifies = 0;
  int regenerations = 0;
  int disables = 0;
  bool malformed = false;
  AccountSecurityChangeFactors? submitted;
  Completer<Either<Failure, TotpSetupResult>>? pendingSetup;
  @override
  Future<Either<Failure, TotpSetupResult>> setupTotp() async {
    if (pendingSetup != null) return pendingSetup!.future;
    return const Right(TotpSetupResult(
        otpUri: 'otpauth://totp/fixture?secret=JBSWY3DPEHPK3PXP',
        secret: 'PUBLIC-SECRET'));
  }

  @override
  Future<Either<Failure, BackupCodesStatusResult>> verifyTotpSetup(
      {required String totpCode}) async {
    verifies++;
    enabled = !malformed;
    return Right(BackupCodesStatusResult(
        enabled: enabled,
        remainingCodes: enabled ? 10 : 0,
        newlyGeneratedCodes: enabled ? _codes : const []));
  }

  @override
  Future<Either<Failure, AccountSecurityStatusResult>>
      getSecurityStatus() async {
    if (pendingSecurity != null) return pendingSecurity!.future;
    return Right(AccountSecurityStatusResult(totpEnabled: enabled));
  }

  @override
  Future<Either<Failure, BackupCodesStatusResult>>
      getBackupCodesStatus() async {
    if (pendingBackup != null) return pendingBackup!.future;
    return Right(BackupCodesStatusResult(
        enabled: enabled, remainingCodes: enabled ? 10 : 0));
  }

  @override
  Future<Either<Failure, BackupCodesStatusResult>> regenerateBackupCodes({
    AccountSecurityChangeFactors factors = const AccountSecurityChangeFactors(),
  }) async {
    regenerations++;
    submitted = factors;
    return const Right(BackupCodesStatusResult(
        enabled: true, remainingCodes: 10, newlyGeneratedCodes: _codes));
  }

  @override
  Future<Either<Failure, void>> disableTotp({
    AccountSecurityChangeFactors factors = const AccountSecurityChangeFactors(),
  }) async {
    disables++;
    submitted = factors;
    enabled = false;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Authorizer extends SecurityChangeAuthorizer {
  _Authorizer(super.ref);
  int calls = 0;
  @override
  Future<AccountSecurityChangeFactors> authorize(
      {required String expectedScope,
      required bool requiresPasskey,
      required AccountSecurityChangeFactors manualFactors}) async {
    calls++;
    expect(expectedScope, 'owner-a');
    expect(requiresPasskey, isTrue);
    return const AccountSecurityChangeFactors(
        passkeyAssertionJson: 'PUBLIC-PROOF');
  }
}

class _SecurityRepository implements SecurityRepository {
  @override
  Future<Either<Failure, AppPinStatus>> verifyAppPin(
      {required String pin}) async {
    expect(pin, '1234');
    return const Right(AppPinStatus(
        enabled: true, configured: true, minPinLength: 4, maxPinLength: 4));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _app(_Repository repo, Widget page,
        {AccountSecurityMode mode = AccountSecurityMode.standard,
        double scale = 1,
        Future<AccountSecurityProfile> Function()? profileLoader,
        void Function(_Authorizer)? onAuthorizer}) =>
    ProviderScope(
        retry: (_, __) => null,
        overrides: [
          sessionStorageScopeProvider
              .overrideWith((ref) => ref.watch(_scopeProvider)),
          authRepositoryProvider.overrideWithValue(repo),
          securityRepositoryProvider.overrideWithValue(_SecurityRepository()),
          securityStatusProvider.overrideWith((ref) async =>
              (await repo.getSecurityStatus()).fold(
                  (failure) => throw Exception(failure.message),
                  (value) => value)),
          backupCodesStatusProvider.overrideWith((ref) async =>
              (await repo.getBackupCodesStatus()).fold(
                  (failure) => throw Exception(failure.message),
                  (value) => value)),
          accountSecurityProfileProvider.overrideWith((ref) async =>
              profileLoader != null
                  ? await profileLoader()
                  : AccountSecurityProfile(
                      mode: mode,
                      appPin: const AppPinStatus(
                          enabled: true,
                          configured: true,
                          minPinLength: 4,
                          maxPinLength: 4))),
          securityChangeAuthorizerProvider.overrideWith((ref) {
            final value = _Authorizer(ref);
            onAuthorizer?.call(value);
            return value;
          }),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: AppScreenFeedbackHost(child: child!)),
            home: page));
Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  for (final totpScreen in [true, false]) {
    testWidgets(
        'security lookups retain data and disable stale mutations: $totpScreen',
        (tester) async {
      final repo = _Repository()..enabled = true;
      await tester.pumpWidget(_app(
          repo,
          totpScreen
              ? const SecurityTotpScreen()
              : const SettingsBackupCodesScreen(),
          scale: 1.4));
      await tester.pumpAndSettle();
      final container = _container(tester);
      final button = find
          .ancestor(
              of: find.text('Gerar novos códigos'),
              matching: find.byType(FilledButton))
          .first;
      final beforeRefresh = tester.widget<FilledButton>(button).onPressed!;
      repo.pendingBackup =
          Completer<Either<Failure, BackupCodesStatusResult>>();
      container.invalidate(backupCodesStatusProvider);
      // A previously captured callback must not bypass the new loading state.
      beforeRefresh();
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      expect(repo.regenerations, 0);
      expect(find.textContaining('10 códigos restantes'), findsOneWidget);
      expect(find.textContaining('Última consulta:'), findsWidgets);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      repo.pendingBackup!.complete(
          const Left(UnknownFailure(message: 'PRIVATE-LOOKUP-STACK')));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 códigos restantes'), findsOneWidget);
      expect(find.textContaining('PRIVATE-LOOKUP-STACK'), findsNothing);
      expect(find.textContaining('Não foi possível atualizar os dados'),
          findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      repo.pendingBackup = null;
      await tester
          .ensureVisible(find.byKey(const ValueKey('security-lookup-retry')));
      await tester.tap(find.byKey(const ValueKey('security-lookup-retry')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(find.textContaining('Não foi possível atualizar os dados'),
          findsNothing);
      await _finish(tester);
    });

    testWidgets(
        'unknown first lookup never offers an authenticator mutation: $totpScreen',
        (tester) async {
      final repo = _Repository()
        ..pendingSecurity =
            Completer<Either<Failure, AccountSecurityStatusResult>>()
        ..pendingBackup = Completer<Either<Failure, BackupCodesStatusResult>>();
      await tester.pumpWidget(_app(
          repo,
          totpScreen
              ? const SecurityTotpScreen()
              : const SettingsBackupCodesScreen()));
      await tester.pump();
      expect(find.text('Ativar autenticador'), findsNothing);
      expect(find.text('Autenticador desativado'), findsNothing);
      expect(find.textContaining('0 códigos restantes'), findsNothing);
      repo.pendingSecurity!
          .complete(const Left(UnknownFailure(message: 'PRIVATE-STATUS')));
      repo.pendingBackup!
          .complete(const Left(UnknownFailure(message: 'PRIVATE-CODES')));
      await tester.pumpAndSettle();
      expect(find.text('Ativar autenticador'), findsNothing);
      expect(find.text('Autenticador desativado'), findsNothing);
      expect(find.textContaining('0 códigos restantes'), findsNothing);
      expect(find.textContaining('PRIVATE-STATUS'), findsNothing);
      await _finish(tester);
    });

    testWidgets(
        'foreground refresh retains lookup and rejects another account: $totpScreen',
        (tester) async {
      final repo = _Repository()..enabled = true;
      await tester.pumpWidget(_app(
          repo,
          totpScreen
              ? const SecurityTotpScreen()
              : const SettingsBackupCodesScreen()));
      await tester.pumpAndSettle();
      final container = _container(tester);
      repo.pendingSecurity =
          Completer<Either<Failure, AccountSecurityStatusResult>>();
      repo.pendingBackup =
          Completer<Either<Failure, BackupCodesStatusResult>>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.textContaining('10 códigos restantes'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('10 códigos restantes'), findsOneWidget);
      expect(find.textContaining('Última consulta:'), findsWidgets);
      container.read(_scopeProvider.notifier).change('owner-b');
      repo.pendingSecurity!.complete(
          const Right(AccountSecurityStatusResult(totpEnabled: true)));
      repo.pendingBackup!.complete(const Right(
          BackupCodesStatusResult(enabled: true, remainingCodes: 3)));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 códigos restantes'), findsNothing);
      expect(find.textContaining('3 códigos restantes'), findsNothing);
      expect(find.textContaining('A sessão mudou'), findsOneWidget);
      await _finish(tester);
    });
  }

  testWidgets('unknown policy is not presented as optional protection',
      (tester) async {
    final profile = Completer<AccountSecurityProfile>();
    await tester.pumpWidget(_app(_Repository(), const SecurityTotpScreen(),
        profileLoader: () => profile.future));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Autenticador opcional'), findsNothing);
    final button = find
        .ancestor(
            of: find.text('Ativar autenticador'),
            matching: find.byType(FilledButton))
        .first;
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    profile.complete(
        const AccountSecurityProfile(mode: AccountSecurityMode.standard));
    await tester.pumpAndSettle();
    expect(find.text('Autenticador opcional'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await _finish(tester);
  });

  testWidgets(
      'setup progress is accurate and stale data cannot validate the code',
      (tester) async {
    final repo = _Repository()
      ..pendingSetup = Completer<Either<Failure, TotpSetupResult>>();
    await tester.pumpWidget(_app(repo, const SecurityTotpScreen()));
    await tester.pumpAndSettle();
    await _tap(tester, 'Ativar autenticador');
    expect(find.text('Preparando o autenticador…'), findsOneWidget);
    repo.pendingSetup!.complete(const Right(TotpSetupResult(
        otpUri: 'otpauth://totp/fixture?secret=JBSWY3DPEHPK3PXP',
        secret: 'PUBLIC-SECRET')));
    await tester.pumpAndSettle();
    final container = _container(tester);
    final input = find.byType(TextField).first;
    await tester.enterText(input, '123456');
    final button = find
        .ancestor(
            of: find.text('Validar código'),
            matching: find.byType(FilledButton))
        .first;
    final beforeRefresh = tester.widget<FilledButton>(button).onPressed!;
    repo.pendingSecurity =
        Completer<Either<Failure, AccountSecurityStatusResult>>();
    container.invalidate(securityStatusProvider);
    beforeRefresh();
    await tester.pump();
    expect(repo.verifies, 0);
    expect(find.text('PUBLIC-SECRET'), findsOneWidget);
    expect(tester.widget<TextField>(input).enabled, isFalse);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    repo.pendingSecurity!
        .complete(const Left(UnknownFailure(message: 'PRIVATE')));
    await tester.pumpAndSettle();
    expect(find.text('PUBLIC-SECRET'), findsOneWidget);
    expect(repo.verifies, 0);
    await _finish(tester);
  });

  testWidgets('late setup response cannot update a disposed screen',
      (tester) async {
    final repo = _Repository()
      ..pendingSetup = Completer<Either<Failure, TotpSetupResult>>();
    await tester.pumpWidget(_app(repo, const SecurityTotpScreen()));
    await tester.pumpAndSettle();
    final action = find.text('Ativar autenticador');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repo.pendingSetup!.complete(const Right(
        TotpSetupResult(otpUri: 'otpauth://fixture', secret: 'PUBLIC-SECRET')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('setup secrets never appear under another session',
      (tester) async {
    final repo = _Repository()
      ..pendingSetup = Completer<Either<Failure, TotpSetupResult>>();
    await tester.pumpWidget(_app(repo, const SecurityTotpScreen()));
    await tester.pumpAndSettle();
    final container = _container(tester);
    final action = find.text('Ativar autenticador');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    container.read(_scopeProvider.notifier).change('owner-b');
    await tester.pump();
    repo.pendingSetup!.complete(const Right(
        TotpSetupResult(otpUri: 'otpauth://fixture', secret: 'PUBLIC-SECRET')));
    await tester.pumpAndSettle();
    expect(find.text('PUBLIC-SECRET'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    await _finish(tester);
  });
  for (final malformed in [false, true]) {
    testWidgets(
        'verification requires digits and respects returned status: $malformed',
        (tester) async {
      final repo = _Repository()..malformed = malformed;
      await tester.pumpWidget(_app(repo, const SecurityTotpScreen()));
      await tester.pumpAndSettle();
      await _tap(tester, 'Ativar autenticador');
      await tester.enterText(find.byType(TextField).first, 'ABCDEF');
      await _tap(tester, 'Validar código');
      expect(repo.verifies, 0);
      await tester.enterText(find.byType(TextField).first, '123456');
      await _tap(tester, 'Validar código');
      expect(repo.verifies, 1);
      await tester.pumpAndSettle();
      expect(find.byType(SecurityChangeResultScreen),
          malformed ? findsNothing : findsOneWidget);
      if (!malformed) {
        await tester
            .tap(find.byKey(const ValueKey('security-result-view-codes')));
        await tester.pumpAndSettle();
        expect(find.byType(RecoveryCodesSheet), findsOneWidget);
      }
      if (malformed) {
        expect(find.textContaining('Não foi possível confirmar a alteração'),
            findsWidgets);
      }
      await _finish(tester);
    });
  }
  testWidgets('mandatory account mode cannot disable its authenticator',
      (tester) async {
    final repo = _Repository()..enabled = true;
    await tester.pumpWidget(_app(repo, const SecurityTotpScreen(),
        mode: AccountSecurityMode.shamir));
    await tester.pumpAndSettle();
    expect(find.text('Autenticador obrigatório'), findsOneWidget);
    final action = find.text('Desativar autenticador');
    await tester.ensureVisible(action);
    await tester.tap(action, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.disables, 0);
    expect(find.byType(Dialog), findsNothing);
    await _finish(tester);
  });
  for (final totpScreen in [false, true]) {
    testWidgets(
        'rotation sends authorization and codes remain usable at large text: $totpScreen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository()..enabled = true;
      await tester.pumpWidget(_app(
          repo,
          totpScreen
              ? const SecurityTotpScreen()
              : const SettingsBackupCodesScreen(),
          scale: 1.7));
      await tester.pumpAndSettle();
      await _tap(tester, 'Gerar novos códigos');
      expect(find.textContaining('os anteriores deixam de funcionar'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-account-confirm')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TransactionPinAuthorizationScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.pumpAndSettle();
      expect(repo.regenerations, 1);
      expect(repo.submitted!.passkeyAssertionJson, 'PUBLIC-PROOF');
      expect(find.byType(SecurityChangeResultScreen), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('security-result-view-codes')));
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryCodesSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Copiar todos'));
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  }
  testWidgets(
      'confirmation double tap creates one dialog and cancellation sends nothing',
      (tester) async {
    final repo = _Repository()..enabled = true;
    await tester.pumpWidget(_app(repo, const SettingsBackupCodesScreen()));
    await tester.pumpAndSettle();
    final action = find.text('Gerar novos códigos');
    await tester.ensureVisible(action);
    final button =
        find.ancestor(of: action, matching: find.byType(FilledButton)).first;
    final onPressed = tester.widget<FilledButton>(button).onPressed!;
    onPressed();
    onPressed();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);
    final cancel = find.widgetWithText(AppButton,
        AppLocalizations.of(tester.element(find.byType(Dialog)))!.cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(repo.regenerations, 0);
    await _finish(tester);
  });
  testWidgets(
      'codes stay hidden after background and disappear on account change',
      (tester) async {
    await tester.pumpWidget(_app(
        _Repository(),
        const Scaffold(
            body: RecoveryCodesSheet(codes: _codes, ownerScope: 'owner-a'))));
    await tester.pumpAndSettle();
    final container = _container(tester);
    expect(find.text('PUB-0001'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('PUB-0001'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('PUB-0001'), findsNothing);
    await _tap(tester, 'Mostrar códigos');
    expect(find.text('PUB-0001'), findsOneWidget);
    container.read(_scopeProvider.notifier).change('owner-b');
    await tester.pump();
    expect(find.text('PUB-0001'), findsNothing);
    await _finish(tester);
  });
  testWidgets(
      'recovery paths remain available when the first profile lookup fails',
      (tester) async {
    final repo = _Repository()
      ..pendingSecurity =
          Completer<Either<Failure, AccountSecurityStatusResult>>()
      ..pendingBackup = Completer<Either<Failure, BackupCodesStatusResult>>();
    await tester.pumpWidget(_app(repo, const SettingsRecoveryHubScreen(),
        profileLoader: () async => throw StateError('PRIVATE-PROFILE')));
    await tester.pump();
    repo.pendingSecurity!
        .complete(const Left(UnknownFailure(message: 'PRIVATE-STATUS')));
    repo.pendingBackup!
        .complete(const Left(UnknownFailure(message: 'PRIVATE-CODES')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-open-codes')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('recovery-open-emergency')), findsOneWidget);
    expect(find.textContaining('PRIVATE-'), findsNothing);
    expect(find.text('Inativo'), findsNothing);
    expect(find.textContaining('0 códigos restantes'), findsNothing);
    final emergency = find.byKey(const ValueKey('recovery-open-emergency'));
    await tester.ensureVisible(emergency);
    await tester.pumpAndSettle();
    await tester.tap(emergency);
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRecoveryScreen), findsOneWidget);
    expect(repo.regenerations, 0);
    expect(repo.disables, 0);
    await _finish(tester);
  });

  testWidgets(
      'hub retains known data on failure and hides it after account change',
      (tester) async {
    final repo = _Repository()..enabled = true;
    await tester
        .pumpWidget(_app(repo, const SettingsRecoveryHubScreen(), scale: 1.4));
    await tester.pumpAndSettle();
    final container = _container(tester);
    repo.pendingSecurity =
        Completer<Either<Failure, AccountSecurityStatusResult>>();
    repo.pendingBackup = Completer<Either<Failure, BackupCodesStatusResult>>();
    container.invalidate(securityStatusProvider);
    container.invalidate(backupCodesStatusProvider);
    await tester.pump();
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.textContaining('10 códigos restantes'), findsOneWidget);
    expect(find.textContaining('Última consulta:'), findsWidgets);
    repo.pendingSecurity!.complete(const Left(NetworkFailure()));
    repo.pendingBackup!.complete(const Left(NetworkFailure()));
    await tester.pumpAndSettle();
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.textContaining('10 códigos restantes'), findsOneWidget);
    expect(
        tester
            .widget<SettingsSectionRow>(
                find.byKey(const ValueKey('recovery-open-codes')))
            .onTap,
        isNotNull);
    container.read(_scopeProvider.notifier).change('owner-b');
    await tester.pump();
    expect(find.text('Ativo'), findsNothing);
    expect(find.textContaining('10 códigos restantes'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('hub navigation is single and carries the initiating account',
      (tester) async {
    await tester.pumpWidget(
        _app(_Repository()..enabled = true, const SettingsRecoveryHubScreen()));
    await tester.pumpAndSettle();
    final container = _container(tester);
    final row = tester.widget<SettingsSectionRow>(
        find.byKey(const ValueKey('recovery-open-codes')));
    row.onTap!();
    row.onTap!();
    container.read(_scopeProvider.notifier).change('owner-b');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsBackupCodesScreen), findsOneWidget);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    expect(find.text('Gerar novos códigos'), findsNothing);
    await _finish(tester);
  });

  testWidgets('a captured hub callback cannot navigate after account change',
      (tester) async {
    await tester
        .pumpWidget(_app(_Repository(), const SettingsRecoveryHubScreen()));
    await tester.pumpAndSettle();
    final container = _container(tester);
    final callback = tester
        .widget<SettingsSectionRow>(
            find.byKey(const ValueKey('recovery-open-emergency')))
        .onTap!;
    container.read(_scopeProvider.notifier).change('owner-b');
    callback();
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRecoveryScreen), findsNothing);
    await _finish(tester);
  });

  testWidgets(
      'recovery hub never treats missing or failed security as inactive',
      (tester) async {
    final repo = _Repository()
      ..pendingSecurity =
          Completer<Either<Failure, AccountSecurityStatusResult>>()
      ..pendingBackup = Completer<Either<Failure, BackupCodesStatusResult>>();
    await tester.pumpWidget(_app(repo, const SettingsRecoveryHubScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Inativo'), findsNothing);
    expect(find.textContaining('backup codes disponíveis'), findsNothing);
    repo.pendingSecurity!.complete(const Left(NetworkFailure()));
    repo.pendingBackup!.complete(const Left(NetworkFailure()));
    await tester.pumpAndSettle();
    expect(find.text('Inativo'), findsNothing);
    expect(find.text('Tentar Novamente'), findsOneWidget);
    await _finish(tester);
  });
  testWidgets(
      'clipboard failure is visible and never announces a copied result',
      (tester) async {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'fixture');
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(
        _Repository(),
        const Scaffold(
            body: RecoveryCodesSheet(
                codes: ['PUB-0001'], ownerScope: 'owner-a'))));
    await tester.pumpAndSettle();
    await _tap(tester, 'Copiar todos');
    expect(find.textContaining('Não foi possível copiar os códigos'),
        findsOneWidget);
    await _finish(tester);
  });
}
