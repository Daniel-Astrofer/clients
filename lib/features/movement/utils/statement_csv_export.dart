import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a privacy-conscious CSV of the local/remote projection.
///
/// Long on-chain addresses are shortened; internal UUIDs are omitted when a
/// human label exists. Values are satoshis (integer) for exact recon.
String buildStatementCsv(List<Transaction> transactions) {
  final buf = StringBuffer();
  buf.writeln(
    'id,timestamp,type,status,network,direction,amount_sats,fee_sats,service_fee_sats,'
    'wallet,from,to,counterparty,txid,confirmations,provider,failure_code',
  );
  for (final tx in transactions) {
    final network = tx.isInternal
        ? 'internal'
        : tx.isLightning
            ? 'lightning'
            : tx.isColdProvider
                ? 'cold'
                : 'onchain';
    final direction = tx.isCredit ? 'in' : (tx.isDebit ? 'out' : '');
    final wallet = _csvCell(
      tx.walletLabel ?? tx.sourceWalletLabel ?? tx.destinationWalletLabel ?? '',
    );
    final from = _csvCell(_shortMaybeAddress(tx.fromAddress));
    final to = _csvCell(_shortMaybeAddress(tx.toAddress));
    final cp = _csvCell(tx.counterpartyLabel ?? '');
    final txid = _csvCell((tx.blockchainTxid ?? '').trim());
    buf.writeln(
      [
        _csvCell(tx.id),
        _csvCell(tx.timestamp.toUtc().toIso8601String()),
        _csvCell(tx.type.name),
        _csvCell(tx.status.name),
        _csvCell(network),
        _csvCell(direction),
        tx.amountSatoshis.toString(),
        tx.feeSatoshis.toString(),
        tx.serviceFeeSatoshis.toString(),
        wallet,
        from,
        to,
        cp,
        txid,
        tx.confirmations.toString(),
        _csvCell(tx.provider ?? ''),
        _csvCell(tx.failureCode ?? ''),
      ].join(','),
    );
  }
  return buf.toString();
}

String _csvCell(String raw) {
  final v = raw.replaceAll('"', '""');
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"$v"';
  }
  return v;
}

String _shortMaybeAddress(String raw) {
  final v = raw.trim();
  if (v.length <= 22) return v;
  // Keep enough to identify without full address dump.
  return '${v.substring(0, 10)}…${v.substring(v.length - 8)}';
}

/// Copy CSV to clipboard and (on mobile) open the system share sheet.
Future<StatementExportResult> exportStatementCsv(
  List<Transaction> transactions, {
  String filePrefix = 'kerosene_extrato',
}) async {
  final csv = buildStatementCsv(transactions);
  await Clipboard.setData(ClipboardData(text: csv));

  if (kIsWeb) {
    return StatementExportResult(
      copiedToClipboard: true,
      shared: false,
      path: null,
      rowCount: transactions.length,
    );
  }

  try {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/${filePrefix}_$stamp.csv');
    await file.writeAsString(csv, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: 'extrato.csv')],
        subject: 'Extrato Kerosene',
        text: 'Extrato local (${transactions.length} lançamentos). '
            'Endereços longos foram encurtados.',
      ),
    );
    return StatementExportResult(
      copiedToClipboard: true,
      shared: true,
      path: file.path,
      rowCount: transactions.length,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('exportStatementCsv share failed: $e');
    }
    return StatementExportResult(
      copiedToClipboard: true,
      shared: false,
      path: null,
      rowCount: transactions.length,
    );
  }
}

class StatementExportResult {
  final bool copiedToClipboard;
  final bool shared;
  final String? path;
  final int rowCount;

  const StatementExportResult({
    required this.copiedToClipboard,
    required this.shared,
    required this.path,
    required this.rowCount,
  });
}
