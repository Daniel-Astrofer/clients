import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/generic/custom_error_dialog.dart';
import 'package:kerosene/design_system/components/generic/kerosene_education_dialog.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final variant in AppThemeVariant.values) {
    testGoldens('error action remains legible on compact screen: $variant',
        (tester) async {
      await pumpFullScreenGolden(
          tester,
          Theme(
            data: AppTheme.themeFor(variant),
            child: MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 740), textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => showCustomErrorDialog(context,
                              'Confira os dados antes de tentar novamente. A alteração não foi confirmada.',
                              onRetry: () {}, onGoBack: () {}),
                          child: const Text('Abrir aviso')))),
            ),
          ),
          size: const Size(320, 740));
      await tester.tap(find.text('Abrir aviso'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'monochrome_error_${variant.name}_compact');
    });
    testGoldens('details sheet uses theme and complete content: $variant',
        (tester) async {
      await pumpFullScreenGolden(
          tester,
          Theme(
            data: AppTheme.themeFor(variant),
            child: MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 740), disableAnimations: true),
              child: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => KeroseneEducationDialog.show<bool>(
                              context: context,
                              icon: KeroseneIcons.security,
                              tone: KeroseneEducationTone.security,
                              title: 'Antes de alterar o acesso',
                              body:
                                  'Confira a conta e guarde os novos códigos antes de concluir a alteração.',
                              bullets: const [
                                'A alteração afeta o acesso a esta conta.',
                                'A confirmação só aparece após a resposta do servidor.'
                              ],
                              primaryLabel: 'Entendi',
                              secondaryLabel: 'Voltar'),
                          child: const Text('Ver detalhes')))),
            ),
          ),
          size: const Size(320, 740));
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'monochrome_details_${variant.name}_compact');
    });
  }
}
