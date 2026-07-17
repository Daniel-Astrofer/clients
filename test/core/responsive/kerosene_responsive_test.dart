import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';

void main() {
  group('KeroseneResponsiveMetrics', () {
    KeroseneResponsiveMetrics metricsFor(double width, {double height = 900}) {
      return KeroseneResponsiveMetrics.fromMediaQuery(
        MediaQueryData(size: Size(width, height)),
      );
    }

    test('classifies window breakpoints', () {
      expect(metricsFor(390).windowClass, KeroseneWindowClass.compact);
      expect(metricsFor(800).windowClass, KeroseneWindowClass.medium);
      expect(metricsFor(1100).windowClass, KeroseneWindowClass.expanded);
      expect(metricsFor(1440).windowClass, KeroseneWindowClass.wide);
    });

    test('app column fills the window on desktop sizes', () {
      // Phone: full width of device.
      expect(metricsFor(390).appColumnMaxWidth, 390);

      // Tablet / small laptop: still fill — no fixed phone column.
      expect(metricsFor(800).appColumnMaxWidth, 800);
      expect(metricsFor(1100).appColumnMaxWidth, 1100);

      // Typical Linux window (1280): fill entirely.
      expect(metricsFor(1280).appColumnMaxWidth, 1280);

      // 1440p desktop: fill.
      expect(metricsFor(1440).appColumnMaxWidth, 1440);

      // Ultrawide soft cap only above 1920.
      expect(metricsFor(2560).appColumnMaxWidth, 1920);
    });

    test('useWideHomeLayout is true from expanded upwards', () {
      expect(metricsFor(390).useWideHomeLayout, isFalse);
      expect(metricsFor(800).useWideHomeLayout, isFalse);
      expect(metricsFor(1100).useWideHomeLayout, isTrue);
      expect(metricsFor(1440).useWideHomeLayout, isTrue);
    });

    test('forms stay narrower than the app column on wide windows', () {
      final wide = metricsFor(1440);
      expect(wide.formMaxWidth, lessThan(wide.appColumnMaxWidth));
      expect(wide.formMaxWidth, 600);
    });
  });

  group('KeroseneAppColumn', () {
    testWidgets('forces child to consume available width up to the cap', (
      tester,
    ) async {
      double? childWidth;

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: KeroseneResponsiveBoundary(
              child: KeroseneAppColumn(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    childWidth = constraints.maxWidth;
                    return const SizedBox(height: 1);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(childWidth, 1280);
    });
  });
}
