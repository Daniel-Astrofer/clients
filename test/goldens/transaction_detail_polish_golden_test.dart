import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'golden_harness.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import '../features/movement/activity/transaction_explorer_action_test.dart'
    as explorer;
import '../features/movement/activity/transaction_detail_polish_test.dart'
    as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    testGoldens(
        'explorer failure leaves a clear retry and intact details: $theme',
        (tester) async {
      await fixture.pumpPolishedDetail(tester, explorer.explorerFixture(),
          theme: theme, scale: 1.4, explorerLauncher: (_) async => false);
      await tester.tap(find.byKey(const ValueKey('transaction-explorer-open')));
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'transaction_explorer_failed_${theme.name}');
      AppScreenFeedbackBus.clear();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testGoldens('exact operation summary and identifiers: $theme',
        (tester) async {
      final tx = fixture.detailPolishFixture(amount: 1, fee: 2);
      await fixture.pumpPolishedDetail(tester, tx, theme: theme, scale: 1.4);
      await screenMatchesGolden(
          tester, 'transaction_detail_${theme.name}_summary');
      await tester.scrollUntilVisible(find.text(tx.blockchainTxid!), 260,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(find.widgetWithText(SelectableText, tx.blockchainTxid!),
          findsOneWidget);
      await screenMatchesGolden(
          tester, 'transaction_detail_${theme.name}_identifiers');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testGoldens('operation detail fits the Linux viewport: $theme',
        (tester) async {
      await fixture.pumpPolishedDetail(
          tester, fixture.detailPolishFixture(lightning: true),
          theme: theme, scale: 1.25, size: const Size(900, 700));
      await screenMatchesGolden(
          tester, 'transaction_detail_${theme.name}_linux');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
