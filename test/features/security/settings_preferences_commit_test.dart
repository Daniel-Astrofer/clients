import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';
import 'package:kerosene/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_appearance_pane.dart';
import 'package:kerosene/features/security/presentation/screens/settings_notifications_pane.dart';
import 'package:kerosene/features/security/presentation/screens/notification_settings_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_section_components.dart';

// Models the legacy plugin's optimistic cache independently of platform commit.
class _ControlledPreferences extends Mock implements SharedPreferences {
  final Map<String, bool> durable = {'appearance_dark_mode_enabled': true};
  late Map<String, bool> cache = Map.of(durable);
  bool acceptsWrites = true;
  Completer<bool>? pending;
  int writes = 0;
  int reloads = 0;

  @override
  bool? getBool(String key) => cache[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    writes++;
    cache[key] = value;
    final accepted = pending == null ? acceptsWrites : await pending!.future;
    if (accepted) durable[key] = value;
    return accepted;
  }

  @override
  Future<void> reload() async {
    reloads++;
    cache = Map.of(durable);
  }
}

class _DevicesRepository extends Mock implements NotificationRepository {
  final pending = Completer<Either<Failure, void>>();
  int calls = 0;
  @override
  Future<Either<Failure, void>> revokeDeviceToken(String tokenId) {
    calls++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alerts load synchronously and publish only after platform commit',
      () async {
    final prefs = _ControlledPreferences();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isTrue);
    prefs.pending = Completer<bool>();
    final save = container
        .read(alertPreferencesProvider.notifier)
        .setTransactionAlertsEnabled(false);
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isTrue);
    prefs.pending!.complete(true);
    await save;
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isFalse);
    expect(
        prefs.durable[AlertPreferencesNotifier.transactionAlertsKey], isFalse);
  });

  test('failed alert and appearance writes restore the optimistic cache',
      () async {
    final prefs = _ControlledPreferences()..acceptsWrites = false;
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await expectLater(
        container
            .read(alertPreferencesProvider.notifier)
            .setTransactionAlertsEnabled(false),
        throwsStateError);
    await expectLater(
        container.read(appearanceProvider.notifier).setDarkModeEnabled(false),
        throwsStateError);
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isTrue);
    expect(container.read(appearanceProvider).darkModeEnabled, isTrue);
    expect(
        prefs.getBool(AlertPreferencesNotifier.transactionAlertsKey), isNull);
    expect(prefs.getBool('appearance_dark_mode_enabled'), isTrue);
    expect(prefs.reloads, 2);
  });

  test('committed appearance and alert preferences survive provider recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    await first.read(appearanceProvider.notifier).setDarkModeEnabled(false);
    await first
        .read(alertPreferencesProvider.notifier)
        .setInAppBannersEnabled(false);
    first.dispose();
    final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(next.dispose);
    expect(next.read(appearanceProvider).darkModeEnabled, isFalse);
    expect(next.read(alertPreferencesProvider).inAppBannersEnabled, isFalse);
  });

  test(
      'privacy is loaded on the first frame and remains protected until save acknowledgement',
      () async {
    final prefs = _ControlledPreferences();
    prefs.durable[PrivacyPreferencesNotifier.blockScreenshotsKey] = true;
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    prefs.pending = Completer<bool>();
    final save = container
        .read(privacyPreferencesProvider.notifier)
        .setBlockFinancialScreenshots(false);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    prefs.pending!.complete(true);
    await save;
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isFalse);
  });
  test('privacy rejects failed commits and restores the plugin cache',
      () async {
    final prefs = _ControlledPreferences()..acceptsWrites = false;
    prefs.durable[PrivacyPreferencesNotifier.blockScreenshotsKey] = true;
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await expectLater(
        container
            .read(privacyPreferencesProvider.notifier)
            .setBlockFinancialScreenshots(false),
        throwsStateError);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    expect(
        prefs.getBool(PrivacyPreferencesNotifier.blockScreenshotsKey), isTrue);
    expect(prefs.reloads, 1);
    prefs.acceptsWrites = true;
    await container
        .read(privacyPreferencesProvider.notifier)
        .setBlockFinancialScreenshots(false);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isFalse);
  });
  test(
      'privacy reload and queued writes do not deadlock or reverse the final preference',
      () async {
    final prefs = _ControlledPreferences()..pending = Completer<bool>();
    prefs.durable[PrivacyPreferencesNotifier.blockScreenshotsKey] = true;
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final privacy = container.read(privacyPreferencesProvider.notifier);
    final first = privacy.setBlockFinancialScreenshots(false);
    final reload = privacy.reload();
    final last = privacy.setBlockFinancialScreenshots(true);
    await Future<void>.delayed(Duration.zero);
    prefs.pending!.complete(true);
    await Future.wait([first, reload, last])
        .timeout(const Duration(seconds: 1));
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    expect(container.read(privacyPreferencesProvider).loading, isFalse);
    expect(
        prefs.durable[PrivacyPreferencesNotifier.blockScreenshotsKey], isTrue);
    expect(prefs.writes, 2);
  });
  test('standalone privacy hosts retain asynchronous preference loading',
      () async {
    SharedPreferences.setMockInitialValues(
        {PrivacyPreferencesNotifier.blockScreenshotsKey: true});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(privacyPreferencesProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(privacyPreferencesProvider).loading, isFalse);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
  });

  Widget app(SharedPreferences prefs, Widget pane,
          {_DevicesRepository? repository,
          List<DeviceToken> tokens = const [],
          double textScale = 1,
          bool reduceMotion = false}) =>
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionStorageScopeProvider.overrideWithValue('test-user'),
          activeDeviceTokensProvider.overrideWith((_) async => tokens),
          if (repository != null)
            notificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduceMotion),
              child: child!),
          home: pane is NotificationSettingsScreen
              ? pane
              : Scaffold(body: SingleChildScrollView(child: pane)),
        ),
      );

  testWidgets('appearance save failure remains visible and can be retried',
      (tester) async {
    final prefs = _ControlledPreferences()..acceptsWrites = false;
    await tester.pumpWidget(app(prefs, const SettingsAppearancePane()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo escuro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(prefs.getBool('appearance_dark_mode_enabled'), isTrue);
    prefs.acceptsWrites = true;
    await tester.tap(find.text('Modo escuro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsNothing);
    expect(prefs.getBool('appearance_dark_mode_enabled'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alert taps are blocked while saving and failure allows retry',
      (tester) async {
    final prefs = _ControlledPreferences()..pending = Completer<bool>();
    await tester.pumpWidget(app(prefs, const SettingsNotificationsPane()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsNotificationsPane)));
    final label = AppLocalizations.of(
            tester.element(find.byType(SettingsNotificationsPane)))!
        .settingsNotifFinancialTitle;
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    expect(prefs.writes, 1);
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isTrue);
    prefs.pending!.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    prefs.pending = null;
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(container.read(alertPreferencesProvider).transactionAlertsEnabled,
        isFalse);
    expect(find.textContaining('Não foi possível salvar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'device revoke cannot repeat while pending or touch a disposed screen',
      (tester) async {
    final repository = _DevicesRepository();
    const token = DeviceToken(
        id: 'device',
        platform: 'Android',
        tokenRef: '',
        deviceRef: '',
        appVersion: '',
        active: true);
    await tester.pumpWidget(app(
        _ControlledPreferences(), const SettingsNotificationsPane(),
        repository: repository, tokens: [token]));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsNotificationsPane));
    final revoke = find.text(AppLocalizations.of(context)!.settingsNotifRevoke);
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tester.tap(find.byKey(const ValueKey('settings-account-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.calls, 1);
    expect(find.text('Desativando…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repository.pending.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('device revoke communication failure leaves the action available',
      (tester) async {
    final repository = _DevicesRepository();
    const token = DeviceToken(
        id: 'device',
        platform: 'Android',
        tokenRef: '',
        deviceRef: '',
        appVersion: '',
        active: true);
    await tester.pumpWidget(app(
        _ControlledPreferences(), const SettingsNotificationsPane(),
        repository: repository, tokens: [token]));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsNotificationsPane));
    final revoke = find.text(AppLocalizations.of(context)!.settingsNotifRevoke);
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    repository.pending.completeError(StateError('connection interrupted'));
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
    AppScreenFeedbackBus.clear();
    expect(revoke, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'standalone notifications uses the same permission and persistence pane',
      (tester) async {
    await tester.pumpWidget(
        app(_ControlledPreferences(), const NotificationSettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNotificationsPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switches expose their state and respect reduced motion',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(
        _ControlledPreferences(), const SettingsAppearancePane(),
        reduceMotion: true));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(MergeSemantics).first);
    expect(node.flagsCollection.isToggled, ui.Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    final animated = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(SettingsReadonlySwitch),
        matching: find.byType(AnimatedContainer)));
    expect(animated.duration, Duration.zero);
    handle.dispose();
  });

  testWidgets(
      'background consent remains usable with large text on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = _ControlledPreferences()
      ..durable[AlertPreferencesNotifier.backgroundAlertsKey] = false;
    await tester.pumpWidget(
        app(prefs, const NotificationSettingsScreen(), textScale: 1.6));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsNotificationsPane));
    final tr = AppLocalizations.of(context)!;
    await tester.ensureVisible(find.text(tr.settingsNotifBackgroundTitle));
    await tester.tap(find.text(tr.settingsNotifBackgroundTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    final dismiss = find.text(tr.settingsNotifBackgroundDialogDismiss);
    await tester.ensureVisible(dismiss);
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(prefs.writes, 0);
    expect(tester.takeException(), isNull);
  });
}
