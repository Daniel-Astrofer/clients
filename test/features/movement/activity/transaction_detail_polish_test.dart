import 'package:flutter/rendering.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/features/movement/presentation/activity/blockchain_explorer.dart';
import '../../../goldens/golden_harness.dart';

Transaction detailPolishFixture({
  TransactionStatus status = TransactionStatus.confirmed,
  bool lightning = false,
  bool incoming = false,
  int amount = 123456789,
  int fee = 0,
  double? recordedBrl,
}) =>
    Transaction(
      id: 'public-internal-operation-1234567890',
      fromAddress: 'bc1q${List.filled(4, 'sourceabcdef').join()}',
      toAddress: 'bc1q${List.filled(4, 'destinationabcdef').join()}',
      receiverDisplayName: 'Marina Silva',
      amountSatoshis: amount,
      feeSatoshis: fee,
      status: status,
      type: incoming ? TransactionType.receive : TransactionType.send,
      confirmations: status == TransactionStatus.confirming ? 2 : 0,
      timestamp: status == TransactionStatus.pending
          ? DateTime.now()
          : DateTime(2020, 1, 1, 12),
      isLightning: lightning,
      blockchainTxid:
          lightning ? null : List.filled(4, '0123456789abcdef').join(),
      paymentHash: lightning ? List.filled(4, 'abcdef0123456789').join() : null,
      displayAmountBrl: recordedBrl,
    );

Future<void> pumpPolishedDetail(
  WidgetTester tester,
  Transaction tx, {
  AppThemeVariant theme = AppThemeVariant.dark,
  double scale = 1,
  Size size = const Size(320, 740),
  Currency currency = Currency.btc,
  BlockchainExplorerLauncher? explorerLauncher,
}) async {
  await pumpFullScreenGolden(
      tester,
      ProviderScope(
          overrides: [
            if (explorerLauncher != null)
              blockchainExplorerLauncherProvider
                  .overrideWithValue(explorerLauncher),
            moneyFormatConfigProvider.overrideWithValue(MoneyFormatConfig(
                currency: currency,
                locale: const Locale('pt'),
                btcDecimalPlaces: 2)),
          ],
          child: Theme(
            data: AppTheme.themeFor(theme),
            child: MediaQuery(
              data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: KeroseneUiScale(
                  child: TransactionDetailScreen(transaction: tx)),
            ),
          )),
      size: size);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);

  testWidgets('long heading remains one word at narrow width and enlarged text',
      (tester) async {
    await pumpPolishedDetail(tester, detailPolishFixture(incoming: true),
        scale: 1.4);
    final paragraph =
        tester.renderObject<RenderParagraph>(find.text('bc1qso...abcdef'));
    final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 15));
    expect(boxes.map((box) => box.top).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('detail navigation removes animation when motion is reduced',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => TransactionDetailScreen.open(
                            context, detailPolishFixture()),
                        child: const Text('Open detail'))))));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(TransactionDetailScreen)))!
            as PageRoute;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('detail projection keeps each identifier once and fiat precision',
      (tester) async {
    final tx = detailPolishFixture(recordedBrl: 123.4567);
    late List<PresentationField> fields;
    await pumpFullScreenGolden(tester, Builder(builder: (context) {
      final presentation = TransactionPresentation.fromTransaction(context, tx,
          displayCurrency: Currency.btc,
          btcUsd: 999999,
          btcEur: 999999,
          btcBrl: 999999);
      fields = presentation.detailTechnicalFields(context, tx,
          appLocale: const Locale('pt'));
      return const SizedBox.shrink();
    }));
    expect(fields.where((f) => f.value == tx.blockchainTxid), hasLength(1));
    expect(fields.singleWhere((f) => f.key == 'internal-id').value, tx.id);
    expect(fields.singleWhere((f) => f.key == 'recorded-brl').value,
        contains('123,4567'));
    expect(fields.map((f) => f.key).toSet(), hasLength(fields.length));
    expect(fields.where((f) => f.key == 'receiver-name'), isEmpty);
  });

  for (final recorded in [0.0, double.nan]) {
    testWidgets('recorded fiat handles zero and invalid values: $recorded',
        (tester) async {
      final tx = detailPolishFixture(recordedBrl: recorded);
      late List<PresentationField> fields;
      await pumpFullScreenGolden(tester, Builder(builder: (context) {
        fields = TransactionPresentation.fromTransaction(context, tx,
                displayCurrency: Currency.btc,
                btcUsd: null,
                btcEur: null,
                btcBrl: null)
            .detailTechnicalFields(context, tx);
        return const SizedBox.shrink();
      }));
      final fiat = fields.where((f) => f.key == 'recorded-brl');
      if (recorded.isFinite) {
        expect(fiat, hasLength(1));
        expect(fiat.single.value, contains('0,00'));
        expect(fiat.single.value, isNot(contains('BTC')));
      } else {
        expect(fiat, isEmpty);
      }
    });
  }

  testWidgets('Lightning hash has one semantic field and no fabricated fiat',
      (tester) async {
    final tx = detailPolishFixture(lightning: true);
    late List<PresentationField> fields;
    await pumpFullScreenGolden(tester, Builder(builder: (context) {
      final presentation = TransactionPresentation.fromTransaction(context, tx,
          displayCurrency: Currency.brl,
          btcUsd: 999999,
          btcEur: 999999,
          btcBrl: 999999);
      fields = presentation.detailTechnicalFields(context, tx);
      return const SizedBox.shrink();
    }));
    expect(fields.where((f) => f.value == tx.paymentHash), hasLength(1));
    expect(fields.where((f) => f.key.startsWith('recorded-')), isEmpty);
    expect(fields.where((f) => f.key == 'onchain-txid'), isEmpty);
  });

  for (final incoming in [false, true]) {
    testWidgets('large exact principal survives the detail: incoming=$incoming',
        (tester) async {
      final tx =
          detailPolishFixture(incoming: incoming, amount: 9007199254740993);
      await pumpPolishedDetail(tester, tx);
      final expected = '${incoming ? '+' : '-'}90071992,54740993 BTC';
      expect(find.text(expected), findsWidgets);
      expect(find.textContaining('54741000'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final entry in [
    (TransactionStatus.pending, KeroseneIcons.timer),
    (TransactionStatus.confirming, KeroseneIcons.timer),
    (TransactionStatus.confirmed, KeroseneIcons.success),
    (TransactionStatus.cancelled, KeroseneIcons.closeCircle),
    (TransactionStatus.failed, KeroseneIcons.error),
  ]) {
    testWidgets('detail conveys ${entry.$1.name} by icon and text',
        (tester) async {
      await pumpPolishedDetail(tester, detailPolishFixture(status: entry.$1),
          scale: 1.6);
      expect(
          tester
              .widget<Icon>(
                  find.byKey(const ValueKey('transaction-detail-status-icon')))
              .icon,
          entry.$2);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('transaction-detail-status-label')))
              .data,
          isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'network fee keeps principal and total distinct without subtitle repeat',
      (tester) async {
    await pumpPolishedDetail(tester, detailPolishFixture(amount: 1, fee: 2));
    await tester.scrollUntilVisible(find.text('-0,00000001 BTC'), 220,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('-0,00000001 BTC'), findsOneWidget);
    expect(find.text('-0,00000003 BTC'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final theme in AppThemeVariant.values) {
    testWidgets('complete technical identifier remains usable: $theme',
        (tester) async {
      final tx = detailPolishFixture(lightning: true);
      await pumpPolishedDetail(tester, tx, theme: theme, scale: 1.4);
      await tester.scrollUntilVisible(find.text(tx.paymentHash!), 280,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(
          find.widgetWithText(SelectableText, tx.paymentHash!), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
