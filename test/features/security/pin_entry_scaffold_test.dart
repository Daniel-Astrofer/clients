import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';

void main() {
  testWidgets('exposes confirmation button and keyboard submission',
      (tester) async {
    var confirmations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PinEntryScaffold(
          instruction: 'PIN',
          valueLength: 4,
          maxLength: 8,
          error: null,
          busy: false,
          onDigit: (_) {},
          onDelete: () {},
          onConfirm: () => confirmations += 1,
          confirmLabel: 'Confirmar',
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Confirmar'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    expect(confirmations, 1);

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(confirmations, 2);
  });

  testWidgets('does not expose confirmation while callback is unavailable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PinEntryScaffold(
          instruction: 'PIN',
          valueLength: 4,
          maxLength: 4,
          error: 'Rede indisponível',
          busy: false,
          onDigit: (_) {},
          onDelete: () {},
          onConfirm: null,
          confirmLabel: 'Confirmar',
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Confirmar'), findsNothing);
  });
}
