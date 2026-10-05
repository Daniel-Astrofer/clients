import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:kerosene/features/movement/presentation/send/send_money_screen.dart';

import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeGoldenHarness);

  testGoldens('send money screen', (tester) async {
    await pumpFullScreenGolden(
      tester,
      const SendMoneyScreen(),
    );
    await screenMatchesGolden(tester, 'send_money_screen');
  });
}
