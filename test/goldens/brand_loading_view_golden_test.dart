import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/design_system/components/generic/tor_navigation_loading_screen.dart';

import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);

  for (final reduced in [false, true]) {
    testGoldens('loading dots, reduced motion: $reduced', (tester) async {
      await pumpFullScreenGolden(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(reduced ? 1.7 : 1),
              disableAnimations: reduced,
            ),
            child: const TorNavigationLoadingScreen(usePrimaryKey: false),
          ),
          size: const Size(320, 568));
      await screenMatchesGolden(
        tester,
        reduced ? 'dots_loading_reduced_large_text' : 'dots_loading_compact',
        customPump: pumpGoldenAnimationFrame,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
