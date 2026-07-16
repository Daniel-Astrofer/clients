import '../config/app_config.dart';
import 'device_credential_capabilities.dart';

/// Enroll + auth policy for Device Key vs WebAuthn-shaped legacy.
///
/// N+1: block new shaped enroll on tier A.  
/// N+2: block shaped auth on tier A (step-up / biometric login).
class DeviceCredentialEnrollPolicy {
  const DeviceCredentialEnrollPolicy._();

  static const reconfigureRequiredCode =
      'ERR_AUTH_DEVICE_KEY_RECONFIGURE_REQUIRED';
  static const reconfigureRequiredMessage =
      'Configure a Chave do dispositivo neste aparelho (Configurações → Dispositivos). '
      'O caminho legado de passkey não é mais usado no mobile.';

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

  /// Whether WEBAUTHN_SHAPED authentication is still allowed (login / step-up).
  ///
  /// N+2 default: false on tier A. Rollback: ALLOW_WEBAUTHN_SHAPED_AUTH=true.
  static Future<bool> allowWebAuthnShapedAuth({
    bool appPinConfigured = false,
  }) async {
    if (AppConfig.allowWebAuthnShapedAuth) {
      return true;
    }
    final caps = await DeviceCredentialCapabilitiesResolver.instance.resolve(
      appPinConfigured: appPinConfigured,
    );
    // Remove dual path on first-class mobile/desktop.
    if (caps.tier == DeviceCredentialTier.a) {
      return false;
    }
    // Tier B may keep shaped only if device-key is not preferred for enroll.
    if (caps.tier == DeviceCredentialTier.b) {
      return !await preferCanonicalDeviceKeyEnroll(
        appPinConfigured: appPinConfigured,
      );
    }
    return true;
  }

  static Future<bool> requireDeviceKeyForStepUp({
    bool appPinConfigured = false,
  }) async {
    return !await allowWebAuthnShapedAuth(appPinConfigured: appPinConfigured);
  }
}
