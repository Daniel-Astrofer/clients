import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/interaction/kerosene_pressable.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/wallet_transaction_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a helpful empty state', (tester) async {
    await pumpWalletList(tester, const TransactionList());

    expect(find.text('Sem transações ainda'), findsOneWidget);
    expect(
      find.textContaining('o histórico aparece aqui'),
      findsOneWidget,
    );
  });

  testWidgets('shows loading state before transactions arrive', (tester) async {
    await pumpWalletList(tester, const TransactionList(isLoading: true));

    expect(find.text('Carregando transações'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('shows retry action after an empty load error', (tester) async {
    var retries = 0;

    await pumpWalletList(
      tester,
      TransactionList(
        errorMessage: 'Servidor indisponível',
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Servidor indisponível'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('renders transaction rows when history exists', (tester) async {
    await pumpWalletList(
      tester,
      TransactionList(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        transactions: [
          _transaction(
            id: 'incoming-1',
            amountSatoshis: 150000,
            type: TransactionType.receive,
            toAddress: 'bc1qreceiveaddress',
          ),
          _transaction(
            id: 'outgoing-1',
            amountSatoshis: 70000,
            type: TransactionType.send,
            fromAddress: 'bc1qsendaddress',
          ),
        ],
      ),
    );

    expect(
        find.byKey(const ValueKey('transaction-list-items')), findsOneWidget);
    expect(find.text('Recebimento · Bitcoin — rede'), findsOneWidget);
    expect(find.text('Envio · Bitcoin — rede'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.textContaining('-'), findsWidgets);
  });

  for (final variant in AppThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'wallet row keeps exact data and full address: $variant $scale',
          (tester) async {
        await pumpWalletList(
            tester,
            TransactionList(transactions: [
              _transaction(
                  id: 'exact-outgoing-address',
                  amountSatoshis: 1,
                  feeSatoshis: 0,
                  type: TransactionType.send,
                  toAddress: walletHistoryDestination),
            ]),
            variant: variant,
            scale: scale);
        final address = find.textContaining(walletHistoryDestination);
        expect(address, findsOneWidget);
        final text = tester.widget<Text>(address);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(find.text('-0,00000001 BTC'), findsOneWidget);
        expect(find.textContaining('R\$'), findsNothing);
        expect(find.textContaining('Confirmada'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('stale row callback cannot open details for another account',
      (tester) async {
    final container = await pumpWalletList(tester, walletHistoryFixture());
    final action = tester
        .widget<KerosenePressable>(find.byType(KerosenePressable).first)
        .onPressed!;
    container.read(walletListTestScopeProvider.notifier).change('account-b');
    action();
    await tester.pumpAndSettle();
    expect(find.text('Recebimento · Bitcoin — rede'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet row uses recorded fiat without repricing the operation',
      (tester) async {
    await pumpWalletList(
        tester,
        TransactionList(transactions: [
          _transaction(
              id: 'recorded-fiat',
              amountSatoshis: 150000,
              type: TransactionType.receive,
              displayAmountBrl: 50.25),
        ]));
    expect(find.textContaining('50,25'), findsOneWidget);
    expect(find.textContaining('525,00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const walletHistoryDestination =
    'bc1qdestinationaddresswithaverylongvalue1111111111111111';

const walletHistorySource =
    'bc1qsourceaddresswithaverylongvalue00000000000000000000';

TransactionList walletHistoryFixture() => TransactionList(transactions: [
      _transaction(
          id: 'exact-incoming',
          amountSatoshis: 1,
          type: TransactionType.receive,
          fromAddress: walletHistorySource),
      _transaction(
          id: 'exact-outgoing',
          amountSatoshis: 70000,
          type: TransactionType.send,
          toAddress:
              'bc1qdestinationaddresswithaverylongvalue1111111111111111'),
    ]);

final walletListTestScopeProvider =
    NotifierProvider<WalletListTestScope, String>(WalletListTestScope.new);

class WalletListTestScope extends Notifier<String> {
  @override
  String build() => 'account-a';
  void change(String value) => state = value;
}

Future<ProviderContainer> pumpWalletList(WidgetTester tester, Widget child,
    {AppThemeVariant variant = AppThemeVariant.dark,
    double scale = 1,
    Size size = const Size(320, 740)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(const {});
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    sessionStorageScopeProvider
        .overrideWith((ref) => ref.watch(walletListTestScopeProvider)),
    moneyFormatConfigProvider.overrideWithValue(const MoneyFormatConfig(
        currency: Currency.brl, locale: Locale('pt'), btcDecimalPlaces: 2)),
    latestBtcPriceProvider.overrideWith((ref) => 65000),
    btcEurPriceProvider.overrideWith((ref) => 60000),
    btcBrlPriceProvider.overrideWith((ref) => 350000),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor(variant).copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!),
        home: Scaffold(
          body: child,
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Transaction _transaction({
  required String id,
  required int amountSatoshis,
  required TransactionType type,
  String fromAddress = 'bc1qsourceaddress',
  String toAddress = 'bc1qdestinationaddress',
  double? displayAmountBrl,
  int feeSatoshis = 1200,
}) {
  return Transaction(
    id: id,
    fromAddress: fromAddress,
    toAddress: toAddress,
    amountSatoshis: amountSatoshis,
    feeSatoshis: feeSatoshis,
    status: TransactionStatus.confirmed,
    type: type,
    confirmations: 6,
    timestamp: DateTime(2026, 6, 15, 12),
    displayAmountBrl: displayAmountBrl,
  );
}
