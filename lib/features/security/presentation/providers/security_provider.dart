import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import '../../domain/entities/app_pin_status.dart';
import '../../domain/entities/account_security_profile.dart';
import '../../domain/entities/admin_access.dart';
import '../../domain/entities/security_status.dart';
import '../../domain/entities/kfe_reserve_overview.dart';

export 'package:kerosene/features/security/application/providers/security_data_providers.dart';
import 'package:kerosene/features/security/application/providers/security_data_providers.dart';

/// Local hint so the PIN pad can open while Tor is still booting.
String appPinConfiguredPrefsKey(String sessionScope) =>
    'app_pin.configured.$sessionScope';

String appPinLengthPrefsKey(String sessionScope) =>
    'app_pin.length.$sessionScope';

/// Optimistic PIN status used only before the server answers over Tor.
/// Backend default is min 4 / max 8 (`security.app-pin.min-length:4`).
const AppPinStatus kOptimisticAppPinStatus = AppPinStatus(
  enabled: true,
  configured: true,
  remainingAttempts: 5,
  maxAttempts: 5,
  minPinLength: 4,
  maxPinLength: 4,
);

/// Gate-only status: **synchronous**, no Tor wait, no network.
///
/// This is what [AppEntryPinGate] must watch so the pad never flashes into
/// loading dots while the user is typing.
///
/// Digit count: use the length saved when the user configured the PIN;
/// otherwise default to **4** (server minimum), not 6.
final appPinGateStatusProvider = Provider<AppPinStatus>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthAuthenticated) {
    return const AppPinStatus();
  }

  final sessionScope = ref.watch(sessionStorageScopeProvider);
  final prefs = ref.read(sharedPreferencesProvider);

  if (sessionScope != null) {
    final configured = prefs.getBool(appPinConfiguredPrefsKey(sessionScope));
    final storedLen = prefs.getInt(appPinLengthPrefsKey(sessionScope));
    final pinLen = (storedLen ?? 4).clamp(4, 8);

    if (configured == false) {
      return AppPinStatus(
        enabled: false,
        configured: false,
        remainingAttempts: 5,
        maxAttempts: 5,
        minPinLength: pinLen,
        maxPinLength: pinLen,
      );
    }
    // configured == true or unknown (first launch after update): show unlock.
    return AppPinStatus(
      enabled: true,
      configured: true,
      remainingAttempts: 5,
      maxAttempts: 5,
      minPinLength: pinLen,
      maxPinLength: pinLen,
    );
  }

  // Session scope still resolving — still show unlock pad (never skip gate).
  return kOptimisticAppPinStatus;
});

final sovereigntyStatusProvider = FutureProvider<SecurityStatus>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getSovereigntyStatus();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (status) => status,
  );
});

final kfeReserveOverviewProvider =
    FutureProvider<KfeReserveOverview>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getKfeReserveOverview();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (overview) => overview,
  );
});

final auditStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getAuditStats();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (stats) => stats,
  );
});

final accountSecurityProfileProvider =
    FutureProvider<AccountSecurityProfile>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getAccountSecurityProfile();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (profile) => profile,
  );
});

/// Server PIN status for settings / post-unlock screens.
///
/// The entry gate must use [appPinGateStatusProvider] instead — this future
/// may wait on Tor and must not drive the unlock pad.
final appPinStatusProvider = FutureProvider<AppPinStatus>(
  (ref) async {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return const AppPinStatus();
    }

    final sessionScope = ref.watch(sessionStorageScopeProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final localConfigured = sessionScope != null &&
        (prefs.getBool(appPinConfiguredPrefsKey(sessionScope)) ?? false);

    // Never block the app shell: if Tor is cold, return local gate status.
    if (!ref.read(torSettledProvider)) {
      return ref.read(appPinGateStatusProvider);
    }

    final repository = ref.read(securityRepositoryProvider);
    final result = await repository.getAppPinStatus();
    return result.fold(
      (failure) {
        if (localConfigured) return ref.read(appPinGateStatusProvider);
        throw _AppPinStatusFailure(failure);
      },
      (status) {
        if (sessionScope != null) {
          // ignore: discarded_futures
          prefs.setBool(
            appPinConfiguredPrefsKey(sessionScope),
            status.configured && status.enabled,
          );
          if (status.minPinLength > 0) {
            // ignore: discarded_futures
            prefs.setInt(
              appPinLengthPrefsKey(sessionScope),
              status.minPinLength.clamp(4, 8),
            );
          }
        }
        return status;
      },
    );
  },
  retry: _retryAppPinStatus,
);

Duration? _retryAppPinStatus(int retryCount, Object error) {
  if (error is Error) {
    return null;
  }
  if (error is _AppPinStatusFailure) {
    final statusCode = error.failure.statusCode;
    if (statusCode != null && statusCode < 500) {
      return null;
    }
  }
  if (retryCount >= 3) {
    return null;
  }
  return KeroseneMotion.exponentialBackoff(retryCount);
}

class _AppPinStatusFailure implements Exception {
  final Failure failure;

  const _AppPinStatusFailure(this.failure);

  @override
  String toString() => failure.message;
}

final adminKeyStatusProvider =
    FutureProvider.autoDispose<AdminKeyStatus>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getAdminKeyStatus();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (status) => status,
  );
});

final pendingAdminAccessAttemptsProvider =
    FutureProvider.autoDispose<List<AdminAccessAttempt>>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getPendingAdminAttempts();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (attempts) => attempts,
  );
});

final adminAuthenticatedDevicesProvider =
    FutureProvider.autoDispose<List<AdminAuthenticatedDevice>>((ref) async {
  final repository = ref.watch(securityRepositoryProvider);
  final result = await repository.getAdminDevices();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (devices) => devices,
  );
});

class AppEntryPinUnlockNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Keep unlock across incidental provider rebuilds during the same session.
    ref.keepAlive();
    // Do NOT watch auth in build() — every auth tick re-ran build() and reset
    // unlock to false, which re-showed the PIN pad after the user already passed.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is! AuthAuthenticated) {
        state = false;
      }
    });
    return false;
  }

  void unlock() => state = true;

  void lock() => state = false;
}

final appEntryPinUnlockedProvider =
    NotifierProvider<AppEntryPinUnlockNotifier, bool>(
  AppEntryPinUnlockNotifier.new,
);
