import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'tor_service.dart';

typedef TorApiUrlUpdater = void Function(String url);

const _bootstrapFailureCooldown = Duration(seconds: 30);
Future<bool>? _bootstrapFuture;
DateTime? _lastBootstrapFailureAt;

@visibleForTesting
void resetTorBootstrapStateForTesting() {
  _bootstrapFuture = null;
  _lastBootstrapFailureAt = null;
}

@visibleForTesting
class TorBootstrapTarget {
  const TorBootstrapTarget({
    required this.requiresTor,
    required this.apiUrl,
    required this.targetHost,
    required this.targetPort,
  });

  final bool requiresTor;
  final String apiUrl;
  final String targetHost;
  final int targetPort;
}

@visibleForTesting
TorBootstrapTarget resolveTorBootstrapTarget(String rawUrl) {
  final apiUrl = rawUrl.trim();
  final uri = Uri.parse(apiUrl);
  final host = uri.host.toLowerCase();
  final targetPort = _resolveTargetPort(uri);

  return TorBootstrapTarget(
    requiresTor: host.endsWith('.onion'),
    apiUrl:
        apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl,
    targetHost: host,
    targetPort: targetPort,
  );
}

int _resolveTargetPort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }
  if (uri.scheme == 'https') {
    return 443;
  }
  return 80;
}

Future<bool> bootstrapTorNetwork({
  required TorService torService,
  required TorApiUrlUpdater updateApiUrl,
}) async {
  final inFlight = _bootstrapFuture;
  if (inFlight != null) {
    final bootstrapped = await inFlight;
    if (bootstrapped) {
      updateApiUrl(AppConfig.apiUrl);
    }
    return bootstrapped;
  }

  final lastFailureAt = _lastBootstrapFailureAt;
  if (lastFailureAt != null) {
    final elapsed = DateTime.now().difference(lastFailureAt);
    if (elapsed < _bootstrapFailureCooldown) {
      AppConfig.isTorEnabled = false;
      debugPrint(
        '🧅 Tor bootstrap skipped; previous failure was ${elapsed.inSeconds}s ago.',
      );
      return false;
    }
  }

  final future = _bootstrapTorNetworkInternal(
    torService: torService,
    updateApiUrl: updateApiUrl,
  );
  _bootstrapFuture = future;
  try {
    final bootstrapped = await future;
    if (bootstrapped) {
      _lastBootstrapFailureAt = null;
    } else {
      _lastBootstrapFailureAt = DateTime.now();
    }
    return bootstrapped;
  } finally {
    if (identical(_bootstrapFuture, future)) {
      _bootstrapFuture = null;
    }
  }
}

Future<bool> _bootstrapTorNetworkInternal({
  required TorService torService,
  required TorApiUrlUpdater updateApiUrl,
}) async {
  try {
    AppConfig.validateReleaseNodeConfiguration();

    final target = resolveTorBootstrapTarget(AppConfig.onionBaseUrl);

    if (!target.requiresTor) {
      AppConfig.isTorEnabled = false;
      debugPrint(
        '🧅 Refusing non-onion mobile API URL. Configure KERO_NODE_*_URL with a .onion address: ${target.apiUrl}',
      );
      return false;
    }

    debugPrint('🚀 Starting Tor Network Bootstrap...');
    final torStarted = await torService.start();

    if (!torStarted) {
      AppConfig.isTorEnabled = false;
      debugPrint('⚠️ Tor is UNAVAILABLE. Requests will remain blocked.');
      return false;
    }

    final relayPort =
        await torService.startRelay(target.targetHost, target.targetPort);
    final newApiUrl = 'http://127.0.0.1:$relayPort';

    AppConfig.activeNodeUrl = target.apiUrl;
    AppConfig.apiUrl = newApiUrl;
    AppConfig.isTorEnabled = true;
    updateApiUrl(newApiUrl);

    debugPrint('✅ Tor Network Ready.');
    debugPrint(
      '🌐 Unified Tor Relay Active: ${AppConfig.apiUrl} -> ${target.apiUrl}',
    );
    return true;
  } on StateError catch (error) {
    AppConfig.isTorEnabled = false;
    debugPrint('🧅 Mobile node configuration invalid: $error');
    return false;
  } catch (error, stackTrace) {
    AppConfig.isTorEnabled = false;
    debugPrint('❌ CRITICAL ERROR: Tor or Relay failed to start: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}
