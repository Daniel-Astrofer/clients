import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/security/presentation/screens/notification_device_components.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_notifications_pane.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';
import '../../goldens/golden_harness.dart';

const deviceFixture = DeviceToken(
  id: '12345678901234567890',
  platform: 'Android',
  tokenRef: 'public-notification-reference-complete-1234567890',
  deviceRef: 'public-device-reference-complete-1234567890',
  appVersion: '1.2.3',
  active: true,
);

class NotificationDeviceRepositoryFixture extends Mock
    implements NotificationRepository {
  List<DeviceToken> devices = [deviceFixture];
  bool failRead = false;
  int revokes = 0;
  Completer<Either<Failure, void>>? pending;
  @override
  Future<Either<Failure, List<DeviceToken>>> activeDeviceTokens() async =>
      failRead
          ? const Left(ServerFailure(message: 'PRIVATE-DIAGNOSTIC'))
          : Right(devices);
  @override
  Future<Either<Failure, void>> revokeDeviceToken(String id) async {
    revokes++;
    final result = pending == null
        ? const Right<Failure, void>(null)
        : await pending!.future;
    if (result.isRight()) {
      devices = devices.where((item) => item.id != id).toList();
    }
    return result;
  }
}

class NotificationDeviceSessionFixture extends MockAuthController {
  NotificationDeviceSessionFixture()
      : super(
            initialOverride: AuthAuthenticated(User(
                id: 'account-a',
                username: 'conta',
                createdAt: DateTime(2020))));
  void change(AuthState next) => state = next;
}

Future<ProviderContainer> pumpNotificationDevices(
    WidgetTester tester, NotificationDeviceRepositoryFixture repository,
    {NotificationDeviceSessionFixture? session,
    AppThemeVariant theme = AppThemeVariant.dark,
    double textScale = 1,
    Size size = const Size(320, 640)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sharedPreferencesProvider.overrideWithValue(goldenSharedPreferences),
    authControllerProvider
        .overrideWith(() => session ?? NotificationDeviceSessionFixture()),
    notificationRepositoryProvider.overrideWithValue(repository),
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
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true),
          child: child!),
      home: const Scaffold(
          body: SingleChildScrollView(child: SettingsNotificationsPane())),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(initializeGoldenHarness);
  testWidgets('disabling notifications requires a device-specific decision',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    await pumpNotificationDevices(tester, repository);
    final action =
        find.byKey(ValueKey('notification-device-disable-${deviceFixture.id}'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(deviceFixture.id), findsWidgets);
    expect(find.text(deviceFixture.deviceRef), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('failed refresh retains the known devices and disables mutations',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final container = await pumpNotificationDevices(tester, repository);
    expect(find.text(deviceFixture.id), findsOneWidget);
    repository.failRead = true;
    container.invalidate(activeDeviceTokensProvider);
    await tester.pumpAndSettle();
    expect(find.text('Android'), findsOneWidget);
    expect(find.text(deviceFixture.id), findsOneWidget);
    expect(find.textContaining('PRIVATE-DIAGNOSTIC'), findsNothing);
    await tester.ensureVisible(find
        .byKey(ValueKey('notification-device-disable-${deviceFixture.id}')));
    await tester.tap(find
        .byKey(ValueKey('notification-device-disable-${deviceFixture.id}')));
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    expect(find.textContaining('Última consulta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openDecision(WidgetTester tester) async {
    final action =
        find.byKey(ValueKey('notification-device-disable-${deviceFixture.id}'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Future<void> confirmDecision(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-account-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets(
      'a recognized response leaves a persistent result and refreshed list',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    await pumpNotificationDevices(tester, repository);
    await openDecision(tester);
    await confirmDecision(tester);
    await tester.pumpAndSettle();
    expect(repository.revokes, 1);
    expect(find.text('Notificações desativadas'), findsOneWidget);
    expect(find.text(deviceFixture.id), findsOneWidget);
    expect(find.text('Nenhum registro ativo'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-device-result-refresh')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    AppScreenFeedbackBus.clear();
  });

  testWidgets(
      'an inconclusive response never announces success or exposes diagnostics',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture()
      ..pending = Completer();
    await pumpNotificationDevices(tester, repository);
    await openDecision(tester);
    await confirmDecision(tester);
    repository.failRead = true;
    repository.pending!
        .completeError(StateError('PRIVATE-TRANSPORT-DIAGNOSTIC'));
    await tester.pumpAndSettle();
    expect(find.text('Alteração não confirmada'), findsOneWidget);
    expect(find.text('Notificações desativadas'), findsNothing);
    expect(find.textContaining('PRIVATE-TRANSPORT'), findsNothing);
    expect(find.textContaining('Atualize a lista antes'), findsOneWidget);
    expect(find.text(deviceFixture.id), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    AppScreenFeedbackBus.clear();
  });

  testWidgets('a decision closes after account change without making a request',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final session = NotificationDeviceSessionFixture();
    await pumpNotificationDevices(tester, repository, session: session);
    await openDecision(tester);
    session.change(const AuthUnauthenticated());
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(deviceFixture.id), findsNothing);
  });

  testWidgets('an old response never appears in another account',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture()
      ..pending = Completer();
    final session = NotificationDeviceSessionFixture();
    await pumpNotificationDevices(tester, repository, session: session);
    await openDecision(tester);
    await confirmDecision(tester);
    repository.devices = [];
    session.change(AuthAuthenticated(
        User(id: 'account-b', username: 'outra', createdAt: DateTime(2020))));
    await tester.pumpAndSettle();
    repository.pending!.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(find.text('Notificações desativadas'), findsNothing);
    expect(find.text(deviceFixture.id), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding cancels an open decision', (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    await pumpNotificationDevices(tester, repository);
    await openDecision(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(repository.revokes, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changed registration data cannot authorize the old decision',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final container = await pumpNotificationDevices(tester, repository);
    await openDecision(tester);
    repository.devices = [
      DeviceToken(
          id: deviceFixture.id,
          platform: 'Linux',
          tokenRef: 'new-reference',
          deviceRef: 'other-device',
          appVersion: '2',
          active: true)
    ];
    container.invalidate(activeDeviceTokensProvider);
    await tester.pumpAndSettle();
    await confirmDecision(tester);
    expect(repository.revokes, 0);
    expect(find.text('Linux'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(AppScreenFeedbackBus.current.value?.message,
        'Confira a lista atualizada e confirme este aparelho novamente.');
    AppScreenFeedbackBus.clear();
  });

  testWidgets('repeated callbacks cannot open decisions or submit twice',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture()
      ..pending = Completer();
    await pumpNotificationDevices(tester, repository);
    final callback = tester
        .widget<NotificationDeviceRegistrationCard>(
            find.byType(NotificationDeviceRegistrationCard))
        .onDisable!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(repository.revokes, 0);
    await confirmDecision(tester);
    callback();
    await tester.pump();
    expect(repository.revokes, 1);
    expect(find.text('Desativando…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pending!.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a captured action remains bound to its displayed account',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final session = NotificationDeviceSessionFixture();
    await pumpNotificationDevices(tester, repository, session: session);
    final callback = tester
        .widget<NotificationDeviceRegistrationCard>(
            find.byType(NotificationDeviceRegistrationCard))
        .onDisable!;
    session.change(AuthAuthenticated(
        User(id: 'account-b', username: 'outra', createdAt: DateTime(2020))));
    await tester.pumpAndSettle();
    callback();
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the action notice cannot follow a change of account',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final session = NotificationDeviceSessionFixture();
    await pumpNotificationDevices(tester, repository, session: session);
    await openDecision(tester);
    await confirmDecision(tester);
    await tester.pumpAndSettle();
    expect(
        AppScreenFeedbackBus.current.value?.title, 'Notificações desativadas');
    session.change(const AuthUnauthenticated());
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(find.text('Notificações desativadas'), findsNothing);
  });

  testWidgets('account cleanup preserves an unrelated newer notice',
      (tester) async {
    final repository = NotificationDeviceRepositoryFixture();
    final session = NotificationDeviceSessionFixture();
    await pumpNotificationDevices(tester, repository, session: session);
    await openDecision(tester);
    await confirmDecision(tester);
    await tester.pumpAndSettle();
    AppScreenFeedbackBus.show(
        type: AppNoticeType.info, title: 'Network', message: 'Public fixture');
    final unrelated = AppScreenFeedbackBus.current.value;
    session.change(const AuthUnauthenticated());
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value, same(unrelated));
    AppScreenFeedbackBus.clear();
  });

  testWidgets(
      'platform codes have recognizable names without inventing unknown devices',
      (tester) async {
    const platforms = ['ANDROID', 'IOS', 'WEB', 'NewPlatform'];
    final repository = NotificationDeviceRepositoryFixture()
      ..devices = [
        for (var index = 0; index < platforms.length; index++)
          DeviceToken(
              id: '${index + 1}',
              platform: platforms[index],
              tokenRef: '',
              deviceRef: '',
              appVersion: '',
              active: true),
      ];
    await pumpNotificationDevices(tester, repository);
    for (final label in ['Android', 'iOS', 'Web', 'NewPlatform']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
