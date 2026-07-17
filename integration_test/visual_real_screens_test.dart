import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/visual_app_harness.dart';
import 'support/visual_capture.dart';

/// Native visual E2E: real app shell + real Tor session + real fonts/colors/data.
///
/// Run (from frontend/):
/// ```bash
/// bash tools/run-visual-e2e.sh
/// # or:
/// flutter test integration_test/visual_real_screens_test.dart \
///   -d linux \
///   --dart-define=RUN_VISUAL_E2E=true
/// ```
///
/// Optional env:
/// - VISUAL_E2E_USERNAME / VISUAL_E2E_PASSWORD / VISUAL_E2E_TOTP_SECRET
/// - VISUAL_E2E_OUT (output dir for PNGs)
///
/// Screenshots land in `artifacts/visual_e2e/*.png` — not widget goldens.
const _runVisualE2e = bool.fromEnvironment('RUN_VISUAL_E2E');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Visual E2E — native screens with real data', () {
    VisualAppHarness? harness;

    setUpAll(() async {
      if (!_runVisualE2e) return;
      harness = await VisualAppHarness.start();
    });

    tearDownAll(() {
      harness?.dispose();
    });

    testWidgets(
      'capture home, settings, activity, receive, accounts',
      (tester) async {
        if (!_runVisualE2e) {
          return;
        }
        final h = harness;
        expect(h, isNotNull, reason: 'VisualAppHarness failed to start');

        await h!.pump(tester);

        // Wait for authenticated shell (past K logo / PIN / welcome).
        await waitUntil(
          tester,
          looksLikeAuthenticatedShell,
          timeout: const Duration(seconds: 120),
          label: 'authenticated home shell with real UI',
        );

        // Extra settle so balances / feed / charts finish first paint.
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> shot(String name) async {
          final file = await captureNativeScreen(
            binding: binding,
            tester: tester,
            name: name,
          );
          expect(file.existsSync(), isTrue, reason: 'missing $name');
          expect(file.lengthSync(), greaterThan(8 * 1024),
              reason: '$name too small — likely empty/black frame');
          debugPrint('[visual-e2e] OK $name → ${file.path}');
        }

        await shot('01_home');

        // Named routes use the real production navigator + deferred screens.
        final routes = <String, String>{
          '02_settings': '/settings',
          '03_activity': '/activity',
          '04_receive': '/receive',
          '05_accounts': '/accounts',
        };

        for (final entry in routes.entries) {
          try {
            await h.goNamed(tester, entry.value);
            await tester.pump(const Duration(seconds: 2));
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 300));
            }
            await shot(entry.key);
          } catch (e, st) {
            debugPrint('[visual-e2e] route ${entry.value} failed: $e\n$st');
            // Still try a capture of whatever is on screen (error/loading).
            try {
              await shot('${entry.key}_partial');
            } catch (_) {}
            rethrow;
          }
        }

        final out = resolveArtifactDir();
        final pngs = out
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList();
        debugPrint(
          '[visual-e2e] wrote ${pngs.length} PNG(s) under ${out.path}',
        );
        expect(pngs, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 8)),
      // Enable with --dart-define=RUN_VISUAL_E2E=true (tools/run-visual-e2e.sh).
      skip: !_runVisualE2e,
    );
  });
}
