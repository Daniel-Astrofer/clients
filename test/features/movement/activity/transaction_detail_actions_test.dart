import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../../../goldens/golden_harness.dart';
import 'activity_actions_test.dart' as fixture;

class _StaleHistory extends LastTransactionHistoryNotifier {
  @override
  List<Transaction> build() => [fixture.actionFixture()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  testWidgets(
      'persistent detail keeps cancellation ahead of an equal-time stale record',
      (tester) async {
    final repo = fixture.ActionRepo();
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              transactionRepositoryProvider.overrideWithValue(repo),
              lastTransactionHistoryProvider.overrideWith(_StaleHistory.new),
            ],
            child:
                TransactionDetailScreen(transaction: fixture.actionFixture())),
        size: const Size(320, 740));
    final cancel = find.byKey(const ValueKey('activity-cancel'));
    await tester.scrollUntilVisible(cancel, 350,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await fixture.confirmAction(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(find.text('Movimentação cancelada'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('transaction-detail-status-label')), -350,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-cancel')), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('activity-archive')), 350,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.byKey(const ValueKey('activity-archive')), findsOneWidget);
    AppScreenFeedbackBus.clear();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
