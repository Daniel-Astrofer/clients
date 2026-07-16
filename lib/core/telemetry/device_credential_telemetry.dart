import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/device_credential_capabilities.dart';

/// Best-effort hardware protection signal (fail-open: never blocks money paths).
enum HardwareBackedStatus {
  /// StrongBox / SE / first-class mobile-desktop expected path.
  likely,

  /// Explicitly soft storage (e.g. Linux keyring without TEE).
  unlikely,

  /// Cannot determine (Windows Hello/TPM gray area, probe failure).
  unknown,
}

/// Local counters for Device Credential health (no PII, no credential material).
///
/// Beta fail-open: metrics only. Values live in SharedPreferences.
class DeviceCredentialTelemetry {
  DeviceCredentialTelemetry._();

  static const _prefix = 'device_cred_telem_v1';

  static Future<void> recordEnroll({
    required String kind,
    required DeviceCredentialCapabilities capabilities,
    HardwareBackedStatus? hardwareBacked,
  }) async {
    final hw = hardwareBacked ?? estimateHardwareBacked(capabilities);
    await _inc('enroll_total');
    await _inc('enroll_${_sanitize(kind)}');
    await _inc('enroll_hw_${hw.name}');
    await _inc('enroll_tier_${capabilities.tier.name}');
    _debug(
      'enroll kind=$kind tier=${capabilities.tier.name} hardwareBacked=${hw.name}',
    );
  }

  static Future<void> recordEnrollBlocked({
    required String code,
    required DeviceCredentialCapabilities capabilities,
  }) async {
    await _inc('enroll_blocked_total');
    await _inc('enroll_blocked_${_sanitize(code)}');
    _debug(
      'enroll_blocked code=$code tier=${capabilities.tier.name} platform=${capabilities.platformId}',
    );
  }

  static Future<void> recordAssertion({
    required String kind,
    required String outcome,
    HardwareBackedStatus? hardwareBacked,
    DeviceCredentialCapabilities? capabilities,
  }) async {
    final hw = hardwareBacked ??
        (capabilities != null
            ? estimateHardwareBacked(capabilities)
            : HardwareBackedStatus.unknown);
    await _inc('assert_total');
    await _inc('assert_${_sanitize(kind)}');
    await _inc('assert_outcome_${_sanitize(outcome)}');
    await _inc('assert_hw_${hw.name}');
    _debug(
      'assertion kind=$kind outcome=$outcome hardwareBacked=${hw.name}',
    );
  }

  static Future<void> recordStepUp({
    required String kind,
    required bool success,
  }) async {
    await recordAssertion(
      kind: kind,
      outcome: success ? 'success' : 'failure',
    );
  }

  /// Fail-open estimate from capabilities (no Keystore JNI probe required).
  static HardwareBackedStatus estimateHardwareBacked(
    DeviceCredentialCapabilities capabilities,
  ) {
    if (!capabilities.canStoreDeviceKey) {
      return HardwareBackedStatus.unknown;
    }
    switch (capabilities.tier) {
      case DeviceCredentialTier.a:
        return capabilities.hardwareBackedLikely
            ? HardwareBackedStatus.likely
            : HardwareBackedStatus.unknown;
      case DeviceCredentialTier.b:
        return HardwareBackedStatus.unknown;
      case DeviceCredentialTier.c:
        return HardwareBackedStatus.unlikely;
      case DeviceCredentialTier.unsupported:
        return HardwareBackedStatus.unknown;
    }
  }

  static Future<Map<String, int>> snapshotCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final out = <String, int>{};
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('$_prefix:')) continue;
        final value = prefs.getInt(key);
        if (value != null) {
          out[key.substring(_prefix.length + 1)] = value;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<void> _inc(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final full = '$_prefix:$key';
      final next = (prefs.getInt(full) ?? 0) + 1;
      await prefs.setInt(full, next);
      await prefs.setInt(
        '$_prefix:last_event_ms',
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeviceCredentialTelemetry: $e');
      }
    }
  }

  static String _sanitize(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
  }

  static void _debug(String message) {
    if (kDebugMode) {
      debugPrint('DeviceCredentialTelemetry: $message');
    }
  }
}
