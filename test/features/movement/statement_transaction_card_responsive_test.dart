import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_list_item.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const compactPortrait = Size(320, 568);
  const compactLandscape = Size(568, 320);
  const regularPortrait = Size(390, 844);

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final arguments = call.arguments;
          if (arguments is Map) {
            clipboardText = arguments['text']?.toString();
          }
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final transaction = Transaction(
    id: 'tx-responsive-001',
    fromAddress: 'bc1qsourceaddresswithaverylongvalue00000000000000000000',
    toAddress: 'bc1qdestinationaddresswithaverylongvalue1111111111111111',
    amountSatoshis: 987654321,
    feeSatoshis: 3210,
    status: TransactionStatus.confirming,
    type: TransactionType.withdrawal,
    confirmations: 1,
    timestamp: DateTime(2026, 5, 19, 22, 30),
    blockchainTxid:
        '82b6f7a1f0d1f1422c3378e4a66de62c2bb91df1a8d2de8f9c11c2a6e3123456',
    description:
        'Long transaction description used only for responsive widget tests',
  );

  List<Object> takeAllExceptions(WidgetTester tester) {
    final exceptions = <Object>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      exceptions.add(exception!);
    }
    return exceptions;
  }

  void configureViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size size,
    required Widget child,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final sharedPreferences = await SharedPreferences.getInstance();
    configureViewport(tester, size);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          backendBtcRatesProvider.overrideWith(
            (ref) async => const BackendBtcRates(
              btcUsd: 76500,
              btcBrl: 382500,
              btcEur: 70380,
              usdBrl: 5,
            ),
          ),
          latestBtcPriceProvider.overrideWithValue(76500),
          btcBrlPriceProvider.overrideWithValue(382500),
          btcEurPriceProvider.overrideWithValue(70380),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('StatementTransactionCard responsiveness', () {
    testWidgets('stacked card fits its fixed stack extent', (tester) async {
      for (final size in [compactPortrait, compactLandscape, regularPortrait]) {
        await pumpCard(
          tester,
          size: size,
          child: SizedBox(
            width: 340,
            height: 174,
            child: StatementTransactionCard(transaction: transaction),
          ),
        );

        expect(
          takeAllExceptions(tester),
          isEmpty,
          reason: 'Stacked transaction card overflowed at $size',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('expanded separated card remains scrollable on short screens', (
      tester,
    ) async {
      await pumpCard(
        tester,
        size: compactLandscape,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: StatementTransactionCard(
              transaction: transaction,
              expanded: true,
              mode: StatementTransactionCardMode.separated,
            ),
          ),
        ),
      );

      expect(takeAllExceptions(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('failed outgoing cards keep the debit sign', (tester) async {
      final failedOutgoing = Transaction(
        id: 'tx-failed-outgoing',
        fromAddress: 'minha-carteira',
        toAddress: 'bc1qdestination',
        amountSatoshis: 50000,
        feeSatoshis: 1200,
        status: TransactionStatus.failed,
        type: TransactionType.withdrawal,
        confirmations: 0,
        timestamp: DateTime(2026, 5, 20, 12),
      );

      await pumpCard(
        tester,
        size: regularPortrait,
        child: SizedBox(
          width: 340,
          height: 174,
          child: StatementTransactionCard(transaction: failedOutgoing),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.startsWith('-') ?? false),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('list expands downward and can open multiple cards', (
      tester,
    ) async {
      configureViewport(tester, regularPortrait);

      Widget buildStack({Set<int> expandedIndices = const {}}) {
        return MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                child: StatementTransactionScrollStack(
                  itemCount: 3,
                  itemGap: 10,
                  itemBuilder: (context, index) {
                    final expanded = expandedIndices.contains(index);
                    return SizedBox(
                      key: ValueKey('stack-item-$index'),
                      height: expanded ? 180 : 100,
                      child: ColoredBox(
                        color: expanded ? Colors.white : Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildStack());
      await tester.pumpAndSettle();
      final collapsedItem1 =
          tester.getTopLeft(find.byKey(const ValueKey('stack-item-1'))).dy;
      final collapsedItem2 =
          tester.getTopLeft(find.byKey(const ValueKey('stack-item-2'))).dy;

      // Expand first card — pushes following items down by height delta.
      await tester.pumpWidget(buildStack(expandedIndices: {0}));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('stack-item-1'))).dy,
        closeTo(collapsedItem1 + 80, 0.5),
      );

      // Open second while first stays open — multi-expand.
      await tester.pumpWidget(buildStack(expandedIndices: {0, 1}));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('stack-item-2'))).dy,
        closeTo(collapsedItem2 + 160, 0.5),
      );

      await tester.pumpWidget(buildStack());
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('stack-item-1'))).dy,
        closeTo(collapsedItem1, 0.5),
      );
      expect(takeAllExceptions(tester), isEmpty);
    });

    testWidgets('expanded detail rows expose copyable party fields', (
      tester,
    ) async {
      final onchainOutgoing = Transaction(
        id: 'tx-copyable-detail-001',
        fromAddress: 'bc1qsourceaddresswithaverylongvalue00000000000000000000',
        toAddress: 'bc1qdestinationaddresswithaverylongvalue1111111111111111',
        amountSatoshis: 210000,
        feeSatoshis: 1200,
        status: TransactionStatus.confirmed,
        type: TransactionType.withdrawal,
        confirmations: 6,
        timestamp: DateTime(2026, 5, 21, 9, 45),
        blockchainTxid:
            '82b6f7a1f0d1f1422c3378e4a66de62c2bb91df1a8d2de8f9c11c2a6e3123456',
        rail: 'ONCHAIN',
      );

      await pumpCard(
        tester,
        size: regularPortrait,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 340,
            child: StatementTransactionCard(
              transaction: onchainOutgoing,
              expanded: true,
              mode: StatementTransactionCardMode.separated,
            ),
          ),
        ),
      );

      expect(find.textContaining('6/6'), findsWidgets);
      expect(find.byIcon(KeroseneIcons.copy), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('transaction list item keeps the debit sign for outgoing rows',
        (tester) async {
      final outgoing = Transaction(
        id: 'tx-list-outgoing',
        fromAddress: 'minha-carteira',
        toAddress: 'bc1qdestination',
        amountSatoshis: 50000,
        feeSatoshis: 1200,
        status: TransactionStatus.confirmed,
        type: TransactionType.send,
        confirmations: 6,
        timestamp: DateTime(2026, 5, 20, 12),
      );

      await pumpCard(
        tester,
        size: regularPortrait,
        child: SizedBox(
          width: 340,
          child: TransactionListItem(transaction: outgoing),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.startsWith('-') ?? false),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
