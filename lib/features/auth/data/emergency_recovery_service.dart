import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_transport.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/security/device_credential_enroll_policy.dart';
import 'package:kerosene/core/logging/app_log.dart';
import 'package:kerosene/features/auth/domain/emergency_recovery_models.dart';

abstract class EmergencyRecoveryService {
  Future<EmergencyRecoveryStartResult> start(
    EmergencyRecoveryStartDraft draft,
  );

  Future<EmergencyRecoveryFinishResult> finish({
    required String username,
    required EmergencyRecoveryStartResult started,
    required String totpCode,
  });
}

/// Completion may have rotated credentials even when its reply cannot be read.
class EmergencyRecoveryResultUnknownException extends AppException {
  const EmergencyRecoveryResultUnknownException()
      : super(
            message: 'Recovery completion could not be confirmed.',
            errorCode: 'ERR_RECOVERY_RESULT_UNKNOWN');
}

/// Challenge preparation does not consume completion authority. Expiry or budget exhaustion closes this attempt.
class EmergencyRecoveryPreparationException extends AppException {
  final bool sessionClosed;
  EmergencyRecoveryPreparationException(AppException? cause)
      : sessionClosed = cause?.statusCode == 410 || cause?.statusCode == 429,
        super(
            message: 'Recovery enrollment preparation failed.',
            errorCode: 'ERR_RECOVERY_DEVICE_KEY_PREPARATION',
            statusCode: cause?.statusCode);
}

class RemoteEmergencyRecoveryService implements EmergencyRecoveryService {
  final ApiTransport _api;
  final PasskeyService _passkeyService;
  final DeviceKeyService _deviceKeyService;
  final Future<bool> Function() _preferCanonical;

  RemoteEmergencyRecoveryService(
    this._api, {
    PasskeyService? passkeyService,
    DeviceKeyService? deviceKeyService,
    Future<bool> Function()? preferCanonical,
  })  : _passkeyService = passkeyService ?? PasskeyService.instance,
        _deviceKeyService = deviceKeyService ?? DeviceKeyService.instance,
        _preferCanonical = preferCanonical ??
            (() =>
                DeviceCredentialEnrollPolicy.preferCanonicalDeviceKeyEnroll());

  @override
  Future<EmergencyRecoveryStartResult> start(
    EmergencyRecoveryStartDraft draft,
  ) async {
    final challenge = await _powChallenge();
    final nonce = await compute(_solveEmergencyRecoveryPow, challenge);
    final response = await _api.post(
      AppConfig.authEmergencyRecoveryStart,
      data: {
        'username': draft.username.trim().toLowerCase(),
        'newPassphrase': draft.newPassphrase,
        'recoveryCodes': draft.recoveryCodes
            .map((code) => code.trim())
            .where((code) => code.isNotEmpty)
            .toList(growable: false),
        'challenge': challenge,
        'nonce': nonce,
      },
    );
    final result = EmergencyRecoveryStartResult.fromJson(
      _requireMap(response.data, 'start'),
    );
    if (response.statusCode != 202 || !result.isUsable) {
      throw const ServerException(
        message: 'A sessão de recuperação voltou incompleta.',
        errorCode: 'ERR_RECOVERY_START_INVALID_RESPONSE',
      );
    }
    return result;
  }

  @override
  Future<EmergencyRecoveryFinishResult> finish({
    required String username,
    required EmergencyRecoveryStartResult started,
    required String totpCode,
  }) async {
    final canonical = await _preferCanonical();
    final body = <String, dynamic>{
      'recoverySessionId': started.recoverySessionId,
      'totpCode': totpCode.trim()
    };
    Map<String, dynamic>? canonicalCredential;
    if (canonical) {
      if (!started.deviceKeyRecoverySupported) {
        throw const AppException(
            message: 'Canonical recovery is unavailable on this server.',
            errorCode: 'ERR_RECOVERY_DEVICE_KEY_UNSUPPORTED');
      }
      late final DeviceKeyChallenge challenge;
      try {
        final response = await _api
            .post(AppConfig.authEmergencyRecoveryDeviceKeyChallenge, data: {
          'recoverySessionId': started.recoverySessionId,
          'totpCode': totpCode.trim()
        });
        if (response.statusCode != 200)
          throw const FormatException('Invalid challenge reply.');
        challenge = DeviceKeyChallenge.fromJson(
            _requireMap(response.data, 'device_key_challenge'));
      } catch (error) {
        throw EmergencyRecoveryPreparationException(
            error is AppException ? error : null);
      }
      canonicalCredential = await _deviceKeyService.register(
          challenge: challenge,
          username: username.trim().toLowerCase(),
          sessionId: started.recoverySessionId,
          activateImmediately: false,
          requireStrictUserPresence: true);
      body['deviceKeyRegistration'] = {
        ...canonicalCredential,
        'confirmUnlinkDevice': false
      };
    } else {
      final credential = await _passkeyService.register(
          challengeHex: started.passkeyChallenge,
          username: username.trim().toLowerCase());
      body.addAll({...credential, 'confirmUnlinkDevice': false});
    }
    try {
      final response = await _api.post(
        AppConfig.authEmergencyRecoveryFinish,
        data: body,
      );
      final result = EmergencyRecoveryFinishResult.fromJson(
        _requireMap(response.data, 'finish'),
      );
      if (response.statusCode != 200 ||
          !result.isUsable ||
          result.username != username.trim().toLowerCase()) {
        throw const EmergencyRecoveryResultUnknownException();
      }
      if (canonicalCredential != null) {
        final id = canonicalCredential['credentialId'];
        if (id is! String || id.isEmpty || result.deviceKeyCredentialId != id) {
          throw const EmergencyRecoveryResultUnknownException();
        }
        try {
          await _deviceKeyService.activateRegistration(
              username: result.username, credentialId: id);
        } catch (_) {
          appLog('Recovery completed; local device-key activation failed.');
          return EmergencyRecoveryFinishResult(
              username: result.username,
              newBackupCodes: result.newBackupCodes,
              deviceKeyCredentialId: id,
              localDeviceKeyReady: false);
        }
      }
      return result;
    } on AppException catch (error) {
      if (error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        rethrow;
      }
      throw const EmergencyRecoveryResultUnknownException();
    } catch (_) {
      throw const EmergencyRecoveryResultUnknownException();
    }
  }

  Future<String> _powChallenge() async {
    final response = await _api.get(AppConfig.authPowChallenge);
    final body = response.data;
    if (body is Map) {
      final challenge = body['challenge']?.toString().trim();
      if (challenge != null && challenge.isNotEmpty) {
        return challenge;
      }
    }
    throw const ServerException(
      message: 'Não conseguimos preparar a proteção da recuperação.',
      errorCode: 'ERR_RECOVERY_POW_CHALLENGE_INVALID_RESPONSE',
    );
  }

  static Map<String, dynamic> _requireMap(Object? data, String operation) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerException(
      message: 'Resposta inesperada do backend de recuperação.',
      errorCode: 'ERR_RECOVERY_${operation.toUpperCase()}_INVALID_RESPONSE',
    );
  }
}

String _solveEmergencyRecoveryPow(String challenge) {
  var nonce = 0;
  const prefix = '0000';
  while (nonce <= 10000000) {
    final digest = crypto.sha256.convert(utf8.encode('$challenge$nonce'));
    if (digest.toString().startsWith(prefix)) {
      return nonce.toString();
    }
    nonce++;
  }
  return nonce.toString();
}
