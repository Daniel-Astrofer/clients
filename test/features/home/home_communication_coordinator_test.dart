import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_communication_item.dart';
import 'package:kerosene/features/home/domain/home_communication_coordinator.dart';

HomeCommunicationItem _item(String id, int priority) => HomeCommunicationItem(
      id: id,
      source: HomeCommunicationSource.notification,
      title: id,
      body: '',
      priority: priority,
      timestamp: DateTime(2026, 9, 26),
    );

void main() {
  test('higher priority item interrupts and preserves current item', () {
    final coordinator = HomeCommunicationCoordinator();
    coordinator.enqueue(_item('editorial', 50));
    coordinator.enqueue(_item('security', 400));

    expect(coordinator.current?.id, 'security');
    expect(coordinator.dismiss()?.id, 'editorial');
  });

  test('duplicate stable keys are ignored', () {
    final coordinator = HomeCommunicationCoordinator();
    coordinator.enqueue(_item('same', 300));
    coordinator.enqueue(_item('same', 300));

    expect(coordinator.pending, isEmpty);
  });
}
