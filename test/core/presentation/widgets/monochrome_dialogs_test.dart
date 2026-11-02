import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/generic/custom_error_dialog.dart';
import 'package:kerosene/design_system/components/generic/kerosene_education_dialog.dart';
import 'package:kerosene/design_system/components/inputs/app_text_field.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/security/presentation/widgets/pin_entry_scaffold.dart';

void mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget home, AppThemeVariant variant,
        {double scale = 1,
        bool reduced = false,
        double keyboard = 0,
        Locale locale = const Locale('pt')}) =>
    MaterialApp(
      theme: AppTheme.themeFor(variant),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
              viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: child!),
      home: home,
    );

void main() {
  for (final variant in AppThemeVariant.values) {
    testWidgets(
        'error dialog stays readable and retryable at large scale: $variant',
        (tester) async {
      mobile(tester);
      var retried = 0;
      final message =
          List.filled(10, 'Confira os dados e tente novamente. ').join();
      await tester.pumpWidget(app(
          Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showCustomErrorDialog(context, message,
                            onRetry: () => retried++, onGoBack: () {}),
                        child: const Text('Abrir')),
                  )),
          variant,
          scale: 1.8,
          keyboard: 160));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final ink = AppTheme.themeFor(variant).colorScheme.onSurface;
      expect(tester.widget<Icon>(find.byIcon(KeroseneIcons.error)).color, ink);
      expect(tester.widget<Text>(find.text(message)).maxLines, isNull);
      await tester.ensureVisible(find.text('Tentar Novamente'));
      await tester.tap(find.text('Tentar Novamente'));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'details use a sheet and return once with reduced motion: $variant',
        (tester) async {
      mobile(tester);
      bool? result;
      var actions = 0;
      await tester.pumpWidget(app(
          Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          result = await KeroseneEducationDialog.show<bool>(
                              context: context,
                              icon: KeroseneIcons.security,
                              tone: KeroseneEducationTone.security,
                              title: 'Dados da alteração',
                              body: List.filled(
                                      8, 'Leia os dados antes de continuar. ')
                                  .join(),
                              primaryLabel: 'Entendi',
                              secondaryLabel: 'Voltar',
                              onPrimary: () => actions++);
                        },
                        child: const Text('Detalhes')),
                  )),
          variant,
          scale: 1.7,
          reduced: true));
      await tester.tap(find.text('Detalhes'));
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
          tester
              .widget<BottomSheet>(find.byType(BottomSheet))
              .animationController!
              .duration,
          Duration.zero);
      final ink = AppTheme.themeFor(variant).colorScheme.onSurface;
      expect(
          tester.widget<Icon>(find.byIcon(KeroseneIcons.security)).color, ink);
      await tester.ensureVisible(find.text('Entendi'));
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(actions, 1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Detalhes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'form validation keeps text icon and monochrome border: $variant',
        (tester) async {
      mobile(tester);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(app(
          Scaffold(
              body: Form(
                  key: form,
                  child: AppTextField(
                      label: 'Nome',
                      validator: (_) => 'Confira o nome informado.'))),
          variant));
      expect(form.currentState!.validate(), false);
      await tester.pump();
      expect(find.text('Confira o nome informado.'), findsOneWidget);
      final theme = AppTheme.themeFor(variant);
      expect(theme.colorScheme.error, theme.colorScheme.onSurface);
      expect(theme.colorScheme.onError, theme.colorScheme.surface);
      expect(tester.widget<Icon>(find.byIcon(KeroseneIcons.error)).color,
          theme.colorScheme.onSurface);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PIN error remains complete and does not animate with reduced motion: $variant',
        (tester) async {
      mobile(tester);
      final message =
          List.filled(5, 'Confira o PIN e tente novamente. ').join();
      await tester.pumpWidget(app(
          PinEntryScaffold(
              instruction: 'Confirmar PIN',
              valueLength: 4,
              maxLength: 6,
              error: message,
              busy: false,
              onDigit: (_) {},
              onDelete: () {},
              onConfirm: () {},
              confirmLabel: 'Confirmar'),
          variant,
          scale: 1.8,
          reduced: true));
      await tester.pump();
      expect(find.text(message), findsOneWidget);
      expect(tester.widget<Text>(find.text(message)).maxLines, isNull);
      expect(find.byIcon(KeroseneIcons.error), findsOneWidget);
      final switches =
          tester.widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(
          switches.every((widget) => widget.duration == Duration.zero), isTrue);
      await tester.ensureVisible(find.text('Confirmar'));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('default error title respects the current language',
      (tester) async {
    await tester.pumpWidget(app(
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        showCustomErrorDialog(context, 'Try again later.'),
                    child: const Text('Open')))),
        AppThemeVariant.dark,
        locale: const Locale('en')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text("We couldn't continue right now"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
