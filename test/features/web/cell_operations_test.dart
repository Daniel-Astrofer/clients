import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/web/data/cell_operations_view.dart';
import 'package:kerosene/features/web/providers/admin_providers.dart';
import 'package:kerosene/features/web/theme/admin_theme.dart';
import 'package:kerosene/features/web/widgets/cell_operations_card.dart';

Map<String, dynamic> evidence(DateTime now) => {
      'schema': 'kerosene.cell-operations/v1',
      'verification': 'VERIFIED',
      'fresh': true,
      'ready': true,
      'checkedAt': now.toIso8601String(),
      'issuedAt': now.subtract(const Duration(seconds: 5)).toIso8601String(),
      'expiresAt': now.add(const Duration(seconds: 60)).toIso8601String(),
      'maximumAgeSeconds': 300,
      'blockers': <String>[],
      'currentRelease': {
        'releaseId': 'release-old',
        'sequence': 1,
        'digest': 'sha256:${'d' * 64}'
      },
      'targetRelease': {
        'releaseId': 'release-new',
        'sequence': 2,
        'digest': 'sha256:${'a' * 64}',
        'deploymentManifestDigest': 'sha256:${'b' * 64}',
        'packageManifestDigest': 'sha256:${'c' * 64}'
      },
      'coreRuntime': {'manifestSignatureValid': true, 'authorized': true},
      'quorum': {
        'requiredVotes': 1,
        'compatibleVotes': 1,
        'votes': [
          {
            'observerId': 'bank-one',
            'fresh': true,
            'accepted': true,
            'status': 'compatible',
            'observedSequence': 2,
            'releaseDigest': 'sha256:${'a' * 64}'
          }
        ]
      },
      'backups': [
        {
          'backupId': 'backup-one',
          'accepted': true,
          'restoreEvidence': {'status': 'PASSED'}
        }
      ],
      'update': {'phase': 'IDLE', 'history': <Map<String, dynamic>>[]},
      'kfeMaintenance': {
        'mode': 'DRAINED',
        'revision': 4,
        'safeToUpdate': true
      },
      'capabilities': {'plan': true, 'execute': false},
    };

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  test('missing evidence blocks even if server claims ready', () {
    final view = CellOperationsView.fromJson({'ready': true}, now: now);
    expect(view.ready, false);
    expect(view.canPlan, false);
    expect(view.verification, 'UNVERIFIED');
    expect(view.blockers, contains('KFE_MAINTENANCE_NOT_SAFE'));
  });
  test(
      'fresh verified evidence can record intent and stale evidence disables it',
      () {
    final data = evidence(now);
    expect(CellOperationsView.fromJson(data, now: now).ready, true);
    expect(CellOperationsView.fromJson(data, now: now).canPlan, true);
    final stale = CellOperationsView.fromJson(data,
        now: now.add(const Duration(seconds: 301)));
    expect(stale.ready, false);
    expect(stale.canPlan, false);
    expect(
        CellOperationsView.fromJson(data,
                now: now.add(const Duration(seconds: 61)))
            .ready,
        false);
    data['kfeMaintenance'] = {'safeToUpdate': false};
    expect(CellOperationsView.fromJson(data, now: now).ready, false);
  });
  testWidgets('missing evidence shows blockers and disabled planning',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          adminCellOperationsProvider
              .overrideWith((ref) async => {'ready': true}),
          adminCellUpdatesProvider.overrideWith((ref) async => {'plans': []}),
        ],
        child: MaterialApp(
            theme: AdminTheme.themeData,
            home: const Scaffold(
                body: SingleChildScrollView(child: CellOperationsCard())))));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('UNVERIFIED · Readiness blocked'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.textContaining('KFE_MAINTENANCE_NOT_SAFE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'unknown schema, invented vote count and interrupted update block presentation',
      () {
    final unknown = evidence(now)..['schema'] = 'kerosene.cell-operations/v999';
    expect(CellOperationsView.fromJson(unknown, now: now).canPlan, false);
    final invented = evidence(now);
    (invented['quorum'] as Map)['compatibleVotes'] = 3;
    expect(CellOperationsView.fromJson(invented, now: now).ready, false);
    final duplicate = evidence(now);
    final quorum = duplicate['quorum'] as Map;
    (quorum['votes'] as List).add((quorum['votes'] as List).first);
    quorum['compatibleVotes'] = 2;
    expect(CellOperationsView.fromJson(duplicate, now: now).ready, false);
    final interrupted = evidence(now)
      ..['update'] = {'phase': 'FAILED', 'history': []};
    expect(CellOperationsView.fromJson(interrupted, now: now).ready, false);
  });
  testWidgets(
      'verified evidence renders votes, restore and distinct plan state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          adminCellOperationsProvider
              .overrideWith((ref) async => evidence(DateTime.now().toUtc())),
          adminCellUpdatesProvider.overrideWith((ref) async => {
                'plans': [
                  {
                    'planId': 'plan-one',
                    'status': 'PLANNED',
                    'targetReleaseId': 'release-new'
                  }
                ]
              }),
        ],
        child: MaterialApp(
            theme: AdminTheme.themeData,
            home: const Scaffold(
                body: SingleChildScrollView(child: CellOperationsCard())))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Evidence ready'), findsOneWidget);
    expect(find.textContaining('bank-one:'), findsOneWidget);
    expect(find.textContaining('Deployment not executed'), findsOneWidget);
    expect(find.text('Create plan (no execution)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
