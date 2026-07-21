import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_value_entry_surface.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('amount hero updates without throwing when typing',
      (tester) async {
    var amount = '0';
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return TransactionValueEntrySurface(
              onBack: () {},
              amountInput: amount,
              unitLabel: '₿',
              currency: Currency.btc,
              fiatReference: '≈ R\$ 0,00',
              showKeypad: true,
              onKeyTap: (key) {
                setState(() {
                  if (key == '←') {
                    amount = amount.length <= 1
                        ? '0'
                        : amount.substring(0, amount.length - 1);
                  } else if (amount == '0' && key != '.') {
                    amount = key;
                  } else {
                    amount = '$amount$key';
                  }
                });
              },
              ctaLabel: 'Continuar',
              ctaEnabled: true,
              isBusy: false,
              onCta: () {},
            );
          },
        ),
      ),
    );

    expect(find.text('0'), findsWidgets);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 180));
    // Hero splits prefix + last digit for animation.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.byIcon(KeroseneIcons.backspace));
    await tester.pump(const Duration(milliseconds: 180));
    // After backspace amount is "1" again.
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('reduced motion still shows amount text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(
          TransactionValueEntrySurface(
            onBack: () {},
            amountInput: '1.5',
            unitLabel: '₿',
            currency: Currency.btc,
            fiatReference: '≈ R\$ 100',
            showKeypad: false,
            ctaLabel: 'OK',
            ctaEnabled: true,
            isBusy: false,
            onCta: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('1'), findsWidgets);
  });
}
