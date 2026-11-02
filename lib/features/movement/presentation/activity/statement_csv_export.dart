import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a CSV of the local/remote projection with complete public identifiers.
///
/// Addresses and transaction references remain complete for reconciliation.
/// Values are satoshis (integer) for exact reconciliation.
/// Network/direction/status use the same taxonomy as Home/Extrato filters.
String buildStatementCsv(List<Transaction> transactions) {
  final buf = StringBuffer();
  buf.writeln(
    'id,timestamp,type,status,network,direction,amount_sats,fee_sats,service_fee_sats,'
    'wallet,from,to,counterparty,txid,confirmations,provider,failure_code',
  );
  for (final tx in transactions) {
    final axes = TransactionAxes.classify(tx);
    final network = switch (axes.rail) {
      TxRail.internal => 'instant',
      TxRail.onchain => 'onchain',
      TxRail.lightning => 'lightning',
      TxRail.cold => 'cold',
    };
    final direction = switch (axes.direction) {
      TxDirection.incoming => 'in',
      TxDirection.outgoing => 'out',
      TxDirection.neutral => '',
    };
    final status = axes.lifecycle.name;
    final wallet = _csvCell(
      tx.walletLabel ?? tx.sourceWalletLabel ?? tx.destinationWalletLabel ?? '',
    );
    final from = _csvCell(tx.fromAddress.trim());
    final to = _csvCell(tx.toAddress.trim());
    final cp = _csvCell(tx.counterpartyLabel ?? '');
    final txid = _csvCell((tx.blockchainTxid ?? '').trim());
    buf.writeln(
      [
        _csvCell(tx.id),
        _csvCell(tx.timestamp.toUtc().toIso8601String()),
        _csvCell(tx.type.name),
        _csvCell(status),
        _csvCell(network),
        _csvCell(direction),
        // Debits export total leaving wallet (principal + fees) when present.
        (tx.isDebit ? -tx.signedDisplaySatoshis : tx.amountSatoshis).toString(),
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
  // Text supplied by users must not become a formula when opened in a spreadsheet.
  // Numeric satoshi columns are emitted separately and preserve their exact sign.
  final text = RegExp(r'^\s*[=+\-@]').hasMatch(raw) ? "'$raw" : raw;
  final v = text.replaceAll('"', '""');
  if (v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r')) {
    return '"$v"';
  }
  return v;
}

/// Copy CSV to clipboard and (on mobile) open the system share sheet.
Future<StatementExportResult> exportStatementCsv(
  List<Transaction> transactions, {
  String filePrefix = 'kerosene_statement',
  AppLocalizations? localizations,
}) async {
  final tr = localizations ?? lookupAppLocalizations(const Locale('en'));
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
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'text/csv', name: 'statement.csv'),
        ],
        subject: tr.statementExportDocumentTitle,
        text: tr.statementPdfSummary(transactions.length),
      ),
    );
    return StatementExportResult(
      copiedToClipboard: true,
      shared: result.status == ShareResultStatus.success,
      shareDismissed: result.status == ShareResultStatus.dismissed,
      path: file.path,
      rowCount: transactions.length,
    );
  } catch (_) {
    // Clipboard acknowledgement remains true even if file sharing fails.
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
  final bool shareDismissed;
  final String? path;
  final int rowCount;

  const StatementExportResult({
    required this.copiedToClipboard,
    required this.shared,
    this.shareDismissed = false,
    required this.path,
    required this.rowCount,
  });
}
