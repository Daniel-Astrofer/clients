import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_data_service.dart';
import '../data/cell_operations_view.dart';
import '../providers/admin_providers.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_typography.dart';

/// Authenticated Core API only. Plans record intent; there is no deploy or restore action.
class CellOperationsCard extends ConsumerStatefulWidget {
  const CellOperationsCard({super.key});
  @override
  ConsumerState<CellOperationsCard> createState() => _CellOperationsCardState();
}

class _CellOperationsCardState extends ConsumerState<CellOperationsCard> {
  bool _planning = false;
  String? _result;

  Future<void> _plan(CellOperationsView view) async {
    final target = CellOperationsView.map(view.data['targetRelease']);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Create update plan'),
              content: Text(
                  'Record a plan for ${target['releaseId']} (sequence ${target['sequence']})? '
                  'This records intent and evidence only. Deployment is performed by the Deploy owner.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Create plan')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      _planning = true;
      _result = null;
    });
    try {
      final plan =
          await ref.read(adminDataServiceProvider).createCellPlan(target);
      if (mounted) {
        setState(() => _result =
            '${plan['status'] ?? 'UNKNOWN'} · ${plan['planId'] ?? 'unknown'} · Deployment not executed');
      }
      ref.invalidate(adminCellUpdatesProvider);
      ref.invalidate(adminCellOperationsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _result =
            'Plan not recorded. Refresh evidence and check permissions or plan storage.');
      }
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operations = ref.watch(adminCellOperationsProvider);
    final updates = ref.watch(adminCellUpdatesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 32),
      Row(children: [
        Expanded(child: Text('CELL OPERATIONS', style: AdminTypography.label)),
        IconButton(
            tooltip: 'Refresh Cell evidence',
            onPressed: () {
              ref.invalidate(adminCellOperationsProvider);
              ref.invalidate(adminCellUpdatesProvider);
            },
            icon: const Icon(Icons.refresh, size: 18)),
      ]),
      operations.when(
        loading: () => Semantics(
            label: 'Loading Cell evidence',
            child: const LinearProgressIndicator()),
        error: (_, __) => Text(
            'UNVERIFIED · Readiness blocked. Cell evidence unavailable.',
            style: AdminTypography.caption),
        data: (data) {
          final view = CellOperationsView.fromJson(data);
          final current = CellOperationsView.map(data['currentRelease']);
          final target = CellOperationsView.map(data['targetRelease']);
          final quorum = CellOperationsView.map(data['quorum']);
          final update = CellOperationsView.map(data['update']);
          final kfe = CellOperationsView.map(data['kfeMaintenance']);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${view.verification} · ${view.ready ? 'Evidence ready' : 'Readiness blocked'}',
                    style: AdminTypography.caption.copyWith(
                        color: view.ready
                            ? AdminColors.positive
                            : AdminColors.warning)),
                _line('Cell / network',
                    '${data['cellId'] ?? 'unknown'} / ${data['networkId'] ?? 'unknown'}'),
                _line('Current release',
                    '${current['releaseId'] ?? 'missing'} · sequence ${current['sequence'] ?? '?'}'),
                _line('Current digest', '${current['digest'] ?? 'missing'}'),
                _line('Target release',
                    '${target['releaseId'] ?? 'missing'} · sequence ${target['sequence'] ?? '?'}'),
                _line('Target digest', '${target['digest'] ?? 'missing'}'),
                _line('Deployment configuration',
                    '${target['deploymentManifestDigest'] ?? 'missing'}'),
                _line('Package manifest',
                    '${target['packageManifestDigest'] ?? 'missing'}'),
                _line('Freshness',
                    '${data['issuedAt'] ?? 'missing'} → ${data['expiresAt'] ?? 'missing'}'),
                _line('Quorum',
                    '${quorum['compatibleVotes'] ?? 0} / ${quorum['requiredVotes'] ?? '?'} votes'),
                for (final vote in CellOperationsView.maps(quorum['votes']))
                  _line(
                      '${vote['observerId'] ?? 'unknown'}',
                      '${vote['status'] ?? 'unknown'} · '
                          '${vote['fresh'] == true ? 'fresh' : 'STALE'} · accepted=${vote['accepted'] == true} · '
                          'sequence ${vote['observedSequence'] ?? '?'} · ${vote['observedAt'] ?? 'missing'} · ${vote['releaseDigest'] ?? 'missing'}'),
                _line('KFE maintenance',
                    '${kfe['mode'] ?? 'UNKNOWN'} · revision ${kfe['revision'] ?? '?'} · safe=${kfe['safeToUpdate'] == true}'),
                _line('KFE observed / change',
                    '${kfe['observedAt'] ?? 'missing'} · ${kfe['changeId'] ?? 'none'}'),
                _line(
                    'KFE blockers',
                    jsonEncode(
                        kfe['blockers'] ?? {'KFE_MAINTENANCE_UNAVAILABLE': 1})),
                Text('Blockers', style: AdminTypography.label),
                if (view.blockers.isEmpty)
                  _line('Evidence', 'No reported blockers'),
                for (final blocker in view.blockers) _line('Blocked', blocker),
                Text('Backup / restore evidence', style: AdminTypography.label),
                if (CellOperationsView.maps(data['backups']).isEmpty)
                  _line('Restore', 'Evidence missing'),
                for (final backup
                    in CellOperationsView.maps(data['backups'])) ...[
                  _line('${backup['backupId'] ?? 'unknown'}',
                      '${backup['createdAt'] ?? 'missing'} · accepted=${backup['accepted'] == true}'),
                  _line('Backup digest',
                      '${backup['objectDigest'] ?? 'missing'}'),
                  _line('Restore evidence',
                      jsonEncode(backup['restoreEvidence'] ?? {})),
                ],
                _line('Update phase', '${update['phase'] ?? 'UNKNOWN'}'),
                for (final event in CellOperationsView.maps(update['history']))
                  _line('History', jsonEncode(event)),
                FilledButton(
                    onPressed:
                        view.canPlan && !_planning ? () => _plan(view) : null,
                    child: Text(_planning
                        ? 'Recording plan…'
                        : 'Create plan (no execution)')),
                if (_result != null)
                  Semantics(
                      liveRegion: true,
                      child: Text(_result!, style: AdminTypography.caption)),
              ]);
        },
      ),
      updates.when(
        data: (data) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recorded update plans', style: AdminTypography.label),
          if (CellOperationsView.maps(data['plans']).isEmpty)
            _line('Plans', 'None recorded'),
          for (final plan in CellOperationsView.maps(data['plans'])) ...[
            _line('${plan['planId'] ?? 'unknown'}',
                '${plan['status'] ?? 'UNKNOWN'} · ${plan['targetReleaseId'] ?? '?'} · ${plan['createdAt'] ?? '?'}'),
            _line('Plan evidence',
                '${plan['evidenceDigest'] ?? 'missing'} · Deployment not executed'),
            _line('Plan blockers', jsonEncode(plan['blockers'] ?? [])),
          ],
        ]),
        loading: () => _line('Plans', 'Loading'),
        error: (_, __) => _line('Plans', 'History unavailable'),
      ),
    ]);
  }

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: SelectableText('$label: $value',
              style: AdminTypography.caption)));
}
