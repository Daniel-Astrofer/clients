import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart'
    show secureStorageServiceProvider;
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/core/network/api_client_route_policy.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/presentation/recovery/payment_recovery_panel.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/features/movement/providers/payment_submission_recovery_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show lastTransactionHistoryProvider;
import '../../../core/security/payment_submission_store_test.dart'
    show MemorySubmissionStorage, payment;

final _account = NotifierProvider<_Account, String>(_Account.new);

class _Account extends Notifier<String> {
  @override
  String build() => 'user_42';
  void switchTo(String scope) => state = scope;
}

class _RecoveryAdapter implements HttpClientAdapter {
  int status = 202;
  final paths = <String>[];
  final methods = <String>[];
  final started = Completer<void>();
  Completer<void>? gate;
  Map<String, dynamic>? alternate;
  static const id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  Map<String, dynamic> get operation => {
        'id': id,
        'status': 'SETTLED',
        'rail': 'INTERNAL',
        'direction': 'INTERNAL',
        'sourceWalletId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'destinationWalletId': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'sourceWalletLabel': 'Minha conta',
        'fromAddress': 'Alice',
        'toAddress': 'Maria',
        'receiverAmountSats': 100000,
        'grossAmountSats': 100000,
        'networkFeeSats': 0,
        'keroseneFeeSats': 0,
        'totalDebitSats': 100000,
        'confirmations': 0,
        'createdAt': '2026-10-09T12:00:00Z',
        'updatedAt': '2026-10-09T12:01:00Z',
      };
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    paths.add(options.path);
    methods.add(options.method);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    return ResponseBody.fromString(
        jsonEncode({
          'success': status < 400,
          'data': status == 200 ? alternate ?? operation : null
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'cache-control': ['public, max-age=600']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MemorySubmissionStorage> seed() async {
    final storage = MemorySubmissionStorage();
    final store = PaymentSubmissionStore(storage);
    store.rememberDisplay(
        'original',
        const MovementMoney(
                currency: Currency.brl, locale: Locale('pt'), btcBrl: 500000)
            .toJournal());
    await store.begin('user_42', payment('original'));
    return storage;
  }

  ProviderContainer container(
          MemorySubmissionStorage storage, _RecoveryAdapter adapter) =>
      ProviderContainer(overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_account)),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(
              baseUrl: 'https://example.test',
              ref: ref,
              routePolicy: ApiClientRoutePolicy.clearnet);
          client.dio.httpClientAdapter = adapter;
          ref.onDispose(() => client.dio.close(force: true));
          return client;
        }),
      ]);

  test('a 202 remains unresolved and repeated checks bypass HTTP cache',
      () async {
    final storage = await seed();
    final adapter = _RecoveryAdapter();
    final scope = container(storage, adapter);
    addTearDown(scope.dispose);
    final query =
        paymentSubmissionLookupProvider(('user_42', 'original', null));
    final subscription = scope.listen(query, (_, __) {});
    addTearDown(subscription.close);
    expect(await scope.read(query.future), isNull);
    scope.invalidate(query);
    expect(await scope.read(query.future), isNull);
    expect(adapter.paths,
        ['/kfe/transactions/submissions', '/kfe/transactions/submissions']);
    expect(adapter.methods, ['GET', 'GET']);
    expect(
        (await scope.read(paymentSubmissionStoreProvider).load('user_42'))
            .single
            .transactionId,
        isNull);
  });

  test('a late result cannot populate another account after a session change',
      () async {
    final storage = await seed();
    final adapter = _RecoveryAdapter()
      ..status = 200
      ..gate = Completer<void>();
    final scope = container(storage, adapter);
    addTearDown(scope.dispose);
    final query =
        paymentSubmissionLookupProvider(('user_42', 'original', null));
    final subscription = scope.listen(query, (_, __) {});
    addTearDown(subscription.close);
    final pending = scope.read(query.future);
    await adapter.started.future;
    scope.read(_account.notifier).switchTo('user_7');
    adapter.gate!.complete();
    await pending;
    expect(scope.read(lastTransactionHistoryProvider), isEmpty);
    expect(await scope.read(paymentSubmissionStoreProvider).load('user_7'),
        isEmpty);
    expect(
        (await scope.read(paymentSubmissionStoreProvider).load('user_42'))
            .single
            .transactionId,
        isNull);
  });

  test('incomplete or mismatched server data never becomes a recovered receipt',
      () async {
    final storage = await seed();
    final adapter = _RecoveryAdapter()
      ..status = 200
      ..alternate = {'id': _RecoveryAdapter.id};
    final scope = container(storage, adapter);
    addTearDown(scope.dispose);
    final query =
        paymentSubmissionLookupProvider(('user_42', 'original', null));
    final subscription = scope.listen(query, (_, __) {});
    addTearDown(subscription.close);
    await expectLater(scope.read(query.future), throwsA(isA<Exception>()));
    adapter.alternate = {
      ...adapter.operation,
      'sourceWalletId': 'dddddddd-dddd-dddd-dddd-dddddddddddd'
    };
    scope.invalidate(query);
    await expectLater(scope.read(query.future), throwsA(isA<Exception>()));
    expect(scope.read(lastTransactionHistoryProvider), isEmpty);
    expect(
        (await scope.read(paymentSubmissionStoreProvider).load('user_42'))
            .single
            .transactionId,
        isNull);
  });

  Widget app(ProviderContainer scope) => UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const Scaffold(
            body: SingleChildScrollView(
                padding: EdgeInsets.all(20), child: PaymentRecoveryPanel())),
      ));

  testWidgets(
      'a restarted journey checks the server, opens its receipt and acknowledges the original intent',
      (tester) async {
    final storage = await seed();
    final adapter = _RecoveryAdapter();
    final scope = container(storage, adapter);
    addTearDown(scope.dispose);
    await tester.pumpWidget(app(scope));
    await tester.pumpAndSettle();
    expect(find.textContaining('resultado ainda está em verificação'),
        findsOneWidget);
    expect(find.textContaining('500,00'), findsNothing);
    expect(find.textContaining('0,00100000 BTC'), findsOneWidget);
    adapter.status = 200;
    await tester.tap(find.text('Verificar resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmada'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '));
    await tester.tap(find.text('Acompanhar operação'));
    await tester.pumpAndSettle();
    expect(find.byType(SendPaymentReceiptScreen<void>), findsOneWidget);
    expect(find.textContaining('500,00'), findsNothing);
    expect(find.textContaining('0,00100000 BTC'), findsWidgets);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(await scope.read(paymentSubmissionStoreProvider).load('user_42'),
        isEmpty);
    expect(adapter.methods.every((method) => method == 'GET'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'switching accounts never displays the previous recovery snapshot',
      (tester) async {
    final storage = await seed();
    final scope = container(storage, _RecoveryAdapter());
    addTearDown(scope.dispose);
    await tester.pumpWidget(app(scope));
    await tester.pumpAndSettle();
    expect(find.textContaining('0,00100000 BTC'), findsOneWidget);
    scope.read(_account.notifier).switchTo('user_7');
    await tester.pump();
    expect(find.textContaining('0,00100000 BTC'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.textContaining('0,00100000 BTC'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
