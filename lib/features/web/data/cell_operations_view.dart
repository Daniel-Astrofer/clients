/// Presentation checks also fail closed when an older/malformed API omits evidence.
class CellOperationsView {
  final Map<String, dynamic> data;
  final List<String> blockers;
  final bool ready;
  final bool canPlan;
  final String verification;

  CellOperationsView._(
      this.data, this.blockers, this.ready, this.canPlan, this.verification);

  factory CellOperationsView.fromJson(Map<String, dynamic> data,
      {DateTime? now}) {
    final blockers = (data['blockers'] is List
            ? (data['blockers'] as List).whereType<String>()
            : <String>['BLOCKER_EVIDENCE_MISSING'])
        .toSet();
    final verified = data['verification'] == 'VERIFIED';
    if (data['blockers'] is List &&
        (data['blockers'] as List).any((blocker) => blocker is! String)) {
      blockers.add('BLOCKER_EVIDENCE_MALFORMED');
    }
    final supported = data['schema'] == 'kerosene.cell-operations/v1';
    if (!supported) {
      blockers.add('UNSUPPORTED_OPERATIONAL_SCHEMA');
    }
    if (!verified) blockers.add('BANK_EVIDENCE_UNVERIFIED');
    final checked = DateTime.tryParse('${data['checkedAt'] ?? ''}');
    final issued = DateTime.tryParse('${data['issuedAt'] ?? ''}');
    final expires = DateTime.tryParse('${data['expiresAt'] ?? ''}');
    final clock = (now ?? DateTime.now()).toUtc();
    final age = data['maximumAgeSeconds'];
    final fresh = data['fresh'] == true &&
        checked != null &&
        issued != null &&
        expires != null &&
        checked.isUtc &&
        issued.isUtc &&
        expires.isUtc &&
        age is int &&
        age > 0 &&
        !checked.isAfter(clock) &&
        !issued.isAfter(clock) &&
        expires.isAfter(clock) &&
        clock.difference(issued).inSeconds <= age &&
        clock.difference(checked).inSeconds <= age;
    if (!fresh) blockers.add('OBSERVATIONS_STALE_OR_MISSING');
    final current = map(data['currentRelease']);
    final target = map(data['targetRelease']);
    if (!_releaseIdentity(current)) {
      blockers.add('CURRENT_RELEASE_MISSING');
    }
    if (!_releaseIdentity(target)) {
      blockers.add('TARGET_RELEASE_MISSING');
    }
    final runtime = map(data['coreRuntime']);
    if (runtime['manifestSignatureValid'] != true ||
        runtime['authorized'] != true) {
      blockers.add('CORE_RUNTIME_UNVERIFIED');
    }
    final quorum = map(data['quorum']);
    final votes = maps(quorum['votes']);
    final accepted = votes
        .where((vote) =>
            vote['accepted'] == true &&
            vote['fresh'] == true &&
            vote['status'] == 'compatible' &&
            _identifier(vote['observerId']) &&
            vote['observedSequence'] == target['sequence'] &&
            vote['releaseDigest'] == target['digest'])
        .toList();
    final unique = accepted.map((vote) => vote['observerId']).toSet();
    if (quorum['requiredVotes'] is! int ||
        quorum['compatibleVotes'] is! int ||
        quorum['requiredVotes'] <= 0 ||
        quorum['requiredVotes'] > 64 ||
        quorum['compatibleVotes'] < quorum['requiredVotes'] ||
        quorum['compatibleVotes'] != accepted.length ||
        unique.length != accepted.length) {
      blockers.add('QUORUM_INSUFFICIENT');
    }
    if (!maps(data['backups']).any((backup) => backup['accepted'] == true)) {
      blockers.add('RESTORE_EVIDENCE_MISSING_OR_STALE');
    }
    final update = map(data['update']);
    if (update['phase'] == null ||
        update['phase'] == 'UNKNOWN' ||
        update['history'] is! List) {
      blockers.add('UPDATE_HISTORY_MISSING');
    }
    if (!['IDLE', 'COMPLETED'].contains(update['phase'])) {
      blockers.add('UPDATE_IN_PROGRESS_OR_FAILED');
    }
    if (map(data['kfeMaintenance'])['safeToUpdate'] != true) {
      blockers.add('KFE_MAINTENANCE_NOT_SAFE');
    }
    final canPlan = supported &&
        verified &&
        fresh &&
        map(data['capabilities'])['plan'] == true &&
        _releaseIdentity(target) &&
        _digest(target['digest']) &&
        _digest(target['deploymentManifestDigest']) &&
        _digest(target['packageManifestDigest']);
    return CellOperationsView._(
        data,
        blockers.toList(),
        data['ready'] == true && blockers.isEmpty,
        canPlan,
        verified ? 'VERIFIED' : 'UNVERIFIED');
  }

  static bool _digest(Object? value) =>
      value is String && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);
  static bool _identifier(Object? value) =>
      value is String &&
      RegExp(r'^[a-z0-9][a-z0-9._-]{2,127}$').hasMatch(value);
  static bool _releaseIdentity(Map<String, dynamic> value) =>
      _identifier(value['releaseId']) &&
      _digest(value['digest']) &&
      value['sequence'] is int &&
      value['sequence'] > 0 &&
      value['sequence'] <= 9007199254740991;
  static Map<String, dynamic> map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> maps(Object? value) => value is List
      ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
      : <Map<String, dynamic>>[];
}
