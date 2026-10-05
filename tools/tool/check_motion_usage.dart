#!/usr/bin/env -S dart run
// ignore_for_file: avoid_print

/// Checks that feature code uses [KeroseneMotion] tokens instead of raw
/// [Duration(milliseconds:...)] and [Curves.*] literals.
///
/// Usage: dart run tool/check_motion_usage.dart [path]
///
/// Exits 0 if clean, 1 if violations found.
library;

import 'dart:io';

const _exemptFiles = {
  // These files DEFINE the tokens — they MUST use raw durations.
  'lib/core/motion/app_motion.dart',
  'lib/core/motion/motion_catalog.dart',
  // Shader/animation renderers are visual design, not token consumers.
  'lib/features/home/scene/renderer/',
  'lib/features/home/presentation/widgets/home_stage_atmosphere.dart',
  'lib/features/home/presentation/widgets/home_aurora_background.dart',
  'lib/design_system/foundation/theme/app_animations.dart',
};

const _exemptPatterns = [
  // Scene renderers and shader code
  'scene/',
  'shader',
  'aurora',
  'gemini_glow',
  // Debug and dev tools
  'debug/',
  'dev_menu',
  // Tests that specifically test motion
  'test/core/motion/',
];

final _rawDurationPattern = RegExp(
  r'Duration\s*\(\s*(milliseconds|seconds|microseconds)\s*:\s*\d+',
);

final _rawCurvePattern = RegExp(r'Curves\.\w+');

final _allowedCurves = {
  'Curves.linear',
  'Curves.easeOutCubic',
  'Curves.easeOutExpo',
  'Curves.easeOutQuart',
  'Curves.easeInCubic',
  'Curves.elasticOut', // KeroseneMotion.spring
  'Curves.easeOutBack', // KeroseneMotion.expressiveBack
};

bool _isExempt(String filePath) {
  for (final exempt in _exemptFiles) {
    if (filePath.startsWith(exempt) || filePath.contains(exempt)) return true;
  }
  for (final pattern in _exemptPatterns) {
    if (filePath.contains(pattern)) return true;
  }
  return false;
}

void main(List<String> args) {
  final target = args.isNotEmpty ? args.first : 'lib';
  final dir = Directory(target);
  if (!dir.existsSync()) {
    print('ERROR: Directory not found: $target');
    exit(1);
  }

  final violations = <String>[];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final relPath = file.path;
    if (_isExempt(relPath)) continue;

    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNo = i + 1;

      // Skip comments and strings (rough check)
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

      // Check for raw Duration(...)
      if (_rawDurationPattern.hasMatch(line)) {
        violations
            .add('$relPath:$lineNo: raw Duration — use KeroseneMotion token\n'
                '  $trimmed');
      }

      // Check for unexpected Curves.*
      final curveMatch = _rawCurvePattern.firstMatch(line);
      if (curveMatch != null) {
        final curve = curveMatch.group(0)!;
        if (!_allowedCurves.contains(curve) &&
            !line.contains('KeroseneMotion') &&
            !line.contains('import') &&
            !line.contains('app_motion')) {
          violations.add(
            '$relPath:$lineNo: unexpected curve $curve — use KeroseneMotion\n'
            '  $trimmed',
          );
        }
      }
    }
  }

  if (violations.isEmpty) {
    print('PASS: No raw motion tokens found outside exempt files.');
    exit(0);
  }

  print('FAIL: ${violations.length} motion token violations:\n');
  for (final v in violations) {
    print(v);
  }
  exit(1);
}
