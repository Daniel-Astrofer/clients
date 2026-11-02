import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import '../features/movement/screens/receive_gateway_providers_screen_test.dart'
    as fixture;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final variant in AppThemeVariant.values) {
    testGoldens('purchase links and complete checkout: $variant',
        (tester) async {
      await fixture.pumpGateway(tester,
          variant: variant,
          scale: 1.4,
          load: () async => fixture.gatewaySnapshot({
                'mercado_pago':
                    'https://pagamentos.example/checkout?invoice=fixture123&amount=250.50&currency=BRL',
                'Outro vendedor': 'https://outro.example/checkout',
              }));
      await screenMatchesGolden(
          tester, 'gateway_links_${variant.name}_compact');
      await tester.ensureVisible(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'gateway_checkout_${variant.name}_compact');
      await tester
          .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'gateway_checkout_actions_${variant.name}_compact');
      expect(tester.takeException(), isNull);
    });

    testGoldens('purchase closes old checkout when session changes: $variant',
        (tester) async {
      final container = await fixture.pumpGateway(tester,
          variant: variant,
          scale: 1.8,
          load: () async => fixture.gatewaySnapshot({
                'mercado_pago': 'https://pagamentos.example/checkout',
              }));
      await tester.ensureVisible(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      expect(find.text('Mercado Pago').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('gateway-open-checkout')), findsOneWidget);
      container
          .read(fixture.gatewayTestSessionProvider.notifier)
          .change('account-b');
      await tester.pumpAndSettle();
      await screenMatchesGolden(
          tester, 'gateway_session_changed_${variant.name}');
      expect(find.textContaining('A sessão mudou'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
