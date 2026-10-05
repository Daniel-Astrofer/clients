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

/// Bumped when local PIN hints change so [appPinGateStatusProvider] rebuilds
/// (SharedPreferences writes alone do not notify Riverpod).
class AppPinLocalStateEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final appPinLocalStateEpochProvider =
    NotifierProvider<AppPinLocalStateEpochNotifier, int>(
  AppPinLocalStateEpochNotifier.new,
);

void bumpAppPinLocalState(WidgetRef ref) {
  ref.read(appPinLocalStateEpochProvider.notifier).bump();
}

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
///
/// Mode rules:
/// - `configured == true`  → single-entry unlock (verify)
/// - `configured == false` → create + confirm setup (only true first create)
/// - unknown (null hint)   → optimistic unlock (single verify). If the server
///   has no device PIN, verify returns AUTH_018 and the gate flips to setup.
///
/// Pin length:
/// - When we know the length (prefs after configure/verify), min==max so the
///   pad auto-submits at that length.
/// - When unknown, min=4 max=8 so the pad does **not** auto-submit at 4 and
///   force a second attempt for 5–8 digit PINs.
final appPinGateStatusProvider = Provider<AppPinStatus>((ref) {
  ref.watch(appPinLocalStateEpochProvider);
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthAuthenticated) {
    return const AppPinStatus();
  }

  final sessionScope = ref.watch(sessionStorageScopeProvider);
  final prefs = ref.read(sharedPreferencesProvider);

  if (sessionScope != null) {
    final configured = prefs.getBool(appPinConfiguredPrefsKey(sessionScope));
    final storedLen = prefs.getInt(appPinLengthPrefsKey(sessionScope));
    final knownLen = (storedLen != null && storedLen >= 4 && storedLen <= 8)
        ? storedLen
        : null;

    if (configured == false) {
      // Explicit local hint: this install has no PIN yet → setup (create+confirm).
      // New PINs use the platform minimum (4) for both steps.
      final setupLen = knownLen ?? 4;
      return AppPinStatus(
        enabled: false,
        configured: false,
        remainingAttempts: 5,
        maxAttempts: 5,
        minPinLength: setupLen,
        maxPinLength: setupLen,
      );
    }
    // configured == true **or** unknown (null): unlock pad (single verify).
    if (knownLen != null) {
      return AppPinStatus(
        enabled: true,
        configured: true,
        remainingAttempts: 5,
        maxAttempts: 5,
        minPinLength: knownLen,
        maxPinLength: knownLen,
      );
    }
    // Length unknown: flexible 4–8, submit via confirm (no wrong auto-submit).
    return const AppPinStatus(
      enabled: true,
      configured: true,
      remainingAttempts: 5,
      maxAttempts: 5,
      minPinLength: 4,
      maxPinLength: 8,
    );
  }

  // Session scope still resolving — unlock pad with flexible length.
  return const AppPinStatus(
    enabled: true,
    configured: true,
    remainingAttempts: 5,
    maxAttempts: 5,
    minPinLength: 4,
    maxPinLength: 8,
  );
});

/// After Tor settles, pull server PIN status so the gate can switch
/// setup ↔ unlock **before** the user types.
///
/// IMPORTANT for authenticated login (token restore):
/// - Must **not** be `watch`ed by the PIN pad (AsyncLoading→data rebuilds the
///   pad and can force a second PIN entry — matches logs: verify + GET status).
/// - Kick with `ref.read(...future)` once from the gate.
/// - Only bump epoch when setup↔lock **mode** actually flips. `null → true`
///   is not a mode change (unknown already shows unlock).
final appPinGateServerSyncProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthAuthenticated) return;
  if (!ref.watch(torSettledProvider)) return;
  if (ref.read(appEntryPinUnlockedProvider) || AppEntryPinSession.unlocked) {
    return;
  }
  if (AppEntryPinSession.pinRequestInFlight) return;

  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null || sessionScope.isEmpty) return;

  final repository = ref.read(securityRepositoryProvider);
  final result = await repository.getAppPinStatus();
  if (!ref.mounted) return;
  // User may have finished PIN while this request was in flight.
  if (ref.read(appEntryPinUnlockedProvider) || AppEntryPinSession.unlocked) {
    return;
  }
  if (AppEntryPinSession.pinRequestInFlight) return;

  result.fold(
    (_) {},
    (status) {
      final prefs = ref.read(sharedPreferencesProvider);
      final configured = status.configured && status.enabled;
      final prevConfigured =
          prefs.getBool(appPinConfiguredPrefsKey(sessionScope));

      // Only sync configured flag. NEVER write server minPinLength into the
      // local pin-length hint — that is the platform minimum (usually 4), not
      // the user's PIN size.
      // ignore: discarded_futures
      prefs.setBool(appPinConfiguredPrefsKey(sessionScope), configured);

      // Mode change only: explicit false ↔ not-false.
      // null (unknown) already presents as unlock — writing true must not bump.
      final wasSetup = prevConfigured == false;
      final nowSetup = !configured;
      if (wasSetup != nowSetup) {
        ref.read(appPinLocalStateEpochProvider.notifier).bump();
      }
    },
  );
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
          final configured = status.configured && status.enabled;
          final prevConfigured =
              prefs.getBool(appPinConfiguredPrefsKey(sessionScope));

          // Configured flag only — pin length is written solely after a
          // successful verify/configure with the digits the user entered.
          // ignore: discarded_futures
          prefs.setBool(
            appPinConfiguredPrefsKey(sessionScope),
            configured,
          );

          // Same rule as gate sync: only bump on real setup↔lock mode change.
          final wasSetup = prevConfigured == false;
          final nowSetup = !configured;
          if (wasSetup != nowSetup) {
            ref.read(appPinLocalStateEpochProvider.notifier).bump();
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

/// Process-lifetime unlock flag. Survives Riverpod notifier rebuilds that would
/// otherwise reset [appEntryPinUnlockedProvider] to `false` and re-show the pad
/// after a successful verify (double PIN within the same app process).
class AppEntryPinSession {
  AppEntryPinSession._();

  static bool unlocked = false;

  /// True while a verify/configure request is in flight — blocks server status
  /// sync from rewriting local hints and remounting the pad mid-entry.
  static bool pinRequestInFlight = false;

  static void markUnlocked() => unlocked = true;

  static void clear() {
    unlocked = false;
    pinRequestInFlight = false;
  }
}

/// When unlock verify hits AUTH_018 (no device PIN yet), the digits already
/// typed are kept here so setup only asks for **confirm** — not a full
/// create+confirm after the user already entered a PIN once.
///
/// Static (not a Riverpod provider) so setup can take the pin in
/// [State.didChangeDependencies] without modifying providers mid-build.
class AppPinSetupHandoff {
  AppPinSetupHandoff._();

  static String? _pin;

  static void offer(String pin) {
    final trimmed = pin.trim();
    if (trimmed.length >= 4 && trimmed.length <= 8) {
      _pin = trimmed;
    }
  }

  static String? take() {
    final value = _pin;
    _pin = null;
    return value;
  }

  static void clear() => _pin = null;
}

class AppEntryPinUnlockNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Keep unlock across incidental provider rebuilds during the same session.
    ref.keepAlive();
    // Do NOT watch auth in build() — every auth tick re-ran build() and reset
    // unlock to false, which re-showed the PIN pad after the user already passed.
    //
    // Unlock is sticky until **real sign-out** or a real account switch.
    // AuthLoading / AuthError / server blips must NOT re-ask the entry PIN.
    // Also restore from [AppEntryPinSession] if the notifier is recreated.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        if (previous is AuthAuthenticated) {
          final prevId = previous.user.id.trim();
          final nextId = next.user.id.trim();
          // Ignore empty/placeholder ids that resolve after the first profile fetch.
          if (prevId.isNotEmpty &&
              nextId.isNotEmpty &&
              prevId != '0' &&
              nextId != '0' &&
              prevId != nextId) {
            AppEntryPinSession.clear();
            AppPinSetupHandoff.clear();
            state = false;
          }
        }
        return;
      }

      // Only clear on explicit unauthenticated (logout / session invalidated).
      if (next is AuthUnauthenticated) {
        AppEntryPinSession.clear();
        AppPinSetupHandoff.clear();
        state = false;
      }
      // AuthLoading, AuthServerUnavailable, AuthError, TOTP steps, etc.: keep.
    });
    return AppEntryPinSession.unlocked;
  }

  void unlock() {
    AppEntryPinSession.markUnlocked();
    state = true;
  }

  void lock() {
    AppEntryPinSession.clear();
    state = false;
  }
}

final appEntryPinUnlockedProvider =
    NotifierProvider<AppEntryPinUnlockNotifier, bool>(
  AppEntryPinUnlockNotifier.new,
);
