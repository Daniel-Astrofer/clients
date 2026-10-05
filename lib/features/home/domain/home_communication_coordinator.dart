import 'package:kerosene/features/home/domain/entities/home_communication_item.dart';

/// Deterministic queue for all Home communication surfaces.
///
/// The coordinator stores only the presentation contract. The caller keeps
/// the original source model (notification, stage or feed item) keyed by
/// [HomeCommunicationItem.stableKey].
class HomeCommunicationCoordinator {
  HomeCommunicationItem? _current;
  final List<HomeCommunicationItem> _pending = <HomeCommunicationItem>[];

  HomeCommunicationItem? get current => _current;
  List<HomeCommunicationItem> get pending => List.unmodifiable(_pending);

  void enqueue(HomeCommunicationItem item) {
    if (item.read || item.isExpired) return;
    if (_current?.stableKey == item.stableKey ||
        _pending.any((queued) => queued.stableKey == item.stableKey)) {
      return;
    }

    final current = _current;
    if (current == null) {
      _current = item;
      return;
    }

    if (item.priority > current.priority) {
      _pending.add(current);
      _current = item;
    } else {
      _pending.add(item);
    }
    _sortPending();
  }

  HomeCommunicationItem? dismiss() {
    _current = _pending.isEmpty ? null : _pending.removeAt(0);
    return _current;
  }

  void clear() {
    _current = null;
    _pending.clear();
  }

  void _sortPending() {
    _pending.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      return (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
  }
}
