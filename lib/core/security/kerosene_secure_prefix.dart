import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Namespace for secure storage / device-key material.
///
/// Resolution order:
/// 1. Process environment `KERO_SECURE_PREFIX` (Linux dual-profile scripts)
/// 2. Compile-time `--dart-define=KERO_SECURE_PREFIX=...`
///
/// Primary vs secondary Linux scripts set different env values so both can share
/// one `build/linux` tree without rebuilding with different defines (which used
/// to corrupt plugins: "file too short").
String keroseneSecurePrefix() {
  if (!kIsWeb) {
    try {
      final fromEnv = Platform.environment['KERO_SECURE_PREFIX']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    } catch (_) {
      // Platform.environment unavailable on some embeds — fall through.
    }
  }
  return const String.fromEnvironment('KERO_SECURE_PREFIX');
}
