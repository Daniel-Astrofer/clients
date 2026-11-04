import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' show loadAppFonts;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show transactionRepositoryProvider;
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_list_item.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_glyph.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

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
    ThemeData? theme,
    bool reactiveMoney = false,
    TransactionRepository? actionRepo,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final sharedPreferences = await SharedPreferences.getInstance();
    configureViewport(tester, size);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          bitcoinAccountsProvider.overrideWithValue(const AsyncData([])),
          walletProvider.overrideWith(_EmptyWallets.new),
          if (actionRepo != null) ...[
            transactionRepositoryProvider.overrideWithValue(actionRepo),
            sessionStorageScopeProvider.overrideWithValue('action-fixture'),
            activityArchiveStoreProvider.overrideWithValue(_ReadyArchive()),
          ],
          if (reactiveMoney)
            moneyFormatConfigProvider
                .overrideWith((ref) => ref.watch(_testMoneyProvider)),
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
          theme: theme,
          locale: actionRepo != null ? const Locale('pt') : null,
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

  for (final mode in StatementTransactionCardMode.values) {
    testWidgets('acknowledged cancellation updates the actual card: $mode',
        (tester) async {
      final current =
          Transaction.fromJson({...transaction.toJson(), 'cancellable': true});
      final cancelled = Transaction.fromJson({
        ...current.toJson(),
        'status': 'cancelled',
        'cancellable': false,
        'updatedAt': DateTime.utc(2030).toIso8601String()
      });
      final repo = _AckRepo(cancelled);
      await pumpCard(tester,
          size: regularPortrait,
          theme: AppTheme.darkTheme,
          actionRepo: repo,
          child: SingleChildScrollView(
              child: StatementTransactionCard(
                  transaction: current,
                  mode: mode,
                  expanded: true,
                  density: StatementTransactionCardDensity.full)));
      final cancel = find.byKey(const ValueKey('activity-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pump();
      await tester.tap(cancel);
      await tester.pump(const Duration(milliseconds: 200));
      final confirm = find.byKey(const ValueKey('activity-confirm-action'));
      await tester.ensureVisible(confirm);
      await tester.pump();
      tester.widget<AppButton>(confirm).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.calls, 1);
      expect(find.text('Movimentação cancelada'), findsOneWidget);
      expect(find.text('Cancelada'), findsWidgets);
      expect(find.byKey(const ValueKey('activity-cancel')), findsNothing);
      expect(find.byKey(const ValueKey('activity-archive')), findsOneWidget);
      AppScreenFeedbackBus.clear();
      expect(takeAllExceptions(tester), isEmpty);
    });
  }

  testWidgets(
      'collapsed Home preserves exact operations when balance precision changes',
      (tester) async {
    await pumpCard(tester,
        size: regularPortrait,
        theme: AppTheme.darkTheme,
        reactiveMoney: true,
        child: SingleChildScrollView(
            child: StatementTransactionCard(
                transaction: transaction,
                density: StatementTransactionCardDensity.home)));
    expect(find.textContaining('9.87657531'), findsOneWidget);
    expect(find.textContaining('≈'), findsNothing);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(StatementTransactionCard)));
    container.read(_testMoneyProvider.notifier).setPrecision(8);
    await tester.pump();
    expect(find.textContaining('9.87657531'), findsOneWidget);
    expect(find.textContaining('9.88'), findsNothing);
    expect(takeAllExceptions(tester), isEmpty);
  });

  testWidgets('expanded statement rows follow updated confirmation data',
      (tester) async {
    StateSetter? update;
    Transaction current = transaction;
    await pumpCard(tester, size: regularPortrait, theme: AppTheme.darkTheme,
        child: SingleChildScrollView(
            child: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return StatementTransactionCard(
          transaction: current,
          density: StatementTransactionCardDensity.full,
          expanded: true);
    })));
    expect(find.widgetWithText(SelectableText, '1/6'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    update!(() => current = Transaction(
        id: transaction.id,
        fromAddress: transaction.fromAddress,
        toAddress: transaction.toAddress,
        amountSatoshis: transaction.amountSatoshis,
        feeSatoshis: transaction.feeSatoshis,
        status: transaction.status,
        type: transaction.type,
        confirmations: 3,
        timestamp: transaction.timestamp,
        blockchainTxid: transaction.blockchainTxid));
    await tester.pump();
    expect(find.widgetWithText(SelectableText, '3/6'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '1/6'), findsNothing);
    expect(takeAllExceptions(tester), isEmpty);
  });

  group('StatementTransactionCard responsiveness', () {
    for (final status in TransactionStatus.values) {
      testWidgets('expanded history keeps the rail and direction: $status',
          (tester) async {
        final tx = Transaction(
            id: 'rail-and-direction',
            fromAddress: 'own-wallet',
            toAddress: 'bc1qpublic-destination',
            amountSatoshis: 50000,
            feeSatoshis: 100,
            status: status,
            type: TransactionType.send,
            confirmations: status == TransactionStatus.confirmed ? 6 : 1,
            timestamp: DateTime.utc(2026, 10, 10),
            rail: 'ONCHAIN');
        await pumpCard(tester,
            size: regularPortrait,
            theme: AppTheme.darkTheme,
            child: SingleChildScrollView(
                child:
                    StatementTransactionCard(transaction: tx, expanded: true)));
        final glyph = tester
            .widget<ActivityGlyph>(find.byKey(const ValueKey('icon-glyph')));
        expect(glyph.spec.primary, KeroseneIcons.railOnchain);
        expect(glyph.spec.direction, KeroseneIcons.dirOut);
        expect(takeAllExceptions(tester), isEmpty);
      });
    }

    for (final dark in [false, true]) {
      testWidgets('full account history follows the Home palette: dark=$dark',
          (tester) async {
        await pumpCard(tester,
            size: regularPortrait,
            theme: AppTheme.themeFor(
                dark ? AppThemeVariant.dark : AppThemeVariant.light),
            child: SingleChildScrollView(
                child: StatementTransactionCard(
                    transaction: transaction, expanded: true)));
        final surface = dark ? HomeSurfaceTheme.dark : HomeSurfaceTheme.light;
        final card = find.byType(StatementTransactionCard);
        final ink = tester.widget<Ink>(
            find.descendant(of: card, matching: find.byType(Ink)).first);
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.color, surface.card);
        expect(decoration.border!.top.color, surface.surfaceBorder);
        expect(decoration.boxShadow, isNull);
        expect(takeAllExceptions(tester), isEmpty);
      });
    }

    testWidgets('Home density renders flush dark surface row and opens details on tap',
        (tester) async {
      await loadAppFonts();
      await pumpCard(
        tester,
        size: regularPortrait,
        theme: AppTheme.darkTheme,
        child: SingleChildScrollView(
            child: SizedBox(
          width: 340,
          child: StatementTransactionCard(
            transaction: transaction,
            density: StatementTransactionCardDensity.home,
          ),
        )),
      );

      final card = find.byType(StatementTransactionCard);
      final material = tester.widget<Material>(
        find.descendant(of: card, matching: find.byType(Material)).first,
      );
      expect(material.type, MaterialType.transparency);
      expect(
          find.descendant(of: card, matching: find.byType(InkWell)), findsOneWidget);

      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TransactionDetailScreen), findsOneWidget);
      expect(takeAllExceptions(tester), isEmpty);
    });

    testWidgets('stacked card grows for complete identifiers', (tester) async {
      for (final size in [compactPortrait, compactLandscape, regularPortrait]) {
        await pumpCard(
          tester,
          size: size,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: StatementTransactionCard(transaction: transaction),
            ),
          ),
        );

        expect(
          takeAllExceptions(tester),
          isEmpty,
          reason: 'Stacked transaction card overflowed at $size',
        );
        final party = tester
            .widget<Text>(find.textContaining(transaction.toAddress).first);
        expect(party.maxLines, isNull);
        expect(party.overflow, isNot(TextOverflow.ellipsis));
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
        child: SingleChildScrollView(
            child: SizedBox(
          width: 340,
          child: StatementTransactionCard(transaction: failedOutgoing),
        )),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'(^|\s)(?:-\s*(?:US\$|R\$|\$|€|₿|\d)|>\s*-)')
                  .hasMatch(widget.data ?? ''),
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
          (widget) =>
              widget is Text &&
              RegExp(r'(^|\s)(?:-\s*(?:US\$|R\$|\$|€|₿|\d)|>\s*-)')
                  .hasMatch(widget.data ?? ''),
        ),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Home density for payment link shows abbreviated hash of who paid',
        (tester) async {
      await loadAppFonts();
      final linkTx = Transaction(
        id: 'pl_test_123',
        fromAddress: 'Rede Bitcoin',
        toAddress: 'bc1q9xxxxpayeraddress00000000000000000000000',
        amountSatoshis: 250000,
        feeSatoshis: 0,
        status: TransactionStatus.confirmed,
        type: TransactionType.receive,
        confirmations: 1,
        timestamp: DateTime.now(),
        rail: 'ONCHAIN',
        provider: 'PAYMENT_LINK',
        blockchainTxid:
            '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b',
      );

      await pumpCard(
        tester,
        size: regularPortrait,
        theme: AppTheme.darkTheme,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 340,
            child: StatementTransactionCard(
              transaction: linkTx,
              density: StatementTransactionCardDensity.home,
            ),
          ),
        ),
      );

      expect(
        find.textContaining('4a5e1e...eda33b', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Link de pagamento', findRichText: true),
          findsNothing);
      expect(find.textContaining('Pagador on-chain', findRichText: true),
          findsNothing);
      expect(takeAllExceptions(tester), isEmpty);
    });
  });
}

final _testMoneyProvider =
    NotifierProvider<_TestMoney, MoneyFormatConfig>(_TestMoney.new);

class _TestMoney extends Notifier<MoneyFormatConfig> {
  @override
  MoneyFormatConfig build() => const MoneyFormatConfig(
      currency: Currency.btc, locale: Locale('en'), btcDecimalPlaces: 2);
  void setPrecision(int value) => state = MoneyFormatConfig(
      currency: Currency.btc,
      locale: const Locale('en'),
      btcDecimalPlaces: value);
}

class _AckRepo implements TransactionRepository {
  final Transaction reply;
  int calls = 0;
  _AckRepo(this.reply);
  @override
  Future<Transaction> cancelTransaction(String id) async {
    calls++;
    return reply;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadyArchive extends ActivityArchiveStore {
  _ReadyArchive() : super(SecureStorageService());
  @override
  Future<Set<String>> load(String scope) async => {};
}

class _EmptyWallets extends WalletNotifier {
  @override
  WalletState build() => const WalletLoaded(wallets: [], btcToUsdRate: 0);
}
