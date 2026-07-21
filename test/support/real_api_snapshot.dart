import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/services/tor_service.dart';
import 'package:kerosene/features/auth/data/models/user_model.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:uuid/uuid.dart';

import '../integration/totp_utils.dart';

/// UI snapshot for **real-data goldens** (full-scroll widget render).
///
/// Preferred source: JSON exported from the **device** (no credentials).
/// Optional fallback: live Tor login via [fetchRealUiSnapshot].
class RealUiSnapshot {
  final User user;
  final String jwt;
  final String apiBaseUrl;
  final List<Wallet> wallets;
  final List<Transaction> transactions;
  final BackendBtcRates rates;
  final DateTime capturedAt;
  final String source;

  const RealUiSnapshot({
    required this.user,
    required this.jwt,
    required this.apiBaseUrl,
    required this.wallets,
    required this.transactions,
    required this.rates,
    required this.capturedAt,
    this.source = 'api',
  });

  String get sessionScope {
    final id = user.id.trim();
    if (id.isNotEmpty && id != '0') return 'user_$id';
    return 'user_${user.username}';
  }

  factory RealUiSnapshot.fromDeviceJson(Map<String, dynamic> json) {
    final userMap = Map<String, dynamic>.from(json['user'] as Map? ?? {});
    final user = UserModel.fromJson(userMap).toEntity();
    final wallets = (json['wallets'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Wallet.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final txs = <Transaction>[];
    for (final raw in (json['transactions'] as List? ?? const [])) {
      if (raw is! Map) continue;
      try {
        txs.add(Transaction.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    final ratesMap = Map<String, dynamic>.from(json['rates'] as Map? ?? {});
    return RealUiSnapshot(
      user: user,
      jwt: '',
      apiBaseUrl: '',
      wallets: wallets,
      transactions: txs,
      rates: BackendBtcRates(
        btcUsd: (ratesMap['btcUsd'] as num?)?.toDouble() ?? 0,
        btcBrl: (ratesMap['btcBrl'] as num?)?.toDouble() ?? 0,
        btcEur: (ratesMap['btcEur'] as num?)?.toDouble() ?? 0,
        usdBrl: (ratesMap['usdBrl'] as num?)?.toDouble() ?? 0,
      ),
      capturedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      source: json['source']?.toString() ?? 'device',
    );
  }
}

/// Default path written by [tools/device-snapshot-goldens.sh] after adb pull.
const defaultDeviceSnapshotRelativePath =
    'test/goldens/real_data/fixtures/device_ui_snapshot.json';

/// Resolve snapshot file: env DEVICE_SNAPSHOT_PATH, else default fixture path.
File? resolveDeviceSnapshotFile() {
  final fromEnv = Platform.environment['DEVICE_SNAPSHOT_PATH']?.trim();
  final candidates = <String>[
    if (fromEnv != null && fromEnv.isNotEmpty) fromEnv,
    defaultDeviceSnapshotRelativePath,
    // When CWD is repo root
    'frontend/$defaultDeviceSnapshotRelativePath',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 20) return f;
  }
  return null;
}

/// Load snapshot exported from the device (no credentials).
RealUiSnapshot? loadDeviceUiSnapshot() {
  final file = resolveDeviceSnapshotFile();
  if (file == null) return null;
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final snap = RealUiSnapshot.fromDeviceJson(map);
  debugPrint(
    '[real-golden] loaded device snapshot ${file.path} '
    'user=${snap.user.username} wallets=${snap.wallets.length} '
    'txs=${snap.transactions.length} source=${snap.source}',
  );
  return snap;
}

String _solvePoW(String challenge) {
  var nonce = 0;
  const prefix = '0000';
  while (true) {
    final digest =
        crypto.sha256.convert(utf8.encode('$challenge$nonce')).toString();
    if (digest.startsWith(prefix) || nonce > 2000000) {
      return nonce.toString();
    }
    nonce++;
  }
}

Dio _dio(String base, {String? jwt}) {
  return Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (jwt != null && jwt.isNotEmpty) 'Authorization': 'Bearer $jwt',
      },
      validateStatus: (s) => s != null && s < 500,
    ),
  );
}

List<Map<String, dynamic>> _asMapList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (data is Map) {
    final root = Map<String, dynamic>.from(data);
    for (final key in ['data', 'items', 'content', 'result', 'wallets']) {
      final v = root[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (v is Map) {
        final nested = Map<String, dynamic>.from(v);
        final content = nested['content'] ?? nested['items'];
        if (content is List) {
          return content
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    if (root['wallets'] is List) {
      return (root['wallets'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return const [];
}

Future<String> bootstrapTorApiBase() async {
  final service = TorService.instance;
  final host = Uri.parse(AppConfig.onionBaseUrl).host;
  try {
    await service.start();
  } catch (e) {
    debugPrint('[real-golden] tor start: $e');
  }
  final port = await service.startRelay(host, 80);
  final base = 'http://127.0.0.1:$port';
  AppConfig.apiUrl = base;
  debugPrint('[real-golden] API $base → $host');
  return base;
}

Future<({String jwt, UserModel user, String? totp})> _loginOrSignup(
  String apiBase,
) async {
  final envUser = Platform.environment['REAL_GOLDEN_USERNAME']?.trim() ??
      Platform.environment['VISUAL_E2E_USERNAME']?.trim();
  final envPass = Platform.environment['REAL_GOLDEN_PASSWORD']?.trim() ??
      Platform.environment['VISUAL_E2E_PASSWORD']?.trim();
  final envTotp = Platform.environment['REAL_GOLDEN_TOTP_SECRET']?.trim() ??
      Platform.environment['VISUAL_E2E_TOTP_SECRET']?.trim();

  if (envUser != null &&
      envUser.isNotEmpty &&
      envPass != null &&
      envPass.isNotEmpty &&
      envTotp != null &&
      envTotp.isNotEmpty) {
    return _login(apiBase, envUser, envPass, envTotp);
  }

  // Ephemeral account — still *real* backend rows (may be empty balances).
  final dio = _dio(apiBase);
  final username = 'rgold_${const Uuid().v4().substring(0, 8)}';
  const pass = 'RealGolden!234';
  final challengeRes = await dio.get(AppConfig.authPowChallenge);
  final challenge = challengeRes.data['challenge'] as String;
  final nonce = _solvePoW(challenge);
  final signup = await dio.post(
    AppConfig.authSignup,
    data: {
      'username': username,
      'passphrase': pass,
      'accountSecurity': 'standard',
      'challenge': challenge,
      'nonce': nonce,
    },
  );
  if (signup.statusCode != 200 && signup.statusCode != 201) {
    throw StateError('signup failed: ${signup.statusCode} ${signup.data}');
  }
  final body = signup.data;
  final otpUri = body['otpUri'] ?? body['qrCodeUri'] ?? body['data']?['otpUri'];
  String? totp;
  if (otpUri != null) {
    totp = Uri.tryParse(otpUri.toString())?.queryParameters['secret'];
  }
  totp ??= (body['totpSecret'] ?? body['data']?['totpSecret'])?.toString();
  if (totp == null || totp.isEmpty) {
    throw StateError('signup missing totp secret');
  }
  final verify = await dio.post(
    AppConfig.authSignupVerify,
    data: {
      'username': username,
      'totpCode': TotpGenerator.generate(totp),
    },
  );
  if (verify.statusCode != 200) {
    throw StateError('signup totp failed: ${verify.statusCode}');
  }
  return _login(apiBase, username, pass, totp);
}

Future<({String jwt, UserModel user, String? totp})> _login(
  String apiBase,
  String username,
  String pass,
  String totpSecret,
) async {
  final dio = _dio(apiBase);
  final login = await dio.post(
    AppConfig.authLogin,
    data: {'username': username, 'passphrase': pass},
  );
  late final String jwt;
  if (login.statusCode == 200) {
    final raw = login.data.toString();
    jwt = raw.contains(' ') ? raw.split(' ').last : raw;
  } else if (login.statusCode == 202) {
    final pre = login.data.toString();
    final fin = await dio.post(
      AppConfig.authLoginVerify,
      data: {
        'username': username,
        'totpCode': TotpGenerator.generate(totpSecret),
        'preAuthToken': pre,
      },
    );
    if (fin.statusCode != 200) {
      throw StateError('login totp failed: ${fin.statusCode} ${fin.data}');
    }
    final raw = fin.data.toString();
    jwt = raw.contains(' ') ? raw.split(' ').last : raw;
  } else {
    throw StateError('login failed: ${login.statusCode} ${login.data}');
  }

  final me = await _dio(apiBase, jwt: jwt).get(AppConfig.authMe);
  final user = me.statusCode == 200 && me.data is Map
      ? UserModel.fromJson(Map<String, dynamic>.from(me.data as Map))
      : UserModel(
          id: '0',
          username: username,
          createdAt: DateTime.now().toUtc(),
        );
  return (jwt: jwt, user: user, totp: totpSecret);
}

/// Boots Tor, authenticates, pulls dashboard wallets + txs + price rates.
Future<RealUiSnapshot> fetchRealUiSnapshot() async {
  final base = await bootstrapTorApiBase();
  final auth = await _loginOrSignup(base);
  final dio = _dio(base, jwt: auth.jwt);

  List<Wallet> wallets = const [];
  List<Transaction> txs = const [];
  var rates = const BackendBtcRates(
    btcUsd: 0,
    btcBrl: 0,
    btcEur: 0,
    usdBrl: 0,
  );

  try {
    final dash = await dio.get(AppConfig.kfeDashboard);
    final walletMaps = _asMapList(dash.data);
    // Prefer nested wallets when dashboard is a map with richer list.
    if (dash.data is Map) {
      final map = Map<String, dynamic>.from(dash.data as Map);
      final nested = _asMapList(map['wallets']);
      if (nested.isNotEmpty) {
        wallets = nested.map(Wallet.fromJson).toList();
      } else if (walletMaps.isNotEmpty) {
        wallets = walletMaps.map(Wallet.fromJson).toList();
      }
    } else {
      wallets = walletMaps.map(Wallet.fromJson).toList();
    }
  } catch (e) {
    debugPrint('[real-golden] wallets: $e');
  }

  try {
    final hist = await dio.get(
      AppConfig.kfeTransactions,
      queryParameters: {'page': 0, 'size': 50},
    );
    final items = _asMapList(hist.data);
    txs = items
        .map((m) {
          try {
            return Transaction.fromJson(m);
          } catch (e) {
            debugPrint('[real-golden] skip tx parse: $e');
            return null;
          }
        })
        .whereType<Transaction>()
        .toList();
  } catch (e) {
    debugPrint('[real-golden] transactions: $e');
  }

  try {
    final price = await dio.get('/api/economy/btc-price');
    if (price.data is Map) {
      rates = BackendBtcRates.fromJson(
        Map<String, dynamic>.from(price.data as Map),
      );
    }
  } catch (e) {
    debugPrint('[real-golden] rates: $e');
  }

  debugPrint(
    '[real-golden] snapshot user=${auth.user.username} '
    'wallets=${wallets.length} txs=${txs.length} '
    'btcUsd=${rates.btcUsd}',
  );

  return RealUiSnapshot(
    user: auth.user,
    jwt: auth.jwt,
    apiBaseUrl: base,
    wallets: wallets,
    transactions: txs,
    rates: rates,
    capturedAt: DateTime.now().toUtc(),
  );
}
