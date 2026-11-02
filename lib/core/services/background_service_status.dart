import 'dart:convert';
import 'package:crypto/crypto.dart';

/// State reported by the running native isolate, without credentials.
class BackgroundServiceStatus {
  const BackgroundServiceStatus({required this.running, this.userId});
  final bool running;
  final String? userId;
}

class BackgroundServiceNeedsForeground implements Exception {
  const BackgroundServiceNeedsForeground();
}

/// Consistency fence for separately stored token/user data. The Core signs
/// JWT `sub` as the user id; the server still verifies the signature and auth.
bool backgroundTokenMatchesUser(String token, String userId, {DateTime? now}) {
  try {
    final raw = token.startsWith('Bearer ') ? token.substring(7) : token;
    final parts = raw.trim().split('.');
    if (parts.length != 3) return false;
    final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final seconds =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    return claims is Map &&
        claims['exp'] is int &&
        claims['exp'] > seconds &&
        (claims['nbf'] == null ||
            (claims['nbf'] is int && claims['nbf'] <= seconds)) &&
        claims['sub'] is String &&
        claims['sub'] == userId &&
        userId.isNotEmpty &&
        userId != '0';
  } catch (_) {
    return false;
  }
}

/// A persisted rejection marker contains only a digest, never the credential.
String backgroundCredentialFingerprint(String token) =>
    sha256.convert(utf8.encode(token)).toString();

/// A late 401 for an old token must not suspend a renewed session.
bool backgroundCredentialRejectionApplies(
        int? statusCode, String? attemptedToken, String? currentToken) =>
    statusCode == 401 &&
    attemptedToken != null &&
    attemptedToken.isNotEmpty &&
    attemptedToken == currentToken;
