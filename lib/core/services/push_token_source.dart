import 'package:flutter/foundation.dart';

/// Supplies the device token registered with the backend.
///
/// Default: stable `local-alert:{installId}` for on-device delivery.
/// Optional override: set [PushTokenSource.remoteTokenOverride] after obtaining
/// an FCM/APNs token (when product enables Google/Apple push).
class PushTokenSource {
  PushTokenSource._();

  /// When non-null and non-empty, registered instead of (or in addition to)
  /// the local-alert token. Never log this value.
  static String? remoteTokenOverride;

  /// Whether a remote (FCM/APNs-style) token is currently configured.
  static bool get hasRemoteToken {
    final t = remoteTokenOverride?.trim();
    return t != null && t.isNotEmpty && !t.startsWith('local-alert:');
  }

  /// Builds the primary registration token for [installId].
  static String primaryToken({required String installId}) {
    final remote = remoteTokenOverride?.trim();
    if (remote != null &&
        remote.isNotEmpty &&
        !remote.startsWith('local-alert:')) {
      return remote;
    }
    return 'local-alert:$installId';
  }

  /// Optional second registration so both local-alert and remote coexist.
  static String? secondaryLocalAlertToken({required String installId}) {
    if (!hasRemoteToken) return null;
    if (installId.isEmpty) return null;
    return 'local-alert:$installId';
  }

  static void clearRemoteToken() {
    remoteTokenOverride = null;
    if (kDebugMode) {
      debugPrint('PushTokenSource: remote token cleared');
    }
  }
}
