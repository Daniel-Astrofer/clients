import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';
import 'package:kerosene/storybook/storybook_mocks.dart' show mockWallets;
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  for (final theme in AppThemeVariant.values) {
    for (final mode in ['session', 'background', 'cancel']) {
      testGoldens('receive owner and cancellation stay clear: $theme $mode',
          (tester) async {
        final link = PaymentLink.fromJson({
          'id': 'public-receive-request-123456789',
          'status': 'PENDING',
          'amountSats': 150000,
          'address': 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'
        });
        await pumpFullScreenGolden(
            tester,
            Theme(
                data: AppTheme.themeFor(theme),
                child: MediaQuery(
                    data: const MediaQueryData(
                        size: Size(320, 740),
                        textScaler: TextScaler.linear(1.4),
                        disableAnimations: true),
                    child: ReceiveRequestFlowScreen(
                        wallet: mockWallets.first,
                        onChainWallet: true,
                        amountBtc: 0.0015,
                        method: ReceiveAmountMethod.qrCode,
                        ownerScope: mode == 'session' ? 'previous-owner' : null,
                        initialPaymentLink: link,
                        enableStatusPolling: false))),
            size: const Size(320, 740));
        if (mode == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await tester.pump();
        }
        if (mode == 'cancel') {
          await tester
              .tap(find.byKey(const ValueKey('receive-cancel-request')));
          await tester.pumpAndSettle();
          expect(find.text(link.id), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await screenMatchesGolden(
            tester, 'receive_session_${mode}_${theme.name}');
        if (mode == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
