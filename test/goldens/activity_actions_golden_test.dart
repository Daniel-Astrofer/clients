import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import '../features/movement/activity/activity_actions_test.dart' as fixture;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in [AppThemeVariant.dark, AppThemeVariant.light]) {
    for (final archive in [false, true]) {
      testGoldens(
          'activity confirmation and persistent result: $theme $archive',
          (tester) async {
        await fixture.pumpActivityActions(tester,
            repo: fixture.ActionRepo(),
            theme: theme,
            scale: 1.4,
            initial: fixture.actionFixture(
                status: archive
                    ? TransactionStatus.cancelled
                    : TransactionStatus.pending));
        final action = find
            .byKey(ValueKey(archive ? 'activity-archive' : 'activity-cancel'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text(fixture.actionFixture().id), findsOneWidget);
        expect(find.textContaining('≈'), findsNothing);
        expect(find.textContaining('aprox.'), findsNothing);
        expect(tester.takeException(), isNull);
        final name = 'activity_${archive ? 'archive' : 'cancel'}_${theme.name}';
        await screenMatchesGolden(tester, '${name}_dialog');
        await fixture.confirmAction(tester);
        await tester.pumpAndSettle();
        AppScreenFeedbackBus.clear();
        await tester.pumpAndSettle();
        expect(
            find.text(
                archive ? 'Movido para Arquivadas' : 'Movimentação cancelada'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(tester, '${name}_result');
      });
    }
  }
}
