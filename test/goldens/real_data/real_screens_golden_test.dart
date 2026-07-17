import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:kerosene/features/financial_accounts/presentation/widgets/wallet_flow_selector.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/movement/screens/send_money_screen.dart';
import 'package:kerosene/features/movement/screens/statement_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_screen.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';

import 'real_golden_harness.dart';

/// Real-data full-scroll goldens from **device session export**.
///
/// 1. Open the app on phone/Linux (already logged in).
/// 2. Tap blue **DADOS** (exports wallets/txs/user — no passwords).
/// 3. `bash tools/device-snapshot-goldens.sh` → pulls JSON + updates goldens.
///
/// No credentials in the shell. Source file:
/// `test/goldens/real_data/fixtures/device_ui_snapshot.json`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeRealGoldenHarness);

  group('Real-data full-scroll goldens (device snapshot)', () {
    Future<void> shot(
      WidgetTester tester,
      String name,
      Widget child,
    ) async {
      await pumpRealFullScrollGolden(tester, child);
      await screenMatchesGolden(
        tester,
        name,
        customPump: (t) async {
          await t.pump(const Duration(milliseconds: 50));
        },
      );
      // Fire education delayed(50s) while tree is still mounted, then dispose
      // so periodic timers cancel cleanly (avoids pending-timer test failure).
      await tester.pump(const Duration(seconds: 55));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testGoldens('home — real wallets & activity', (tester) async {
      await shot(tester, 'real_home_screen', const HomeScreen());
    });

    testGoldens('settings — real account shell', (tester) async {
      await shot(
        tester,
        'real_settings_screen',
        const SettingsScreen(showPrimaryNavigation: true),
      );
    });

    testGoldens('activity / statement — real txs', (tester) async {
      await shot(
        tester,
        'real_activity_screen',
        const TransactionStatementScreen(),
      );
    });

    testGoldens('wallet selector — real wallets', (tester) async {
      await shot(
        tester,
        'real_wallet_selector',
        WalletFlowSelector(
          title: 'Enviar',
          subtitle: 'Escolha a carteira',
          onContinue: (_) {},
        ),
      );
    });

    testGoldens('send money — real selected wallet', (tester) async {
      final walletId = realGoldenSnapshot.wallets.isNotEmpty
          ? realGoldenSnapshot.wallets.first.id
          : (mockWallets.isNotEmpty ? mockWallets.first.id : '0');
      await shot(
        tester,
        'real_send_money_screen',
        SendMoneyScreen(walletId: walletId),
      );
    });
  }, skip: !shouldRunRealGoldens);
}
