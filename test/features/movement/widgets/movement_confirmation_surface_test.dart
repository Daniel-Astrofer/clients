import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_confirmation_surface.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';

void main() {
  for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
    testWidgets('complete identifiers wrap at 320px with large text: $variant',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final invoice = 'lnbc${List.filled(200, '1234567890abcdef').join()}';
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.themeFor(variant),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MovementConfirmationSurface(
              title: 'Aguardando confirmação',
              amountLabel: '0,00000001 BTC',
              rows: [
                MovementConfirmationRow(
                  label: 'Fatura Lightning completa',
                  value: invoice,
                  technical: true,
                ),
                const MovementConfirmationRow(
                  label: 'Valor exato',
                  value: '0,00000001 BTC',
                  numeric: true,
                ),
              ],
            ),
          ),
        ),
      ));
      final identifier = find.widgetWithText(SelectableText, invoice);
      expect(identifier, findsOneWidget);
      expect(tester.widget<SelectableText>(identifier).maxLines, isNull);
      expect(tester.getSize(identifier).width, lessThanOrEqualTo(272));
      expect(tester.getSize(identifier).height, greaterThan(80));
      expect(tester.widget<SelectableText>(identifier).style!.fontFamily,
          contains('JetBrainsMono'));
      final amount = find.byWidgetPredicate((widget) =>
          widget is Text &&
          widget.data == '0,00000001 BTC' &&
          widget.style?.fontSize == 14);
      expect(amount, findsOneWidget);
      expect(tester.widget<Text>(amount).style!.fontFamily,
          contains('PlusJakartaSans'));
      expect(
          tester
              .widget<Text>(find.text('Aguardando confirmação'))
              .style!
              .fontFamily,
          contains('PlayfairDisplay'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders configurable confirmation title amount and rows',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MovementConfirmationSurface(
            title: 'Transação Confirmada',
            amountLabel: '0.01000000 BTC',
            supportingLabel: 'R\$ 3.000,00',
            rows: [
              MovementConfirmationRow(label: 'Rede', value: 'Kerosene'),
              MovementConfirmationRow(label: 'Carteira', value: 'Principal'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Transação Confirmada'), findsOneWidget);
    expect(find.text('0.01000000 BTC'), findsOneWidget);
    expect(find.text('R\$ 3.000,00'), findsOneWidget);
    expect(find.text('Rede'), findsOneWidget);
    expect(find.text('Kerosene'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
  });
}
