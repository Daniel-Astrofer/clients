import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time override: `--dart-define=KERO_UNIFIED_SEND_V2=true`
/// Default **true** after PR6: cold uses the same send wizard as custodial.
const bool kUnifiedSendV2CompileDefault = bool.fromEnvironment(
  'KERO_UNIFIED_SEND_V2',
  defaultValue: true,
);

const String kUnifiedSendV2PrefsKey = 'feature.unified_send_v2';

/// Whether the unified send engine (PR6+) is enabled.
///
/// Resolution order:
/// 1. Explicit SharedPreferences key (runtime toggle / QA)
/// 2. Compile-time `KERO_UNIFIED_SEND_V2`
///
/// Default remains **off** until PR8 flips staging default.
final unifiedSendV2EnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs.containsKey(kUnifiedSendV2PrefsKey)) {
    return prefs.getBool(kUnifiedSendV2PrefsKey) ??
        kUnifiedSendV2CompileDefault;
  }
  return kUnifiedSendV2CompileDefault;
});

/// QA / debug helper to persist the flag.
Future<void> setUnifiedSendV2Enabled(
  SharedPreferences prefs, {
  required bool enabled,
}) {
  return prefs.setBool(kUnifiedSendV2PrefsKey, enabled);
}
