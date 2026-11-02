import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/history_sync_notice.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

final _owner = NotifierProvider<_Owner, String>(_Owner.new);

class _Owner extends Notifier<String> {
  @override
  String build() => 'user_a';
  void change(String value) => state = value;
}

final _rows = [
  Transaction(
    id: 'known-operation',
    fromAddress: 'sender',
    toAddress: 'recipient',
    amountSatoshis: 1,
    feeSatoshis: 0,
    status: TransactionStatus.confirmed,
    type: TransactionType.receive,
    confirmations: 1,
    timestamp: DateTime.utc(2000),
  ),
];

Future<ProviderContainer> _pump(WidgetTester tester,
    {Brightness brightness = Brightness.dark,
    bool hasRows = true,
    bool unexpectedError = false,
    required VoidCallback refresh}) async {
  await tester.binding.setSurfaceSize(const Size(320, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageScopeProvider.overrideWith((ref) => ref.watch(_owner)),
      transactionHistoryProvider.overrideWith((ref) async {
        if (unexpectedError) throw StateError('Fixture storage failure');
        return hasRows ? _rows : [];
      }),
    ],
    child: MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                    body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HistorySyncNotice(onRefresh: refresh),
                )),
              )),
    ),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
      tester.element(find.byType(HistorySyncNotice)));
}

void main() {
  setUpAll(() => initializeDateFormatting('pt'));

  for (final brightness in Brightness.values) {
    for (final knownSync in [false, true]) {
      testWidgets(
          'HTTP failure remains visible while online: $brightness, date=$knownSync',
          (tester) async {
        var refreshes = 0;
        final container = await _pump(tester,
            brightness: brightness, refresh: () => refreshes++);
        expect(
            find.text('Não foi possível atualizar o histórico'), findsNothing);
        final sync =
            container.read(transactionHistoryLastSyncProvider.notifier);
        if (knownSync) sync.touch();
        sync.markFailed();
        await tester.pumpAndSettle();

        expect(container.read(networkStatusProvider), isTrue);
        expect(find.text('Não foi possível atualizar o histórico'),
            findsOneWidget);
        expect(find.textContaining('Última atualização:'),
            knownSync ? findsOneWidget : findsNothing);
        expect(find.textContaining('2000'), findsNothing);
        await tester.tap(find.byTooltip('Atualizar histórico'));
        expect(refreshes, 1);
        expect(tester.takeException(), isNull);

        sync.touch();
        await tester.pumpAndSettle();
        expect(
            find.text('Não foi possível atualizar o histórico'), findsNothing);
      });
    }
  }

  testWidgets('a detached retry cannot refresh a different account',
      (tester) async {
    var refreshes = 0;
    final container = await _pump(tester, refresh: () => refreshes++);
    container.read(transactionHistoryLastSyncProvider.notifier).markFailed();
    await tester.pumpAndSettle();
    final action =
        tester.widget<IconButton>(find.byType(IconButton)).onPressed!;
    container.read(_owner.notifier).change('user_b');
    await tester.pumpAndSettle();
    action();
    expect(refreshes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unexpected query errors remain visible with known rows',
      (tester) async {
    final container =
        await _pump(tester, unexpectedError: true, refresh: () {});
    expect(container.read(transactionHistoryReadinessProvider).failed, isFalse);
    container.read(lastTransactionHistoryProvider.notifier).set(_rows);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar o histórico'), findsOneWidget);
    expect(find.textContaining('Última atualização:'), findsNothing);
    expect(find.byTooltip('Atualizar histórico'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history keeps the main error presentation responsible',
      (tester) async {
    final container = await _pump(tester, hasRows: false, refresh: () {});
    container.read(transactionHistoryLastSyncProvider.notifier).markFailed();
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar o histórico'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
