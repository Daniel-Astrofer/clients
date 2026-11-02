import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show
        sessionStorageScopeProvider,
        authControllerProvider,
        AuthController,
        AuthState,
        AuthAuthenticated,
        AuthInitial;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/settings_security_pane.dart';
import 'package:kerosene/features/security/presentation/screens/settings_section_components.dart';
import '../../goldens/golden_harness.dart';

class LocalActionPreferences extends Mock implements SharedPreferences {
  bool durable = true;
  bool cached = true;
  int writes = 0;
  Completer<bool>? pending;
  bool accepted = true;
  @override
  bool? getBool(String key) =>
      key == PrivacyPreferencesNotifier.blockScreenshotsKey ? cached : null;
  @override
  Future<bool> setBool(String key, bool value) async {
    writes++;
    cached = value;
    final ok = pending == null ? accepted : await pending!.future;
    if (ok) durable = value;
    return ok;
  }

  @override
  Future<void> reload() async {
    cached = durable;
  }
}

class LocalActionStore implements LocalTransactionHistoryStore {
  final calls = <String>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> clear(String scope) async {
    calls.add(scope);
    await pending?.future;
    if (fail) throw StateError('PRIVATE-STACK-DETAILS');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final localActionOwnerProvider =
    NotifierProvider<LocalActionOwner, String?>(LocalActionOwner.new);

class LocalActionOwner extends Notifier<String?> {
  @override
  String? build() => 'complete-public-account-identifier-1234567890';
  void change(String? owner) => state = owner;
}

class _LocalAuth extends AuthController {
  @override
  AuthState build() {
    final owner = ref.watch(localActionOwnerProvider);
    return owner == null
        ? const AuthInitial()
        : AuthAuthenticated(User(
            id: owner,
            username: owner == 'bob' ? 'bob' : 'alice',
            createdAt: DateTime(2020)));
  }
}

class LocalActionHistory extends LastTransactionHistoryNotifier {
  int clears = 0;
  @override
  List<Transaction> build() {
    final owner = ref.watch(sessionStorageScopeProvider);
    return [
      Transaction(
          id: '$owner-movement',
          fromAddress: 'origin',
          toAddress: 'destination',
          amountSatoshis: 1,
          feeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.receive,
          confirmations: 1,
          timestamp: DateTime(2020))
    ];
  }

  @override
  void set(List<Transaction> value) {
    clears++;
    super.set(value);
  }
}

Future<ProviderContainer> pumpLocalSettings(
  WidgetTester tester, {
  required LocalActionStore store,
  LocalActionPreferences? preferences,
  AppThemeVariant theme = AppThemeVariant.dark,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    authControllerProvider.overrideWith(_LocalAuth.new),
    sharedPreferencesProvider
        .overrideWithValue(preferences ?? LocalActionPreferences()),
    sessionStorageScopeProvider
        .overrideWith((ref) => ref.watch(localActionOwnerProvider)),
    localTransactionHistoryStoreProvider.overrideWithValue(store),
    localTransactionHistoryProvider.overrideWith((ref) async => []),
    lastTransactionHistoryProvider.overrideWith(LocalActionHistory.new),
    transactionHistoryProvider.overrideWith((ref) async => []),
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
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          home: const Scaffold(
              body: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: SettingsSecurityPane())))));
  await tester.pumpAndSettle();
  return container;
}

SettingsSectionRow localActionRow(WidgetTester tester, String title) =>
    tester.widget<SettingsSectionRow>(find
        .ancestor(
            of: find.text(title), matching: find.byType(SettingsSectionRow))
        .first);
Future<void> openLocalWipe(WidgetTester tester,
    {bool duplicate = false}) async {
  final callback = localActionRow(tester, 'Apagar extrato local').onTap!;
  callback();
  if (duplicate) callback();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> confirmLocalWipe(WidgetTester tester) async {
  final confirm = find.byKey(const ValueKey('settings-account-confirm'));
  expect(confirm.hitTestable(), findsOneWidget);
  await tester.tap(confirm);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> finishLocalSettings(WidgetTester tester) async {
  AppScreenFeedbackBus.clear();
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    testWidgets(
        'wipe confirmation is account-bound and reachable with large text: $theme',
        (tester) async {
      final store = LocalActionStore();
      await pumpLocalSettings(tester, store: store, theme: theme, scale: 1.8);
      await openLocalWipe(tester, duplicate: true);
      expect(find.byType(Dialog), findsOneWidget);
      expect(
          find.widgetWithText(
              SelectableText, 'complete-public-account-identifier-1234567890'),
          findsOneWidget);
      expect(find.textContaining('500'), findsNothing);
      expect(
          ModalRoute.of(tester.element(find.byType(Dialog)))!
              .transitionDuration,
          Duration.zero);
      expect(
          find.byKey(const ValueKey('settings-account-confirm')).hitTestable(),
          findsOneWidget);
      expect(store.calls, isEmpty);
      await finishLocalSettings(tester);
    });
  }
  testWidgets(
      'wipe waits for storage, blocks duplicate confirmation and persists the result',
      (tester) async {
    final store = LocalActionStore()..pending = Completer<void>();
    final container = await pumpLocalSettings(tester, store: store);
    container.read(lastTransactionHistoryProvider);
    await openLocalWipe(tester, duplicate: true);
    await confirmLocalWipe(tester);
    expect(store.calls, ['complete-public-account-identifier-1234567890']);
    expect(localActionRow(tester, 'Apagar extrato local').onTap, isNull);
    expect(
        container.read(lastTransactionHistoryProvider.notifier)
            is LocalActionHistory,
        isTrue);
    expect(container.read(lastTransactionHistoryProvider), isNotEmpty);
    expect(AppScreenFeedbackBus.current.value, isNull);
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(container.read(lastTransactionHistoryProvider), isEmpty);
    expect(
        find.byKey(const ValueKey('settings-ledger-result')), findsOneWidget);
    expect(find.text('Ver extrato'), findsOneWidget);
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.info);
    await finishLocalSettings(tester);
  });
  testWidgets(
      'changing account closes the confirmation without erasing either account',
      (tester) async {
    final store = LocalActionStore();
    final container = await pumpLocalSettings(tester, store: store);
    await openLocalWipe(tester);
    container.read(localActionOwnerProvider.notifier).change('bob');
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(store.calls, isEmpty);
    expect(find.byKey(const ValueKey('settings-ledger-result')), findsNothing);
    await finishLocalSettings(tester);
  });
  testWidgets(
      'late erase cannot clear a new account projection or announce success there',
      (tester) async {
    final store = LocalActionStore()..pending = Completer<void>();
    final container = await pumpLocalSettings(tester, store: store);
    await openLocalWipe(tester);
    await confirmLocalWipe(tester);
    container.read(localActionOwnerProvider.notifier).change('bob');
    expect(container.read(lastTransactionHistoryProvider).single.id,
        'bob-movement');
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(container.read(lastTransactionHistoryProvider).single.id,
        'bob-movement');
    expect(
        (container.read(lastTransactionHistoryProvider.notifier)
                as LocalActionHistory)
            .clears,
        0);
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(find.byKey(const ValueKey('settings-ledger-result')), findsNothing);
    await finishLocalSettings(tester);
  });
  testWidgets(
      'erase failure exposes a safe persistent message and permits a confirmed retry',
      (tester) async {
    final store = LocalActionStore()..fail = true;
    await pumpLocalSettings(tester, store: store);
    await openLocalWipe(tester);
    await confirmLocalWipe(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Não conseguimos confirmar a remoção'),
        findsOneWidget);
    expect(find.textContaining('PRIVATE-STACK'), findsNothing);
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
    AppScreenFeedbackBus.clear();
    store.fail = false;
    final retry = tester.widget<AppButton>(find.widgetWithText(
        AppButton,
        AppLocalizations.of(tester.element(find.byType(SettingsSecurityPane)))!
            .tryAgain));
    retry.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await confirmLocalWipe(tester);
    await tester.pumpAndSettle();
    expect(store.calls, hasLength(2));
    expect(find.text('Ver extrato'), findsOneWidget);
    await finishLocalSettings(tester);
  });
  testWidgets(
      'privacy failure retains the protection state and permits saving again',
      (tester) async {
    final prefs = LocalActionPreferences()..pending = Completer<bool>();
    final container = await pumpLocalSettings(tester,
        store: LocalActionStore(), preferences: prefs);
    localActionRow(tester, 'Bloquear capturas no extrato').onTap!();
    await tester.pump();
    expect(
        localActionRow(tester, 'Bloquear capturas no extrato').onTap, isNull);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    expect(prefs.writes, 1);
    prefs.pending!.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isTrue);
    expect(prefs.cached, isTrue);
    prefs.pending = null;
    localActionRow(tester, 'Bloquear capturas no extrato').onTap!();
    await tester.pumpAndSettle();
    expect(container.read(privacyPreferencesProvider).blockFinancialScreenshots,
        isFalse);
    expect(find.textContaining('Não foi possível salvar'), findsNothing);
    await finishLocalSettings(tester);
  });
}
