import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_actions.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

Transaction actionFixture(
        {TransactionStatus status = TransactionStatus.pending,
        String id = 'complete-operation-identifier-1234567890',
        DateTime? updatedAt}) =>
    Transaction(
        id: id,
        fromAddress: 'Minha conta',
        toAddress: 'bc1q${List.filled(3, 'publicdestinationabcdef').join()}',
        amountSatoshis: 1,
        feeSatoshis: 2,
        status: status,
        type: TransactionType.send,
        confirmations: 0,
        cancellable: true,
        timestamp: DateTime(2020),
        updatedAt: updatedAt);

class ActionRepo implements TransactionRepository {
  int calls = 0;
  Completer<Transaction>? gate;
  Transaction? response;
  bool fail = false;
  @override
  Future<Transaction> cancelTransaction(String id) async {
    calls++;
    if (fail) throw StateError('not acknowledged');
    if (gate != null) return await gate!.future;
    return response ??
        actionFixture(status: TransactionStatus.cancelled, id: id);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ActionStorage extends SecureStorageService {
  final data = <String, String>{};
  bool fail = false;
  Completer<void>? gate;
  Completer<void>? started;
  @override
  Future<String?> readCompatibleStrict({required String key}) async =>
      data[key];
  @override
  Future<void> write({required String key, required String value}) async {
    if (started?.isCompleted == false) started!.complete();
    await gate?.future;
    if (fail) throw StateError('save failed');
    data[key] = value;
  }
}

final actionOwnerProvider =
    NotifierProvider<ActionOwner, String?>(ActionOwner.new);

class ActionOwner extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void change(String? value) => state = value;
}

Future<ProviderContainer> pumpActivityActions(WidgetTester tester,
    {required ActionRepo repo,
    ActionStorage? storage,
    Transaction? initial,
    AppThemeVariant theme = AppThemeVariant.dark,
    double scale = 1,
    ValueChanged<Transaction>? onChanged}) async {
  await tester.binding.setSurfaceSize(const Size(320, 568));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sessionStorageScopeProvider
        .overrideWith((ref) => ref.watch(actionOwnerProvider)),
    transactionRepositoryProvider.overrideWithValue(repo),
    transactionHistoryProvider.overrideWith((ref) async => []),
    paymentLinksProvider.overrideWith((ref) async => <PaymentLink>[]),
    moneyFormatConfigProvider.overrideWithValue(const MoneyFormatConfig(
        currency: Currency.btc, locale: Locale('pt'), btcDecimalPlaces: 2)),
    resolvedBackendBtcRatesProvider.overrideWithValue(null),
    activityArchiveStoreProvider
        .overrideWithValue(ActivityArchiveStore(storage ?? ActionStorage())),
  ]);
  addTearDown(container.dispose);
  var current = initial ?? actionFixture();
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
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
            builder: (context, update) => ActivityActions(
                  transaction: current,
                  onChanged: (value) {
                    onChanged?.call(value);
                    update(() => current = value);
                  },
                )),
      )),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> confirmAction(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('activity-confirm-action'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(AppScreenFeedbackBus.clear);
  for (final theme in AppThemeVariant.values) {
    testWidgets(
        'confirmation is complete with large text and reduced motion: $theme',
        (tester) async {
      final repo = ActionRepo();
      await pumpActivityActions(tester, repo: repo, theme: theme, scale: 1.8);
      final button = tester
          .widget<AppButton>(find.byKey(const ValueKey('activity-cancel')));
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.widgetWithText(SelectableText, actionFixture().id),
          findsOneWidget);
      expect(find.text('-0,00000001 BTC'), findsOneWidget);
      expect(find.text('0,00000002 BTC'), findsOneWidget);
      expect(find.text('-0,00000003 BTC'), findsOneWidget);
      expect(find.text('Total da operação'), findsOneWidget);
      expect(find.textContaining('não estorna Bitcoin'), findsOneWidget);
      expect(repo.calls, 0);
      final route = ModalRoute.of(tester.element(find.byType(Dialog)));
      expect(route!.transitionDuration, Duration.zero);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'cancel success waits for acknowledgement and leaves a persistent result',
      (tester) async {
    final repo = ActionRepo()..gate = Completer<Transaction>();
    Transaction? changed;
    await pumpActivityActions(tester,
        repo: repo, onChanged: (value) => changed = value);
    await tester.tap(find.byKey(const ValueKey('activity-cancel')));
    await tester.pumpAndSettle();
    await confirmAction(tester);
    expect(repo.calls, 1);
    expect(changed, isNull);
    expect(AppScreenFeedbackBus.current.value, isNull);
    repo.gate!.complete(actionFixture(status: TransactionStatus.cancelled));
    await tester.pumpAndSettle();
    expect(changed?.isCancelled, isTrue);
    expect(find.text('Movimentação cancelada'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-archive')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-cancel')), findsNothing);
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.success);
    AppScreenFeedbackBus.clear();
  });
  for (final invalid in ['pending', 'different-id', 'exception']) {
    testWidgets('cancellation never reports success for $invalid',
        (tester) async {
      final repo = ActionRepo();
      if (invalid == 'exception') repo.fail = true;
      if (invalid == 'pending') repo.response = actionFixture();
      if (invalid == 'different-id') {
        repo.response = actionFixture(
            status: TransactionStatus.cancelled, id: 'other-record');
      }
      Transaction? changed;
      await pumpActivityActions(tester,
          repo: repo, onChanged: (value) => changed = value);
      await tester.tap(find.byKey(const ValueKey('activity-cancel')));
      await tester.pumpAndSettle();
      await confirmAction(tester);
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(find.textContaining('Não conseguimos confirmar o cancelamento'),
          findsOneWidget);
      expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
      AppScreenFeedbackBus.clear();
    });
  }
  testWidgets('session change closes the confirmation and sends no request',
      (tester) async {
    final repo = ActionRepo();
    final container = await pumpActivityActions(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('activity-cancel')));
    await tester.pumpAndSettle();
    container.read(actionOwnerProvider.notifier).change('bob');
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(repo.calls, 0);
  });
  testWidgets('late response cannot update another session', (tester) async {
    final repo = ActionRepo()..gate = Completer<Transaction>();
    Transaction? changed;
    final container = await pumpActivityActions(tester,
        repo: repo, onChanged: (value) => changed = value);
    await tester.tap(find.byKey(const ValueKey('activity-cancel')));
    await tester.pumpAndSettle();
    await confirmAction(tester);
    container.read(actionOwnerProvider.notifier).change('bob');
    await tester.pump();
    repo.gate!.complete(actionFixture(status: TransactionStatus.cancelled));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect(AppScreenFeedbackBus.current.value, isNull);
  });
  testWidgets('archive remains visible until storage acknowledges it',
      (tester) async {
    final storage = ActionStorage()
      ..gate = Completer<void>()
      ..started = Completer<void>();
    final container = await pumpActivityActions(tester,
        repo: ActionRepo(),
        storage: storage,
        initial: actionFixture(status: TransactionStatus.cancelled));
    await tester.tap(find.byKey(const ValueKey('activity-archive')));
    await tester.pumpAndSettle();
    expect(find.textContaining('não altera saldo'), findsOneWidget);
    await confirmAction(tester);
    expect(container.read(activityArchiveProvider), isEmpty);
    expect(AppScreenFeedbackBus.current.value, isNull);
    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(
        container.read(activityArchiveProvider), contains(actionFixture().id));
    expect(find.text('Movido para Arquivadas'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-archive')), findsNothing);
    AppScreenFeedbackBus.clear();
  });
  testWidgets('archive failure keeps the movement and exposes retry',
      (tester) async {
    final storage = ActionStorage()..fail = true;
    final container = await pumpActivityActions(tester,
        repo: ActionRepo(),
        storage: storage,
        initial: actionFixture(status: TransactionStatus.cancelled));
    await tester.tap(find.byKey(const ValueKey('activity-archive')));
    await tester.pumpAndSettle();
    await confirmAction(tester);
    await tester.pumpAndSettle();
    expect(container.read(activityArchiveProvider), isEmpty);
    expect(find.textContaining('Não conseguimos confirmar o arquivamento'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('activity-archive')), findsOneWidget);
    AppScreenFeedbackBus.clear();
    storage.fail = false;
    await tester.tap(find.byKey(const ValueKey('activity-archive')));
    await tester.pumpAndSettle();
    await confirmAction(tester);
    await tester.pumpAndSettle();
    expect(
        container.read(activityArchiveProvider), contains(actionFixture().id));
    AppScreenFeedbackBus.clear();
  });
}
