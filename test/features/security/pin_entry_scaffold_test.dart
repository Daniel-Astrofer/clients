import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('announces pending PIN work with reduced motion $reducedMotion',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var confirmations = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: PinEntryScaffold(
                instruction: 'PIN',
                valueLength: 4,
                maxLength: 4,
                error: null,
                busy: true,
                busyLabel: 'Verificando PIN…',
                onDigit: (_) {},
                onDelete: () {},
                onConfirm: () => confirmations += 1,
              ),
            ),
          ),
        );

        expect(find.text('Verificando PIN…'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('pin-working'))),
          matchesSemantics(label: 'Verificando PIN…', isLiveRegion: true),
        );
        expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(confirmations, 0);
      } finally {
        semantics.dispose();
      }
    });
  }

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
  testWidgets(
      'shows help action and keeps secure numeric input limited to four digits',
      (tester) async {
    var value = '';
    var recoveries = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        return PinEntryScaffold(
          instruction: 'Crie seu PIN',
          subtitle: 'Escolha 4 dígitos.',
          valueLength: value.length,
          maxLength: 4,
          error: null,
          busy: false,
          onDigit: (digit) => setState(() => value += digit),
          onDelete: () =>
              setState(() => value = value.substring(0, value.length - 1)),
          onConfirm: null,
          footer: TextButton(
            onPressed: () => recoveries++,
            child: const Text('Recuperar acesso'),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Escolha 4 dígitos.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    await tester.enterText(find.byType(TextField), '12a345');
    await tester.pump();
    expect(value, '1234');
    await tester.tap(find.text('Recuperar acesso'));
    expect(recoveries, 1);
  });

  testWidgets('busy input ignores short edits without a range error',
      (tester) async {
    var edits = 0;
    await tester.pumpWidget(MaterialApp(
        home: PinEntryScaffold(
      instruction: 'PIN',
      valueLength: 4,
      maxLength: 4,
      error: null,
      busy: true,
      onDigit: (_) => edits++,
      onDelete: () => edits++,
      onConfirm: null,
    )));
    tester.widget<TextField>(find.byType(TextField)).onChanged!('');
    await tester.pump();
    expect(edits, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls with large text and a keyboard on a small window',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          viewInsets: const EdgeInsets.only(bottom: 240),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: PinEntryScaffold(
        instruction: 'Confirme seu PIN',
        subtitle: 'Digite os quatro dígitos novamente.',
        valueLength: 2,
        maxLength: 4,
        error: 'Os códigos precisam ser iguais. Tente novamente.',
        busy: false,
        onDigit: (_) {},
        onDelete: () {},
        onConfirm: () {},
        confirmLabel: 'Continuar',
        footer: const Text('Sua conta permanece protegida.'),
      ),
    ));
    await tester.ensureVisible(find.text('Sua conta permanece protegida.'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm, back and invalid feedback dispatch tactile events',
      (tester) async {
    final feedback = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        feedback.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    String? error;
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return PinEntryScaffold(
        instruction: 'PIN',
        valueLength: 4,
        maxLength: 4,
        error: error,
        busy: false,
        onDigit: (_) {},
        onDelete: () {},
        onConfirm: () {},
        confirmLabel: 'Confirmar',
        onCancel: () {},
      );
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.tap(find.byType(IconButton));
    update(() => error = 'PIN inválido');
    await tester.pumpAndSettle();
    expect(feedback, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact'
    ]);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('PIN errors shake only when motion is allowed: $reducedMotion',
        (tester) async {
      String? error;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: StatefulBuilder(builder: (context, setState) {
            update = setState;
            return PinEntryScaffold(
              instruction: 'PIN',
              valueLength: 0,
              maxLength: 4,
              error: error,
              busy: false,
              onDigit: (_) {},
              onDelete: () {},
              onConfirm: null,
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();
      update(() => error = 'PIN incorreto');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final shakeTransform = find.descendant(
        of: find.byKey(const ValueKey('pin-error-motion')),
        matching: find.byType(Transform),
      );
      if (reducedMotion) {
        expect(shakeTransform, findsNothing);
      } else {
        expect(
            tester
                .widget<Transform>(shakeTransform.first)
                .transform
                .storage[12],
            isNot(0));
      }
      await tester.pumpAndSettle();
      expect(find.text('PIN incorreto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
