import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/security/secure_screen_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureSeedVisibility', () {
    test('reveal / hide toggle', () {
      var ticks = 0;
      final vis = SecureSeedVisibility(onChanged: () => ticks++);
      expect(vis.visible, isFalse);
      vis.reveal();
      expect(vis.visible, isTrue);
      expect(ticks, 1);
      vis.hide();
      expect(vis.visible, isFalse);
      expect(ticks, 2);
      vis.toggle();
      expect(vis.visible, isTrue);
    });

    testWidgets('hides when app pauses', (tester) async {
      var ticks = 0;
      final vis = SecureSeedVisibility(onChanged: () => ticks++);
      vis.attach();
      vis.reveal();
      expect(vis.visible, isTrue);

      vis.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(vis.visible, isFalse);
      expect(ticks, greaterThanOrEqualTo(2));

      vis.detach();
    });
  });

  group('SecureScreenGuard', () {
    test('enter/leave are ref-counted without throwing in tests', () async {
      await SecureScreenGuard.enter();
      await SecureScreenGuard.enter();
      await SecureScreenGuard.leave();
      await SecureScreenGuard.leave();
      // Extra leave is a no-op.
      await SecureScreenGuard.leave();
    });
  });
}
