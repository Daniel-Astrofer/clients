import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  final txid = List.filled(4, '0123456789abcdef').join();
  final transaction = Transaction(
      id: 'full-public-operation-identifier',
      fromAddress: 'bc1q${List.filled(4, 'sourceabcdefgh').join()}',
      toAddress: 'bc1q${List.filled(4, 'destinationabcdef').join()}',
      amountSatoshis: 1,
      feeSatoshis: 2,
      serviceFeeSatoshis: 3,
      status: TransactionStatus.confirming,
      type: TransactionType.send,
      confirmations: 2,
      blockchainTxid: txid,
      timestamp: DateTime(2020, 1, 1, 12));
  for (final variant in AppThemeVariant.values) {
    testGoldens(
        'activity data stays complete in compact expanded card: $variant',
        (tester) async {
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(variant),
              child: MediaQuery(
                data: const MediaQueryData(
                    size: Size(320, 740),
                    textScaler: TextScaler.linear(1.4),
                    disableAnimations: true),
                child: Scaffold(
                    body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: StatementTransactionCard(
                      transaction: transaction,
                      density: StatementTransactionCardDensity.home,
                      expanded: true),
                )),
              )),
          size: const Size(320, 740));
      await screenMatchesGolden(
          tester, 'statement_complete_${variant.name}_compact');
      await tester
          .ensureVisible(find.byKey(const ValueKey('statement-copy-txid')));
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'statement_complete_id_${variant.name}_compact');
      expect(find.widgetWithText(SelectableText, txid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testGoldens(
      'export sheet describes only loaded history and exact identifiers',
      (tester) async {
    await pumpFullScreenGolden(tester, const TransactionStatementScreen(),
        size: const Size(320, 740));
    await tester.tap(find.byIcon(KeroseneIcons.download).first);
    await tester.pumpAndSettle();
    expect(find.text('Incluir todos os movimentos carregados'), findsOneWidget);
    expect(find.textContaining('Identificadores completos'), findsOneWidget);
    await screenMatchesGolden(tester, 'statement_export_sheet_compact');
    expect(tester.takeException(), isNull);
  });
}
