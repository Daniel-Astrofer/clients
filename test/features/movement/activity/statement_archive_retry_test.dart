import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_screen.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import '../../../goldens/golden_harness.dart';

class _Archive extends ActivityArchiveStore {
  _Archive() : super(SecureStorageService());
  bool fail = false;
  int reads = 0;
  Completer<Set<String>>? pending;
  @override
  Future<Set<String>> load(String scope) async {
    reads++;
    if (fail) throw StateError('fixture unavailable');
    return pending == null ? {'known-id'} : await pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  testWidgets(
      'statement retries archive storage independently while retaining its last known ids',
      (tester) async {
    final archive = _Archive();
    var remoteReads = 0;
    await pumpFullScreenGolden(
        tester,
        ProviderScope(overrides: [
          activityArchiveStoreProvider.overrideWithValue(archive),
          // The golden parent has its own archive; keep this fixture's notifier
          // and view metadata in the same child scope as the controlled store.
          activityArchiveProvider.overrideWith(ActivityArchiveNotifier.new),
          activityArchiveReadinessProvider.overrideWith((ref) {
            ref.watch(activityArchiveProvider);
            final current = ref.read(activityArchiveProvider.notifier);
            return (state: current.loadState, checkedAt: current.checkedAt);
          }),
          transactionHistoryProvider.overrideWith((ref) async {
            remoteReads++;
            return [];
          }),
        ], child: const TransactionStatementScreen()),
        size: const Size(320, 740));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionStatementScreen)));
    expect(container.read(activityArchiveProvider), {'known-id'});
    final checked = container.read(activityArchiveReadinessProvider).checkedAt;
    expect(checked, isNotNull);
    archive.fail = true;
    await container.read(activityArchiveProvider.notifier).reload();
    await tester.pumpAndSettle();
    expect(container.read(activityArchiveProvider), {'known-id'});
    expect(container.read(activityArchiveReadinessProvider).checkedAt, checked);
    final retry = find.byKey(const ValueKey('activity-archive-retry'));
    expect(retry, findsOneWidget);
    final remoteBeforeRetry = remoteReads;
    archive.fail = false;
    archive.pending = Completer<Set<String>>();
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(find.byKey(const ValueKey('activity-archive-retry')), findsNothing);
    expect(container.read(activityArchiveProvider), {'known-id'});
    archive.pending!.complete({'known-id', 'recovered-id'});
    await tester.pumpAndSettle();
    expect(
        container.read(activityArchiveProvider), {'known-id', 'recovered-id'});
    expect(container.read(activityArchiveReadinessProvider).state,
        ActivityArchiveLoadState.ready);
    expect(archive.reads, 3);
    expect(remoteReads, remoteBeforeRetry);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
