import '../config/app_config.dart';
import 'device_credential_capabilities.dart';

/// Release N+1 enroll policy: canonical DEVICE_KEY first; WebAuthn-shaped legacy.
class DeviceCredentialEnrollPolicy {
  const DeviceCredentialEnrollPolicy._();

  /// True when this runtime should enroll via Device Key (KEROSENE_JSON_V1).
  static Future<bool> preferCanonicalDeviceKeyEnroll({
    bool appPinConfigured = false,
  }) async {
    if (!AppConfig.preferCanonicalDeviceKeyEnroll) {
      return false;
    }
    final caps = await DeviceCredentialCapabilitiesResolver.instance.resolve(
      appPinConfigured: appPinConfigured,
    );
    if (!caps.canEnrollDeviceCredential) {
      return false;
    }
    // Mobile/desktop first-class (and Windows with Hello) enroll DEVICE_KEY.
    return caps.tier == DeviceCredentialTier.a ||
        caps.tier == DeviceCredentialTier.b;
  }

  /// Whether new WEBAUTHN_SHAPED enroll is still allowed.
  ///
  /// N+1 default: false on tier A when canonical enroll is preferred.
  /// Authentication with an already-enrolled sovereign key remains allowed.
  static Future<bool> allowWebAuthnShapedEnroll({
    bool appPinConfigured = false,
  }) async {
    if (AppConfig.allowWebAuthnShapedEnroll) {
      return true;
    }
    if (!AppConfig.preferCanonicalDeviceKeyEnroll) {
      return true;
    }
    final caps = await DeviceCredentialCapabilitiesResolver.instance.resolve(
      appPinConfigured: appPinConfigured,
    );
    // Block new shaped enroll on first-class platforms.
    if (caps.tier == DeviceCredentialTier.a) {
      return false;
    }
    // Tier B/C/web: shaped enroll only if device-key path is not preferred.
    return !await preferCanonicalDeviceKeyEnroll(
      appPinConfigured: appPinConfigured,
    );
  }
}
