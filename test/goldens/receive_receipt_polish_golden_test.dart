import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/storybook/storybook_mocks.dart' show mockWallets;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final variant in AppThemeVariant.values) {
    testGoldens('receipt retains exact amount and full destination: $variant',
        (tester) async {
      const address = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
      final link = PaymentLink.fromJson({
        'id': 'public-fixture-receipt',
        'status': 'PAID',
        'settlementStatus': 'SETTLED',
        'amountSats': 150000,
        'receiverAmountSats': 140001,
        'address': address,
        'createdAt': '2020-01-01T12:00:00Z',
        'confirmations': 6
      });
      await pumpFullScreenGolden(
          tester,
          Theme(
              data: AppTheme.themeFor(variant),
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 740),
                      textScaler: TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: ReceiveRequestFlowScreen(
                      wallet: mockWallets.first,
                      onChainWallet: true,
                      amountBtc: 0.0015,
                      money: const MovementMoney(
                          locale: Locale('pt'), btcDecimalPlaces: 2),
                      method: ReceiveAmountMethod.qrCode,
                      initialPaymentLink: link,
                      enableStatusPolling: false,
                      identifiedAt: DateTime(2020, 1, 1, 12)))),
          size: const Size(320, 740));
      expect(find.text('0,00140001 BTC'), findsOneWidget);
      await screenMatchesGolden(
          tester, 'receive_receipt_${variant.name}_summary');
      await tester.ensureVisible(find.text(address));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester, 'receive_receipt_${variant.name}_destination');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
