import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client_provider.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/utils/device_helper.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/security/domain/entities/app_pin_status.dart';

final appPinRecoveryServiceProvider = Provider<AppPinRecoveryService>((ref) {
  final auth = ref.read(authRepositoryProvider);
  final client = ref.read(apiClientProvider);
  return AppPinRecoveryService(
    challenge: (username) async {
      final result = await auth.deviceKeyLoginStart(username);
      return result.fold(
          (failure) => throw ServerException(
              message: failure.message,
              errorCode: failure.errorCode,
              statusCode: failure.statusCode),
          (value) => value);
    },
    sign: (challenge, username) => DeviceKeyService.instance.authenticate(
        challenge: DeviceKeyChallenge.fromJson(challenge),
        username: username,
        requireStrictUserPresence: true),
    recover: (body) async {
      final response = await client.post('${AppConfig.authAppPin}/recover',
          headers: {'X-Device-Hash': await DeviceHelper.getDeviceHash()},
          data: body);
      return Map<String, dynamic>.from(response.data as Map);
    },
  );
});

/// A one-use device assertion and account password authorize only this PIN replacement.
/// Callers must keep [isCurrent] bound to the original authenticated session.
class AppPinRecoveryService {
  const AppPinRecoveryService({
    required this.challenge,
    required this.sign,
    required this.recover,
  });

  final Future<Map<String, dynamic>> Function(String username) challenge;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>, String)
      sign;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) recover;

  Future<AppPinStatus> replace(
      {required String username,
      required String password,
      required String newPin,
      required bool Function() isCurrent}) async {
    if (!RegExp(r'^\d{4}$').hasMatch(newPin) || password.isEmpty) {
      throw const FormatException('Invalid recovery input.');
    }
    void ensureCurrent() {
      if (!isCurrent()) throw StateError('PIN recovery session changed.');
    }

    ensureCurrent();
    final request = await challenge(username);
    ensureCurrent();
    final assertion = await sign(request, username);
    ensureCurrent();
    final response = await recover({
      'password': password,
      'newPin': newPin,
      'deviceKey': assertion,
    });
    ensureCurrent();
    final status = AppPinStatus.fromJson(response);
    if (!status.configured ||
        !status.enabled ||
        status.locked ||
        status.minPinLength < 1 ||
        status.minPinLength > 4 ||
        status.maxPinLength < 4 ||
        status.maxPinLength < status.minPinLength) {
      throw const FormatException('Invalid PIN recovery response.');
    }
    return status;
  }
}
