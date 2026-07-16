import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User privacy preferences for financial surfaces.
class PrivacyPreferencesState {
  /// When true, blocks screenshots / recents on Android for extrato & detail.
  final bool blockFinancialScreenshots;

  const PrivacyPreferencesState({
    this.blockFinancialScreenshots = false,
  });

  PrivacyPreferencesState copyWith({bool? blockFinancialScreenshots}) {
    return PrivacyPreferencesState(
      blockFinancialScreenshots:
          blockFinancialScreenshots ?? this.blockFinancialScreenshots,
    );
  }
}

class PrivacyPreferencesNotifier extends Notifier<PrivacyPreferencesState> {
  static const String blockScreenshotsKey =
      'privacy_block_financial_screenshots';

  @override
  PrivacyPreferencesState build() {
    _load();
    return const PrivacyPreferencesState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      blockFinancialScreenshots: prefs.getBool(blockScreenshotsKey) ?? false,
    );
  }

  Future<void> setBlockFinancialScreenshots(bool enabled) async {
    state = state.copyWith(blockFinancialScreenshots: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(blockScreenshotsKey, enabled);
  }
}

final privacyPreferencesProvider =
    NotifierProvider<PrivacyPreferencesNotifier, PrivacyPreferencesState>(
  PrivacyPreferencesNotifier.new,
);
