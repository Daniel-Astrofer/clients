import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret navigation checkpoints. These never grant authentication or PIN access.
abstract final class FirstAccessProgress {
  static String _key(String userId) => 'first_access.v1.$userId';

  static Future<void> markPending(SharedPreferences prefs, String userId) =>
      _write(prefs, userId, 'choose');

  static bool shouldShow(SharedPreferences prefs, String userId,
      {required bool hasWallets}) {
    final stage = prefs.getString(_key(userId));
    if (stage == 'complete') return false;
    if (stage == 'choose' || stage == 'creating' || stage == 'ready') {
      return true;
    }
    // Preserve the choice made by previous app versions.
    if (prefs.getBool('home.wallet_setup_redirect_seen.$userId') == true) {
      return false;
    }
    return !hasWallets;
  }

  static bool hasCheckpoint(SharedPreferences prefs, String userId) => const [
        'choose',
        'creating',
        'ready'
      ].contains(prefs.getString(_key(userId)));

  static bool isPendingCreation(SharedPreferences prefs, String userId) =>
      prefs.getString(_key(userId)) == 'creating';

  static Future<void> creating(SharedPreferences prefs, String userId) =>
      _write(prefs, userId, 'creating');

  static bool isReady(SharedPreferences prefs, String userId) =>
      prefs.getString(_key(userId)) == 'ready';

  static Future<void> ready(SharedPreferences prefs, String userId) =>
      _write(prefs, userId, 'ready');

  static Future<void> complete(SharedPreferences prefs, String userId) =>
      _write(prefs, userId, 'complete');

  static Future<void> _write(
      SharedPreferences prefs, String userId, String stage) async {
    if (userId.trim().isEmpty) throw StateError('Missing first-access owner.');
    if (!await prefs.setString(_key(userId), stage)) {
      throw StateError('First-access checkpoint was not saved.');
    }
  }
}
