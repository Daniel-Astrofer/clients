import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_ui_scale.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double size) => size * (size < 20 ? 1.8 : 1.3);
  @override
  double get textScaleFactor => 1.8;
}

void main() {
  test('normal density preserves nonlinear system scaling', () {
    const scaler = KeroseneTextScaler(_NonlinearScaler());
    for (final size in [10.0, 16.0, 28.0, 48.0]) {
      expect(scaler.scale(size), const _NonlinearScaler().scale(size));
    }
  });
  testWidgets('routes and dialogs retain normal text and icon sizes',
      (tester) async {
    late BuildContext routeContext;
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(390, 844), textScaler: _NonlinearScaler()),
            child: KeroseneUiScale(
                child: KeroseneResponsiveBoundary(
                    child: KeroseneUiScale(child: child!)))),
        home: Builder(builder: (context) {
          routeContext = context;
          return Scaffold(
              body: Column(children: [
            const Text('Saldo', style: TextStyle(fontSize: 28)),
            const TextField(decoration: InputDecoration(labelText: 'Valor')),
            IconButton(
                key: const ValueKey('action'),
                tooltip: 'Enviar',
                onPressed: () => taps++,
                icon: const KeroseneIcon(Icons.send, size: 24)),
            QrImageView(
                key: const ValueKey('qr'), data: 'bitcoin:test', size: 180),
          ]));
        })));
    expect(MediaQuery.textScalerOf(routeContext).scale(28), 36.4);
    expect(
        MediaQuery.textScalerOf(tester.element(find.byType(TextField)))
            .scale(16),
        28.8);
    expect(tester.getSize(find.byKey(const ValueKey('action'))).shortestSide,
        greaterThanOrEqualTo(48));
    expect(
        tester.getSize(find.byKey(const ValueKey('qr'))), const Size(180, 180));
    expect(
        find.descendant(
            of: find.byIcon(Icons.send), matching: find.byType(Transform)),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('action')));
    expect(taps, 1);
    showDialog<void>(
        context: routeContext,
        builder: (context) => AlertDialog(
            title: Text('${MediaQuery.textScalerOf(context).scale(16)}')));
    await tester.pumpAndSettle();
    expect(find.text('28.8'), findsOneWidget);
    Navigator.of(routeContext).pop();
    await tester.pumpAndSettle();
    Navigator.of(routeContext).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
            body: Text('${MediaQuery.textScalerOf(context).scale(28)}'))));
    await tester.pumpAndSettle();
    expect(find.text('36.4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('icon accessibility avoids double density reduction',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: _NonlinearScaler()),
            child: KeroseneUiScale(child: child!)),
        home: const Center(
            child:
                KeroseneIcon(Icons.send, size: 24, applyTextScaling: true))));
    final glyph = tester.widget<RichText>(find.descendant(
        of: find.byIcon(Icons.send), matching: find.byType(RichText)));
    expect(glyph.text.style!.fontSize, 24 * 1.3);
    expect(
        find.descendant(
            of: find.byIcon(Icons.send), matching: find.byType(Transform)),
        findsNothing);
  });
  testWidgets('public root retains ordinary icons', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Center(child: KeroseneIcon(Icons.send, size: 24))));
    expect(
        find.descendant(
            of: find.byIcon(Icons.send), matching: find.byType(Transform)),
        findsNothing);
  });
}
