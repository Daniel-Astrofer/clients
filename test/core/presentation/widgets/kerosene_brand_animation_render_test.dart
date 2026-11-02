import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

Future<int> _visiblePixels(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = bytes!.buffer.asUint8List();
      var visible = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > 100 &&
            pixels[i + 1] > 100 &&
            pixels[i + 2] > 100 &&
            pixels[i + 3] > 100) {
          visible++;
        }
      }
      return visible;
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final asset in [
    'assets/logo/kerosene-k-logo.json',
    'assets/logo/kerosene-logo-white.json',
  ]) {
    testWidgets('$asset actually paints the brand', (tester) async {
      final composition =
          await tester.runAsync(() => AssetLottie(asset).load());
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
          key: key,
          child: SizedBox(
              width: 240,
              height: 240,
              child: Lottie(
                composition: composition,
                animate: false,
                controller: const AlwaysStoppedAnimation(0.6),
              )),
        )),
      ));
      await tester.pump();
      expect(await _visiblePixels(tester, key), greaterThan(500),
          reason: 'A parsed composition without warnings can still be blank.');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
