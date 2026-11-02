import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/presentation/state/auth_state.dart';
import 'package:kerosene/features/auth/data/emergency_recovery_service.dart';

/// Clock used only for the UI deadline; the server's one-time TTL remains authoritative.
final emergencyRecoveryClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Ends the old app session after the user has retained the one-time recovery result.
final emergencyRecoverySessionExitProvider =
    Provider<Future<bool> Function()>((ref) => () async {
          await ref.read(authControllerProvider.notifier).logout();
          return ref.mounted &&
              ref.read(authControllerProvider) is AuthUnauthenticated;
        });

final emergencyRecoveryServiceProvider =
    Provider<EmergencyRecoveryService>((ref) {
  return RemoteEmergencyRecoveryService(ref.watch(authApiClientProvider));
});
