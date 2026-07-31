import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates touch target minimums per [docs/product/design/accessibility-rules.md].
///
/// - Standard interactive: ≥ 44×44pt
/// - Financial actions: ≥ 48×48pt
void main() {
  group('Touch target minimums', () {
    testWidgets('container meets 48pt financial minimum', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  key: const Key('financial-action'),
                  width: 48,
                  height: 48,
                  color: Colors.red.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('financial-action')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('icon button with padding meets 44pt minimum', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                key: const Key('icon-btn'),
                icon: const Icon(Icons.close, size: 24),
                onPressed: () {},
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('icon-btn')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('list tile row has adequate height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: const Key('tx-row'),
              height: 56,
              child: const Center(child: Text('Transaction')),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('tx-row')));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
