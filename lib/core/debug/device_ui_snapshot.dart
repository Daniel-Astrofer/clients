import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/data/models/user_model.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// Fixed file name so adb/scripts always know where to look.
const kDeviceUiSnapshotFileName = 'device_ui_snapshot.json';

/// Folder name under Downloads / Documents.
const kDeviceUiSnapshotDirName = 'kerosene_captures';

/// Snapshot of **whatever is already loaded in the running app** (device session).
/// Used to generate full-scroll goldens without typing credentials.
class DeviceUiSnapshot {
  final User user;
  final List<Wallet> wallets;
  final List<Transaction> transactions;
  final BackendBtcRates rates;
  final DateTime capturedAt;
  final String source; // e.g. linux | android | unknown

  const DeviceUiSnapshot({
    required this.user,
    required this.wallets,
    required this.transactions,
    required this.rates,
    required this.capturedAt,
    this.source = 'unknown',
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'source': source,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'user': UserModel.fromEntity(user).toJson(),
        'wallets': wallets.map(_walletToJson).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'rates': {
          'btcUsd': rates.btcUsd,
          'btcBrl': rates.btcBrl,
          'btcEur': rates.btcEur,
          'usdBrl': rates.usdBrl,
        },
      };

  factory DeviceUiSnapshot.fromJson(Map<String, dynamic> json) {
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
      } catch (e) {
        debugPrint('[device-snapshot] skip tx: $e');
      }
    }
    final ratesMap = Map<String, dynamic>.from(json['rates'] as Map? ?? {});
    final rates = BackendBtcRates(
      btcUsd: (ratesMap['btcUsd'] as num?)?.toDouble() ?? 0,
      btcBrl: (ratesMap['btcBrl'] as num?)?.toDouble() ?? 0,
      btcEur: (ratesMap['btcEur'] as num?)?.toDouble() ?? 0,
      usdBrl: (ratesMap['usdBrl'] as num?)?.toDouble() ?? 0,
    );
    return DeviceUiSnapshot(
      user: user,
      wallets: wallets,
      transactions: txs,
      rates: rates,
      capturedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      source: json['source']?.toString() ?? 'unknown',
    );
  }

  static Map<String, dynamic> _walletToJson(Wallet w) => {
        'id': w.id,
        'walletId': w.id,
        'name': w.name,
        'walletName': w.name,
        'label': w.name,
        'address': w.address,
        'depositAddress': w.address,
        'onchainAddress': w.address,
        'balance': w.balance,
        'availableSats': w.availableSats,
        'observedSats': w.observedSats,
        'walletMode': w.walletMode,
        'spendable': w.spendable,
        'walletTypeDescription': w.custodyExplanation,
        'accountSecurity': w.accountSecurity,
        'cardType': w.cardType.name,
        'cardHolderName': w.cardHolderName,
        'cardMaskedNumber': w.cardMaskedNumber,
        'cardNumberSuffix': w.cardNumberSuffix,
        'cardSequence': w.cardSequence,
        'cardRotationStatus': w.cardRotationStatus,
        'withdrawalFeeRate': w.withdrawalFeeRate,
        'depositFeeRate': w.depositFeeRate,
        'isActive': w.isActive,
        'createdAt': w.createdAt.toIso8601String(),
        'updatedAt': w.updatedAt.toIso8601String(),
      };

  /// Build from the **live** Riverpod graph of the running app.
  static DeviceUiSnapshot captureFromRef(WidgetRef ref) {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      throw StateError(
        'App não está autenticado. Entre na conta no device e tente de novo.',
      );
    }

    final walletState = ref.read(walletProvider);
    final wallets = walletState is WalletLoaded
        ? walletState.wallets
        : const <Wallet>[];

    var txs = <Transaction>[];
    final txAsync = ref.read(transactionHistoryProvider);
    final txData = txAsync.asData?.value;
    if (txData != null && txData.isNotEmpty) {
      txs = List<Transaction>.from(txData);
    } else {
      try {
        final last = ref.read(lastTransactionHistoryProvider);
        if (last.isNotEmpty) txs = List<Transaction>.from(last);
      } catch (_) {}
    }

    var rates = const BackendBtcRates(
      btcUsd: 0,
      btcBrl: 0,
      btcEur: 0,
      usdBrl: 0,
    );
    final backendRates = ref.read(backendBtcRatesProvider).asData?.value;
    if (backendRates != null) {
      rates = backendRates;
    } else {
      final latest = ref.read(latestBtcPriceProvider);
      if (latest != null && latest > 0) {
        rates = BackendBtcRates(
          btcUsd: latest,
          btcBrl: ref.read(btcBrlPriceProvider) ?? latest * 5,
          btcEur: ref.read(btcEurPriceProvider) ?? latest * 0.92,
          usdBrl: 5,
        );
      }
    }

    String source = 'unknown';
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        source = 'android';
      } else if (Platform.isLinux) {
        source = 'linux';
      } else if (Platform.isIOS) {
        source = 'ios';
      } else if (Platform.isMacOS) {
        source = 'macos';
      }
    }

    return DeviceUiSnapshot(
      user: auth.user,
      wallets: wallets,
      transactions: txs,
      rates: rates,
      capturedAt: DateTime.now().toUtc(),
      source: source,
    );
  }

  /// Writes [kDeviceUiSnapshotFileName] under Downloads and Documents.
  /// Returns all paths written (for SnackBar / logs).
  static Future<List<File>> writeEverywhere(DeviceUiSnapshot snapshot) async {
    final json = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    final bytes = utf8.encode(json);
    final written = <File>[];

    Future<void> tryWrite(Directory dir) async {
      try {
        final targetDir = Directory(p.join(dir.path, kDeviceUiSnapshotDirName));
        await targetDir.create(recursive: true);
        final file = File(p.join(targetDir.path, kDeviceUiSnapshotFileName));
        await file.writeAsBytes(bytes, flush: true);
        written.add(file);
        debugPrint('[device-snapshot] wrote ${file.path} (${bytes.length} bytes)');
      } catch (e) {
        debugPrint('[device-snapshot] write failed in ${dir.path}: $e');
      }
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) await tryWrite(downloads);
    } catch (_) {}

    try {
      await tryWrite(await getApplicationDocumentsDirectory());
    } catch (_) {}

    // Android public Download (easy adb pull even without run-as).
    if (!kIsWeb && Platform.isAndroid) {
      for (final root in [
        '/sdcard/Download',
        '/storage/emulated/0/Download',
      ]) {
        try {
          final dir = Directory(root);
          if (await dir.exists()) await tryWrite(dir);
        } catch (_) {}
      }
    }

    if (written.isEmpty) {
      throw StateError('Não foi possível gravar device_ui_snapshot.json');
    }
    return written;
  }

  /// Capture live providers and persist for golden generation.
  static Future<List<File>> exportFromRef(WidgetRef ref) async {
    final snap = captureFromRef(ref);
    if (snap.wallets.isEmpty && snap.transactions.isEmpty) {
      debugPrint(
        '[device-snapshot] warning: wallets and txs empty — '
        'abra a Home e espere carregar antes de exportar',
      );
    }
    return writeEverywhere(snap);
  }
}
