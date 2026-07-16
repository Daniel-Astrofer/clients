import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../config/app_config.dart';

/// Product tiers from Device Credential decisions (Flutter 2026 matrix).
enum DeviceCredentialTier {
  /// Android / iOS / macOS — first-class Device Key.
  a,

  /// Windows — Device Key with Hello / fallback.
  b,

  /// Linux — third-class; App PIN gate required; biometrics untrusted.
  c,

  /// Web / unknown — no Device Key enroll preference.
  unsupported,
}

/// Runtime capability snapshot for Device Key / sovereign local credentials.
///
/// Prefer this over raw `Platform.isAndroid` checks (locked product decision).
@immutable
class DeviceCredentialCapabilities {
  final DeviceCredentialTier tier;
  final String platformId;
  final bool canStoreDeviceKey;
  final bool canBiometricGate;
  final bool hardwareBackedLikely;
  final bool deviceKeyLoginPreferred;
  final bool requireAppPinWithDeviceKey;
  final bool canEnrollDeviceCredential;
  final String? enrollBlockReasonCode;
  final String? enrollBlockReasonMessage;

  const DeviceCredentialCapabilities({
    required this.tier,
    required this.platformId,
    required this.canStoreDeviceKey,
    required this.canBiometricGate,
    required this.hardwareBackedLikely,
    required this.deviceKeyLoginPreferred,
    required this.requireAppPinWithDeviceKey,
    required this.canEnrollDeviceCredential,
    this.enrollBlockReasonCode,
    this.enrollBlockReasonMessage,
  });

  bool get isFirstClass => tier == DeviceCredentialTier.a;
  bool get isSecondClass => tier == DeviceCredentialTier.b;
  bool get isThirdClass => tier == DeviceCredentialTier.c;

  Map<String, Object?> toTelemetry() => {
        'tier': tier.name,
        'platformId': platformId,
        'canStoreDeviceKey': canStoreDeviceKey,
        'canBiometricGate': canBiometricGate,
        'hardwareBackedLikely': hardwareBackedLikely,
        'deviceKeyLoginPreferred': deviceKeyLoginPreferred,
        'requireAppPinWithDeviceKey': requireAppPinWithDeviceKey,
        'canEnrollDeviceCredential': canEnrollDeviceCredential,
        'enrollBlockReasonCode': enrollBlockReasonCode,
      };
}

/// Resolves [DeviceCredentialCapabilities] from OS + local_auth probes.
class DeviceCredentialCapabilitiesResolver {
  DeviceCredentialCapabilitiesResolver({
    LocalAuthentication? localAuthentication,
    String? platformIdOverride,
    bool? preferDeviceKeyOnMobile,
    bool? deviceKeyLoginEnabled,
  })  : _localAuthentication = localAuthentication ?? LocalAuthentication(),
        _platformIdOverride = platformIdOverride,
        _preferDeviceKeyOnMobile = preferDeviceKeyOnMobile ?? true,
        _deviceKeyLoginEnabled = deviceKeyLoginEnabled ?? true;

  static final DeviceCredentialCapabilitiesResolver instance =
      DeviceCredentialCapabilitiesResolver(
    preferDeviceKeyOnMobile: AppConfig.preferDeviceKeyOnMobile,
    deviceKeyLoginEnabled: AppConfig.deviceKeyLoginEnabled,
  );

  final LocalAuthentication _localAuthentication;
  final String? _platformIdOverride;
  final bool _preferDeviceKeyOnMobile;
  final bool _deviceKeyLoginEnabled;

  /// Pure mapping for unit tests (no platform channels).
  static DeviceCredentialCapabilities fromProbes({
    required String platformId,
    required bool canCheckBiometrics,
    required bool isDeviceSupported,
    required bool biometricsEnrolled,
    bool appPinConfigured = false,
    bool preferDeviceKeyOnMobile = true,
    bool deviceKeyLoginEnabled = true,
  }) {
    final normalized = platformId.trim().toLowerCase();
    final tier = _tierFor(normalized);
    final canStore = _canStoreFor(normalized);
    final canBiometricGate =
        canCheckBiometrics || isDeviceSupported || biometricsEnrolled;
    final hardwareBackedLikely = switch (tier) {
      DeviceCredentialTier.a => true,
      DeviceCredentialTier.b => false, // TPM/Hello medium — not StrongBox-class
      DeviceCredentialTier.c => false,
      DeviceCredentialTier.unsupported => false,
    };
    final requireAppPin = tier == DeviceCredentialTier.c ||
        (tier == DeviceCredentialTier.b && !canBiometricGate);

    final loginPreferred = deviceKeyLoginEnabled &&
        switch (tier) {
          DeviceCredentialTier.a => preferDeviceKeyOnMobile,
          DeviceCredentialTier.b => canBiometricGate,
          DeviceCredentialTier.c => false,
          DeviceCredentialTier.unsupported => false,
        };

    String? blockCode;
    String? blockMessage;
    var canEnroll = canStore;

    if (!canStore) {
      canEnroll = false;
      blockCode = 'ERR_AUTH_DEVICE_KEY_STORAGE_UNAVAILABLE';
      blockMessage =
          'Este ambiente não suporta armazenamento seguro da chave do dispositivo.';
    } else if (requireAppPin && !canBiometricGate) {
      // Linux has no local_auth plugin. Gate is the **app entry PIN** already
      // unlocked for this session (or optional appPinConfigured hint).
      // Do not hard-block enroll — otherwise custodial transfers can never step-up.
      if (appPinConfigured ||
          tier == DeviceCredentialTier.c ||
          tier == DeviceCredentialTier.b) {
        canEnroll = true;
      } else {
        canEnroll = false;
        blockCode = 'ERR_AUTH_DEVICE_KEY_APP_PIN_REQUIRED';
        blockMessage =
            'Configure um PIN do aplicativo ou bloqueio de tela antes de ativar a chave deste dispositivo.';
      }
    } else if (!canBiometricGate && !appPinConfigured) {
      canEnroll = false;
      blockCode = 'ERR_AUTH_DEVICE_KEY_NO_LOCAL_CREDENTIALS';
      blockMessage =
          'Configure biometria ou bloqueio de tela para usar a chave deste dispositivo.';
    }

    return DeviceCredentialCapabilities(
      tier: tier,
      platformId: normalized,
      canStoreDeviceKey: canStore,
      canBiometricGate: canBiometricGate,
      hardwareBackedLikely: hardwareBackedLikely,
      deviceKeyLoginPreferred: loginPreferred,
      requireAppPinWithDeviceKey: requireAppPin,
      canEnrollDeviceCredential: canEnroll,
      enrollBlockReasonCode: canEnroll ? null : blockCode,
      enrollBlockReasonMessage: canEnroll ? null : blockMessage,
    );
  }

  Future<DeviceCredentialCapabilities> resolve({
    bool appPinConfigured = false,
  }) async {
    final platformId = _platformIdOverride ?? detectPlatformId();
    var canCheck = false;
    var supported = false;
    var enrolled = false;
    try {
      canCheck = await _localAuthentication.canCheckBiometrics;
      supported = await _localAuthentication.isDeviceSupported();
      if (canCheck) {
        enrolled = (await _localAuthentication.getAvailableBiometrics())
            .isNotEmpty;
      }
    } catch (error) {
      debugPrint(
        'DeviceCredentialCapabilities: local_auth probe failed: $error',
      );
    }

    final caps = fromProbes(
      platformId: platformId,
      canCheckBiometrics: canCheck,
      isDeviceSupported: supported,
      biometricsEnrolled: enrolled,
      appPinConfigured: appPinConfigured,
      preferDeviceKeyOnMobile: _preferDeviceKeyOnMobile,
      deviceKeyLoginEnabled: _deviceKeyLoginEnabled,
    );
    debugPrint(
      'DeviceCredentialCapabilities: ${caps.toTelemetry()}',
    );
    return caps;
  }

  /// Throws [DeviceCredentialCapabilityException] when enroll is not allowed.
  Future<DeviceCredentialCapabilities> assertCanEnroll({
    bool appPinConfigured = false,
  }) async {
    final caps = await resolve(appPinConfigured: appPinConfigured);
    if (!caps.canEnrollDeviceCredential) {
      throw DeviceCredentialCapabilityException(
        code: caps.enrollBlockReasonCode ??
            'ERR_AUTH_DEVICE_KEY_ENROLL_BLOCKED',
        message: caps.enrollBlockReasonMessage ??
            'Não é possível registrar a chave deste dispositivo neste ambiente.',
      );
    }
    return caps;
  }

  static String detectPlatformId() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static DeviceCredentialTier _tierFor(String platformId) {
    switch (platformId) {
      case 'android':
      case 'ios':
      case 'macos':
        return DeviceCredentialTier.a;
      case 'windows':
        return DeviceCredentialTier.b;
      case 'linux':
        return DeviceCredentialTier.c;
      default:
        return DeviceCredentialTier.unsupported;
    }
  }

  static bool _canStoreFor(String platformId) {
    switch (platformId) {
      case 'android':
      case 'ios':
      case 'macos':
      case 'windows':
      case 'linux':
        return true;
      default:
        return false;
    }
  }
}

class DeviceCredentialCapabilityException implements Exception {
  final String code;
  final String message;

  const DeviceCredentialCapabilityException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'DeviceCredentialCapabilityException($code): $message';
}
