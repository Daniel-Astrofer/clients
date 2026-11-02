import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/design_system/components/generic/tor_loading_dots.dart';
import 'package:kerosene/design_system/components/generic/tor_navigation_loading_screen.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('startup shows only dots, reduced motion: $reducedMotion',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 568),
            disableAnimations: reducedMotion,
            textScaler: const TextScaler.linear(2),
          ),
          child: const TorNavigationLoadingScreen(usePrimaryKey: false),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TorLoadingDots), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
