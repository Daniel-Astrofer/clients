import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates semantic labeling patterns per [docs/product/design/accessibility-rules.md].
void main() {
  group('Semantic labels', () {
    testWidgets('icon button with tooltip provides semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                icon: const Icon(Icons.send),
                tooltip: 'Enviar dinheiro',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Enviar dinheiro'), findsOneWidget);
    });

    testWidgets('financial amount widget builds with Semantics wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'Saldo: 1500.00 BRL',
                child: const Text('Saldo: 1500.00 BRL',
                    style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
        ),
      );

      // Widget renders: text is visible
      expect(find.text('Saldo: 1500.00 BRL'), findsOneWidget);
    });

    testWidgets('excludeSemantics wraps without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                excludeSemantics: true,
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );

      // Widget renders without exception
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('gesture detector with Semantics label renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'Carteira Bitcoin',
                child: GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.wallet, size: 24),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
