import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/security/device_credential_enroll_policy.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/domain/entities/account_security_change_factors.dart';

final securityChangeAuthorizerProvider = Provider<SecurityChangeAuthorizer>(
  (ref) => SecurityChangeAuthorizer(ref),
);

/// Signs security changes with existing account credentials; never enrolls a key.
class SecurityChangeAuthorizer {
  final Ref ref;
  final DeviceKeyService deviceKey;
  final PasskeyService passkey;

  SecurityChangeAuthorizer(
    this.ref, {
    DeviceKeyService? deviceKey,
    PasskeyService? passkey,
  })  : deviceKey = deviceKey ?? DeviceKeyService.instance,
        passkey = passkey ?? PasskeyService.instance;

  void _checkOwner(String expectedScope) {
    if (!ref.mounted ||
        ref.read(sessionStorageScopeProvider) != expectedScope ||
        ref.read(authControllerProvider) is! AuthAuthenticated) {
      throw const ServerException(
          message: 'A sessão mudou. Abra esta tela novamente.',
          errorCode: 'ERR_AUTH_SESSION_REQUIRED');
    }
  }

  /// Returns one-use factors bound to the caller's session, without caching them.
  Future<AccountSecurityChangeFactors> authorize({
    required String expectedScope,
    required bool requiresPasskey,
    required AccountSecurityChangeFactors manualFactors,
  }) async {
    _checkOwner(expectedScope);
    if (!requiresPasskey) return manualFactors;
    final username =
        (ref.read(authControllerProvider) as AuthAuthenticated).user.username;
    final repository = ref.read(authRepositoryProvider);
    String assertion;
    final hasKey = await deviceKey.hasRegisteredDeviceKey(username);
    _checkOwner(expectedScope);
    if (hasKey) {
      final result = await repository.deviceKeyLoginStart(username);
      _checkOwner(expectedScope);
      final challenge = result.fold(
          (failure) => throw ServerException(
              message: failure.message,
              statusCode: failure.statusCode,
              errorCode: failure.errorCode,
              data: failure.data),
          DeviceKeyChallenge.fromJson);
      final proof = await deviceKey.authenticate(
          challenge: challenge, username: username);
      _checkOwner(expectedScope);
      assertion = jsonEncode({'type': 'DEVICE_KEY', ...proof});
    } else {
      if (await DeviceCredentialEnrollPolicy.requireDeviceKeyForStepUp()) {
        throw const ServerException(
            message: DeviceCredentialEnrollPolicy.reconfigureRequiredMessage,
            errorCode: DeviceCredentialEnrollPolicy.reconfigureRequiredCode);
      }
      _checkOwner(expectedScope);
      final result = await repository.passkeyLoginStart(username);
      _checkOwner(expectedScope);
      final challenge = result.fold(
          (failure) => throw ServerException(
              message: failure.message,
              statusCode: failure.statusCode,
              errorCode: failure.errorCode,
              data: failure.data),
          (value) => value);
      final credential = await passkey.authenticate(
          challengeHex: challenge, username: username);
      _checkOwner(expectedScope);
      // Reserve the monotonic counter before submission. Gaps are accepted by
      // Core; reusing the same counter after an unknown response is not.
      await passkey.commitAuthenticationCounter(credential);
      _checkOwner(expectedScope);
      assertion = jsonEncode(PasskeyService.toWirePayload(credential));
    }
    return AccountSecurityChangeFactors(
      totpCode: manualFactors.totpCode,
      confirmationPassphrase: manualFactors.confirmationPassphrase,
      passkeyAssertionJson: assertion,
    );
  }
}
