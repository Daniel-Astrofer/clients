import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'statement_csv_export.dart';

/// Builds a simple multi-page PDF statement with shortened addresses.
Future<Uint8List> buildStatementPdfBytes(List<Transaction> transactions) async {
  final doc = pw.Document();
  final rows = transactions.take(200).toList(growable: false);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Kerosene — Extrato',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Gerado em ${DateTime.now().toUtc().toIso8601String()} (UTC) · '
            '${transactions.length} lançamentos'
            '${transactions.length > 200 ? ' (PDF limita 200)' : ''}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (context) {
        return [
          pw.TableHelper.fromTextArray(
            headers: const [
              'Quando',
              'Tipo',
              'Rede',
              'Valor (sats)',
              'De/Para',
              'TXID',
              'Status',
            ],
            data: [
              for (final tx in rows)
                [
                  tx.timestamp.toUtc().toIso8601String().substring(0, 16),
                  tx.type.name,
                  _network(tx),
                  (tx.isDebit ? -tx.signedDisplaySatoshis : tx.amountSatoshis)
                      .toString(),
                  _party(tx),
                  _short(tx.blockchainTxid ?? ''),
                  tx.status.name,
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Endereços e TXIDs longos foram encurtados. '
            'Use o CSV para reconciliação numérica completa em sats.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ];
      },
    ),
  );

  return doc.save();
}

String _network(Transaction tx) {
  if (tx.isInternal) return 'interna';
  if (tx.isLightning) return 'lightning';
  if (tx.isColdProvider) return 'cold';
  return 'onchain';
}

String _party(Transaction tx) {
  final from = _short(tx.counterpartyLabel ?? tx.fromAddress);
  final to = _short(tx.walletLabel ?? tx.toAddress);
  if (tx.isCredit) return 'De $from';
  return 'Para ${tx.counterpartyLabel != null ? _short(tx.counterpartyLabel!) : to}';
}

String _short(String raw) {
  final v = raw.trim();
  if (v.length <= 18) return v;
  return '${v.substring(0, 8)}…${v.substring(v.length - 6)}';
}

/// Share a PDF extrato (addresses redacted/shortened).
Future<StatementExportResult> exportStatementPdf(
  List<Transaction> transactions, {
  String filePrefix = 'kerosene_extrato',
}) async {
  final bytes = await buildStatementPdfBytes(transactions);

  if (kIsWeb) {
    // Web: fall back to CSV copy — blob download varies by platform.
    return exportStatementCsv(transactions, filePrefix: filePrefix);
  }

  try {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/${filePrefix}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: 'extrato.pdf'),
        ],
        subject: 'Extrato Kerosene (PDF)',
        text: 'Extrato local (${transactions.length} lançamentos).',
      ),
    );
    return StatementExportResult(
      copiedToClipboard: false,
      shared: true,
      path: file.path,
      rowCount: transactions.length,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('exportStatementPdf failed: $e');
    }
    return StatementExportResult(
      copiedToClipboard: false,
      shared: false,
      path: null,
      rowCount: transactions.length,
    );
  }
}
