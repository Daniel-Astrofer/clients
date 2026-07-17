import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Namespace for secure storage / device-key / local identity material.
///
/// Resolution order:
/// 1. Process environment `KERO_SECURE_PREFIX` (Linux dual-profile scripts)
/// 2. Compile-time `--dart-define=KERO_SECURE_PREFIX=...`
///
/// Linux scripts **must** set distinct env values:
/// - primary  → `primary_`
/// - secondary → `secondary_`
///
/// Never leave this empty when running two desktop instances on one machine.
String keroseneSecurePrefix() {
  if (!kIsWeb) {
    try {
      final fromEnv = Platform.environment['KERO_SECURE_PREFIX']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv.endsWith('_') ? fromEnv : '${fromEnv}_';
      }
    } catch (_) {
      // Platform.environment unavailable on some embeds — fall through.
    }
  }
  final compiled = const String.fromEnvironment('KERO_SECURE_PREFIX').trim();
  if (compiled.isEmpty) return '';
  return compiled.endsWith('_') ? compiled : '${compiled}_';
}

/// Human profile label (`primary` / `secondary`) for logs and device name.
String keroseneProfileLabel() {
  if (!kIsWeb) {
    try {
      final fromEnv = Platform.environment['KERO_PROFILE']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    } catch (_) {}
  }
  final prefix = keroseneSecurePrefix();
  if (prefix.startsWith('secondary')) return 'secondary';
  if (prefix.startsWith('primary')) return 'primary';
  if (prefix.isEmpty) return 'default';
  return prefix.replaceAll(RegExp(r'_+$'), '');
}

/// Safe token for prefs keys / device-id salt (alnum + underscore).
String keroseneProfileTag() {
  final raw = keroseneSecurePrefix().isNotEmpty
      ? keroseneSecurePrefix()
      : keroseneProfileLabel();
  final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  if (cleaned.isEmpty) return 'default';
  return cleaned;
}
