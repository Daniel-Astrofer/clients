import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

/// User privacy preferences for financial surfaces.
class PrivacyPreferencesState {
  /// When true, blocks screenshots / recents on Android for financial screens.
  final bool blockFinancialScreenshots;
  final bool loading;
  final bool readFailed;

  const PrivacyPreferencesState({
    this.blockFinancialScreenshots = false,
    this.loading = false,
    this.readFailed = false,
  });
  PrivacyPreferencesState copyWith(
          {bool? blockFinancialScreenshots, bool? loading, bool? readFailed}) =>
      PrivacyPreferencesState(
          blockFinancialScreenshots:
              blockFinancialScreenshots ?? this.blockFinancialScreenshots,
          loading: loading ?? this.loading,
          readFailed: readFailed ?? this.readFailed);
}

class PrivacyPreferencesNotifier extends Notifier<PrivacyPreferencesState> {
  static const String blockScreenshotsKey =
      'privacy_block_financial_screenshots';
  SharedPreferences? _preferences;
  Future<void>? _hydration;
  Future<void> _writes = Future<void>.value();

  @override
  PrivacyPreferencesState build() {
    try {
      // Bootstrap supplies this before financial surfaces mount: protection is
      // known on the first frame, rather than overwritten by an async default.
      _preferences = ref.read(sharedPreferencesProvider);
      return _fromPreferences(_preferences!);
    } catch (error) {
      final missingBootstrap = error is UnimplementedError ||
          (error is ProviderException && error.exception is UnimplementedError);
      if (!missingBootstrap) rethrow;
      // Retain the standalone-host contract used by isolated financial screens.
      _hydration = Future.microtask(_loadStandalone);
      return const PrivacyPreferencesState(loading: true);
    }
  }

  PrivacyPreferencesState _fromPreferences(SharedPreferences prefs) =>
      PrivacyPreferencesState(
        blockFinancialScreenshots: prefs.getBool(blockScreenshotsKey) ?? false,
      );

  Future<void> _loadStandalone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      _preferences = prefs;
      state = _fromPreferences(prefs);
    } catch (_) {
      if (ref.mounted) state = const PrivacyPreferencesState(readFailed: true);
    }
  }

  Future<void> reload() {
    if (state.loading) return _hydration ?? Future<void>.value();
    state = state.copyWith(loading: true, readFailed: false);
    return _hydration = _readAgain();
  }

  Future<void> _readAgain() async {
    try {
      await _writes;
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      await prefs.reload();
      if (!ref.mounted) return;
      _preferences = prefs;
      state = _fromPreferences(prefs);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loading: false, readFailed: true);
    }
  }

  Future<void> setBlockFinancialScreenshots(bool enabled) {
    final hydration = _hydration;
    final operation = _writes.then((_) async {
      await hydration;
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      _preferences = prefs;
      try {
        if (!await prefs.setBool(blockScreenshotsKey, enabled)) {
          throw StateError('Privacy preference was not saved.');
        }
      } catch (_) {
        // The legacy plugin updates its cache even when the platform rejects
        // the write. Restore that cache before allowing a new attempt.
        await prefs.reload();
        rethrow;
      }
      if (ref.mounted) {
        state = PrivacyPreferencesState(
            blockFinancialScreenshots: enabled, loading: state.loading);
      }
    });
    // Only the bookkeeping tail recovers; the caller receives every save error.
    _writes =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}

final privacyPreferencesProvider =
    NotifierProvider<PrivacyPreferencesNotifier, PrivacyPreferencesState>(
  PrivacyPreferencesNotifier.new,
);
