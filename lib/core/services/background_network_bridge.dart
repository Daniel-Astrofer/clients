import 'package:flutter/foundation.dart' show debugPrint, immutable, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/providers/alert_preferences_provider.dart';

/// SharedPreferences bridge so the **background isolate** can reuse Tor SOCKS
/// routing and alert prefs written by the main isolate.
///
/// SharedPreferences is process-scoped on Android/iOS — both isolates read the
/// same keys when using the default prefs file.
abstract final class BackgroundNetworkBridge {
  static const socksHostKey = 'bg.network.socks_host';
  static const socksPortKey = 'bg.network.socks_port';
  static const apiBaseUrlKey = 'bg.network.api_base_url';
  static const torEnabledKey = 'bg.network.tor_enabled';
  static const lastNotificationIdKey = 'bg.notifications.last_id';
  static const seenNotificationIdsKey = 'bg.notifications.seen_ids';

  /// Call from the main isolate whenever Tor / API URL becomes ready.
  static Future<void> publishMainIsolateRouting({
    required String apiBaseUrl,
    required bool torEnabled,
    String socksHost = '127.0.0.1',
    int? socksPort,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(apiBaseUrlKey, apiBaseUrl);
      await prefs.setBool(torEnabledKey, torEnabled);
      await prefs.setString(socksHostKey, socksHost);
      if (socksPort != null && socksPort > 0) {
        await prefs.setInt(socksPortKey, socksPort);
      }
      if (kDebugMode) {
        debugPrint(
          'BackgroundNetworkBridge: published api=$apiBaseUrl '
          'tor=$torEnabled socks=$socksHost:${socksPort ?? '-'}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackgroundNetworkBridge: publish failed: $e');
      }
    }
  }

  static Future<BackgroundRoutingSnapshot> readRouting() async {
    final prefs = await SharedPreferences.getInstance();
    final api = prefs.getString(apiBaseUrlKey)?.trim();
    return BackgroundRoutingSnapshot(
      apiBaseUrl: (api != null && api.isNotEmpty) ? api : AppConfig.apiUrl,
      torEnabled: prefs.getBool(torEnabledKey) ?? AppConfig.isTorEnabled,
      socksHost: prefs.getString(socksHostKey) ?? '127.0.0.1',
      socksPort: prefs.getInt(socksPortKey),
    );
  }

  static Future<BackgroundAlertPrefs> readAlertPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return BackgroundAlertPrefs(
      transactionAlertsEnabled:
          prefs.getBool(AlertPreferencesNotifier.transactionAlertsKey) ?? true,
      securityAlertsEnabled:
          prefs.getBool(AlertPreferencesNotifier.securityAlertsKey) ?? true,
      marketAlertsEnabled:
          prefs.getBool(AlertPreferencesNotifier.marketAlertsKey) ?? false,
    );
  }

  static Future<void> rememberSeenIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(seenNotificationIdsKey) ?? const [];
      final merged = <String>{...existing, ...ids}.toList();
      // Cap durable set.
      final kept = merged.length > 400
          ? merged.sublist(merged.length - 400)
          : merged;
      await prefs.setStringList(seenNotificationIdsKey, kept);
      final numeric = kept
          .map(int.tryParse)
          .whereType<int>()
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (numeric > 0) {
        await prefs.setInt(lastNotificationIdKey, numeric);
      }
    } catch (_) {}
  }

  static Future<Set<String>> loadSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(seenNotificationIdsKey) ?? const [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }
}

@immutable
class BackgroundRoutingSnapshot {
  final String apiBaseUrl;
  final bool torEnabled;
  final String socksHost;
  final int? socksPort;

  const BackgroundRoutingSnapshot({
    required this.apiBaseUrl,
    required this.torEnabled,
    required this.socksHost,
    required this.socksPort,
  });

  bool get hasSocks =>
      socksPort != null && socksPort! > 0 && socksHost.isNotEmpty;

  bool get isOnionApi {
    final host = Uri.tryParse(apiBaseUrl)?.host.toLowerCase() ?? '';
    return host.endsWith('.onion');
  }

  /// True when the isolate should tunnel HTTP via SOCKS5.
  ///
  /// Prefer the main-isolate **local Tor relay** (`127.0.0.1`) with direct HTTP.
  /// SOCKS is only required when the API base itself is a `.onion` URL.
  bool get shouldUseSocks => hasSocks && isOnionApi;
}

@immutable
class BackgroundAlertPrefs {
  final bool transactionAlertsEnabled;
  final bool securityAlertsEnabled;
  final bool marketAlertsEnabled;

  const BackgroundAlertPrefs({
    required this.transactionAlertsEnabled,
    required this.securityAlertsEnabled,
    required this.marketAlertsEnabled,
  });

  bool allowsKind(String kind) {
    final k = kind.trim().toLowerCase();
    if (k.contains('security')) return securityAlertsEnabled;
    if (k.contains('market')) return marketAlertsEnabled;
    // Financial default
    if (k.contains('deposit') ||
        k.contains('transfer') ||
        k.contains('payment') ||
        k.contains('outbound') ||
        k.contains('inbound') ||
        k.contains('received') ||
        k.contains('sent')) {
      return transactionAlertsEnabled;
    }
    return true;
  }
}
