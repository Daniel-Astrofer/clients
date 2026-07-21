import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/core/services/tor_service.dart';
import 'package:kerosene/features/auth/data/models/user_model.dart';
import 'package:uuid/uuid.dart';

import 'totp_utils.dart';

/// Result of a real (Tor/.onion) auth session for visual E2E.
class RealSession {
  final String username;
  final String passphrase;
  final String jwt;
  final String? totpSecret;
  final UserModel user;
  final String apiBaseUrl;

  const RealSession({
    required this.username,
    required this.passphrase,
    required this.jwt,
    required this.user,
    required this.apiBaseUrl,
    this.totpSecret,
  });
}

String solvePoW(String challenge) {
  var nonce = 0;
  const prefix = '0000';
  while (true) {
    final input = '$challenge$nonce';
    final digest = crypto.sha256.convert(utf8.encode(input));
    final hash = digest.toString();
    if (hash.startsWith(prefix)) {
      return nonce.toString();
    }
    nonce++;
    if (nonce > 2000000) break;
  }
  return nonce.toString();
}

/// Boots Tor relay to the active onion node and returns the local relay base URL.
Future<String> bootstrapTorRelay({TorService? tor}) async {
  final service = tor ?? TorService.instance;
  final host = Uri.parse(AppConfig.onionBaseUrl).host;
  debugPrint('[visual-e2e] Tor relay → $host');

  try {
    final started = await service.start();
    if (!started) {
      debugPrint(
          '[visual-e2e] TorService.start returned false; trying relay anyway');
    }
  } catch (e) {
    debugPrint('[visual-e2e] TorService.start: $e');
  }

  final relayPort = await service.startRelay(host, 80);
  final base = 'http://127.0.0.1:$relayPort';
  AppConfig.apiUrl = base;
  debugPrint('[visual-e2e] API via Tor relay: $base');
  return base;
}

Dio _dio(String baseUrl) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      validateStatus: (s) => s != null && s < 500,
    ),
  );
}

/// Creates a brand-new account (PoW → signup → TOTP) and returns a session.
Future<RealSession> createEphemeralSession(String apiBaseUrl) async {
  final dio = _dio(apiBaseUrl);
  final username = 'visual_${const Uuid().v4().substring(0, 8)}';
  const passphrase = 'VisualE2e!234';

  debugPrint('[visual-e2e] Signup $username');
  final challengeRes = await dio.get(AppConfig.authPowChallenge);
  if (challengeRes.statusCode != 200) {
    throw StateError('PoW challenge failed: ${challengeRes.statusCode}');
  }
  final challenge = challengeRes.data['challenge'] as String;
  final nonce = solvePoW(challenge);

  final signupRes = await dio.post(
    AppConfig.authSignup,
    data: {
      'username': username,
      'passphrase': passphrase,
      'accountSecurity': 'standard',
      'challenge': challenge,
      'nonce': nonce,
    },
  );
  if (signupRes.statusCode != 200 && signupRes.statusCode != 201) {
    throw StateError(
        'Signup failed: ${signupRes.statusCode} ${signupRes.data}');
  }

  final body = signupRes.data;
  final otpUri = body['otpUri'] ?? body['qrCodeUri'] ?? body['data']?['otpUri'];
  String? totpSecret;
  if (otpUri != null) {
    totpSecret = Uri.tryParse(otpUri.toString())?.queryParameters['secret'];
  }
  totpSecret ??=
      (body['totpSecret'] ?? body['data']?['totpSecret'])?.toString();
  if (totpSecret == null || totpSecret.isEmpty) {
    throw StateError('Signup did not return TOTP secret');
  }

  final verifyCode = TotpGenerator.generate(totpSecret);
  final verifyRes = await dio.post(
    AppConfig.authSignupVerify,
    data: {'username': username, 'totpCode': verifyCode},
  );
  if (verifyRes.statusCode != 200) {
    throw StateError('Signup TOTP verify failed: ${verifyRes.statusCode}');
  }

  return loginWithCredentials(
    apiBaseUrl: apiBaseUrl,
    username: username,
    passphrase: passphrase,
    totpSecret: totpSecret,
  );
}

/// Logs in with existing credentials (password + TOTP).
Future<RealSession> loginWithCredentials({
  required String apiBaseUrl,
  required String username,
  required String passphrase,
  required String totpSecret,
}) async {
  final dio = _dio(apiBaseUrl);

  debugPrint('[visual-e2e] Login $username');
  final loginRes = await dio.post(
    AppConfig.authLogin,
    data: {'username': username, 'passphrase': passphrase},
  );

  String? preAuthToken;
  if (loginRes.statusCode == 202) {
    preAuthToken = loginRes.data.toString();
  } else if (loginRes.statusCode == 200) {
    // Direct JWT path (no TOTP) — rare for our accounts.
    final raw = loginRes.data.toString();
    final jwt = raw.contains(' ') ? raw.split(' ').last : raw;
    final user = await _fetchMe(dio, jwt);
    return RealSession(
      username: username,
      passphrase: passphrase,
      jwt: jwt,
      totpSecret: totpSecret,
      user: user,
      apiBaseUrl: apiBaseUrl,
    );
  } else {
    throw StateError('Login failed: ${loginRes.statusCode} ${loginRes.data}');
  }

  final code = TotpGenerator.generate(totpSecret);
  final finalRes = await dio.post(
    AppConfig.authLoginVerify,
    data: {
      'username': username,
      'totpCode': code,
      'preAuthToken': preAuthToken,
    },
  );
  if (finalRes.statusCode != 200) {
    throw StateError(
      'Login TOTP verify failed: ${finalRes.statusCode} ${finalRes.data}',
    );
  }

  final raw = finalRes.data.toString();
  final jwt = raw.contains(' ') ? raw.split(' ').last : raw;
  final user = await _fetchMe(dio, jwt);

  return RealSession(
    username: username,
    passphrase: passphrase,
    jwt: jwt,
    totpSecret: totpSecret,
    user: user,
    apiBaseUrl: apiBaseUrl,
  );
}

Future<UserModel> _fetchMe(Dio dio, String jwt) async {
  final me = await dio.get(
    AppConfig.authMe,
    options: Options(headers: {'Authorization': 'Bearer $jwt'}),
  );
  if (me.statusCode != 200 || me.data is! Map) {
    // Minimal placeholder so local storage still has a user blob.
    return UserModel(
      id: '0',
      username: 'visual_e2e',
      createdAt: DateTime.now().toUtc(),
    );
  }
  return UserModel.fromJson(Map<String, dynamic>.from(me.data as Map));
}

/// Persists JWT + user so the real app shell restores [AuthAuthenticated].
Future<void> persistSession(RealSession session) async {
  final storage = SecureStorageService();
  await storage.write(key: AppConfig.authTokenKey, value: session.jwt);
  await storage.write(
    key: AppConfig.userDataKey,
    value: jsonEncode(session.user.toJson()),
  );
  debugPrint(
    '[visual-e2e] Session persisted for ${session.user.username} (${session.user.id})',
  );
}

/// Env-driven session:
/// - VISUAL_E2E_USERNAME + VISUAL_E2E_PASSWORD + VISUAL_E2E_TOTP_SECRET → login
/// - otherwise create ephemeral account (needs live onion).
Future<RealSession> obtainVisualSession(String apiBaseUrl) async {
  final username = Platform.environment['VISUAL_E2E_USERNAME']?.trim();
  final password = Platform.environment['VISUAL_E2E_PASSWORD']?.trim();
  final totp = Platform.environment['VISUAL_E2E_TOTP_SECRET']?.trim();

  if (username != null &&
      username.isNotEmpty &&
      password != null &&
      password.isNotEmpty &&
      totp != null &&
      totp.isNotEmpty) {
    return loginWithCredentials(
      apiBaseUrl: apiBaseUrl,
      username: username,
      passphrase: password,
      totpSecret: totp,
    );
  }

  debugPrint(
    '[visual-e2e] No VISUAL_E2E_* credentials; creating ephemeral account',
  );
  return createEphemeralSession(apiBaseUrl);
}
