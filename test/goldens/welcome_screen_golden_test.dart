import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:kerosene/features/auth/presentation/screens/welcome_screen.dart';

import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeGoldenHarness);

  testGoldens('welcome screen', (tester) async {
    await pumpFullScreenGolden(tester, const WelcomeScreen());
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(() =>
        precacheImage(image.image, tester.element(find.byType(WelcomeScreen))));
    await tester.pump();
    await screenMatchesGolden(tester, 'welcome_screen');
  });
}
