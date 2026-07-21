enum ActivityLifecycle { pending, settled, failed, cancelled }

class ActivityRecord {
  final String id;
  final String handlerId;
  final double amountBtc;
  final ActivityLifecycle status;
  final Map<String, String> attributes;
  final DateTime createdAt;

  const ActivityRecord({
    required this.id,
    required this.handlerId,
    required this.amountBtc,
    required this.status,
    this.attributes = const {},
    required this.createdAt,
  });
}
