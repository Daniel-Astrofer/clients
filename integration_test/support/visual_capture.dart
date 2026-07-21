import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

/// Where native visual E2E PNGs land (repo-relative when CWD is frontend/).
const visualE2eArtifactDir = 'artifacts/visual_e2e';

Directory resolveArtifactDir() {
  final fromEnv = Platform.environment['VISUAL_E2E_OUT'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    return Directory(fromEnv.trim());
  }
  // Prefer package root when running from nested build dirs.
  final cwd = Directory.current;
  final candidates = <Directory>[
    Directory(p.join(cwd.path, visualE2eArtifactDir)),
    Directory(p.join(cwd.path, 'frontend', visualE2eArtifactDir)),
  ];
  return candidates.first;
}

/// Captures the **native Flutter surface** (device/emulator/desktop engine),
/// not widget-test goldens. Saves PNG under [visualE2eArtifactDir].
///
/// This is the rendered app the user would see: real fonts, colors, theme,
/// and whatever data the live session loaded — not Storybook mocks.
Future<File> captureNativeScreen({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String name,
}) async {
  final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final outDir = resolveArtifactDir();
  await outDir.create(recursive: true);
  final file = File(p.join(outDir.path, '$safe.png'));

  // Settle one more frame so animations/skins finish before the shot.
  await tester.pump(const Duration(milliseconds: 200));

  Uint8List? pngBytes;

  // 1) Official integration_test surface capture (Android needs surface convert).
  try {
    await binding.convertFlutterSurfaceToImage();
    // Required on Android after convertFlutterSurfaceToImage.
    await tester.pump(const Duration(milliseconds: 100));
    final bytes = await binding.takeScreenshot(safe);
    if (bytes.isNotEmpty) {
      pngBytes = Uint8List.fromList(bytes);
    }
  } catch (e) {
    debugPrint('[visual-e2e] takeScreenshot failed ($safe): $e');
  }

  // 2) Fallback: rasterize the root [RepaintBoundary] / [RenderView].
  if (pngBytes == null || pngBytes.isEmpty) {
    pngBytes = await _rasterizeTester(tester);
  }

  if (pngBytes == null || pngBytes.isEmpty) {
    throw StateError('Failed to capture screenshot bytes for $safe');
  }

  await file.writeAsBytes(pngBytes, flush: true);
  debugPrint(
    '[visual-e2e] saved ${file.path} (${pngBytes.length} bytes)',
  );
  return file;
}

Future<Uint8List?> _rasterizeTester(WidgetTester tester) async {
  try {
    // Prefer an explicit capture boundary if the harness inserted one.
    final boundaryFinder =
        find.byKey(const ValueKey('visual_e2e_capture_root'));
    RenderRepaintBoundary? boundary;
    if (boundaryFinder.evaluate().isNotEmpty) {
      boundary = tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
    } else {
      final candidates = find.byType(RepaintBoundary);
      if (candidates.evaluate().isEmpty) return null;
      // Outermost usually first.
      boundary = tester.renderObject(candidates.first) as RenderRepaintBoundary;
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('[visual-e2e] rasterize fallback failed: $e');
    return null;
  }
}

/// Wait until [predicate] is true or [timeout] elapses.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 90),
  Duration step = const Duration(milliseconds: 400),
  String label = 'condition',
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (predicate()) return;
  }
  throw TimeoutException('Timed out waiting for $label after $timeout');
}
