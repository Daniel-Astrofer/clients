import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'statement_csv_export.dart';
import 'transaction_taxonomy.dart';

/// Exports every supplied movement with complete identifiers and exact amounts.
/// The selected set is a snapshot of loaded history, not a completeness claim
/// about the server. Long fields span rows/pages rather than being shortened.
Future<Uint8List> buildStatementPdfBytes(
  List<Transaction> transactions, {
  AppLocalizations? localizations,
  MovementMoney money = const MovementMoney(),
  DateTime? generatedAt,
}) async {
  final tr = localizations ?? lookupAppLocalizations(const Locale('en'));
  final fonts = await Future.wait([
    rootBundle.load('assets/fonts/AeonikPro-Regular.ttf'),
    rootBundle.load('assets/fonts/AeonikPro-Medium.ttf'),
    rootBundle.load('assets/fonts/AeonikPro-Bold.ttf'),
    rootBundle.load('assets/fonts/ModeratMono-Regular.ttf'),
  ]);
  return compute(_renderStatementPdf, (
    transactions: List<Transaction>.of(transactions),
    fonts: fonts,
    language: tr.localeName,
    money: money,
    generatedAt: generatedAt ?? DateTime.now(),
  ));
}

Future<Uint8List> _renderStatementPdf(
    ({
      List<Transaction> transactions,
      List<ByteData> fonts,
      String language,
      MovementMoney money,
      DateTime generatedAt,
    }) input) async {
  final transactions = input.transactions;
  final fonts = input.fonts;
  final money = input.money;
  final tr = lookupAppLocalizations(Locale(input.language.split('_').first));
  final body = pw.Font.ttf(fonts[0]);
  final bold = pw.Font.ttf(fonts[1]);
  final title = pw.Font.ttf(fonts[2]);
  final technical = pw.Font.ttf(fonts[3]);
  final doc = pw.Document(
      title: 'Kerosene - ${tr.statementExportDocumentTitle}',
      author: 'Kerosene');
  final stamp = input.generatedAt.toUtc().toIso8601String();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    theme: pw.ThemeData.withFont(base: body, bold: bold),
    header: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Kerosene - ${tr.statementExportDocumentTitle}',
            style: pw.TextStyle(font: title, fontSize: 22)),
        pw.SizedBox(height: 6),
        pw.Text(tr.statementPdfGeneratedAt(stamp),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(tr.statementPdfSummary(transactions.length),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),
      ],
    ),
    footer: (context) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
          tr.statementPdfPage(context.pageNumber, context.pagesCount),
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ),
    build: (_) => [
      pw.Text(tr.statementPdfLoadedHistoryNote,
          style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 16),
      if (transactions.isEmpty) pw.Text(tr.statementEmptyOnDevice),
      for (var index = 0; index < transactions.length; index++) ...[
        pw.NewPage(freeSpace: 110),
        pw.Text('${index + 1}. ${_type(transactions[index], tr)}',
            style: pw.TextStyle(font: bold, fontSize: 12)),
        pw.SizedBox(height: 5),
        pw.Text(_primary(transactions[index], money),
            style: pw.TextStyle(font: bold, fontSize: 14)),
        pw.SizedBox(height: 8),
        for (final field in _fields(transactions[index], tr, money.locale))
          for (final chunk in _chunks(field.value))
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom:
                          pw.BorderSide(color: PdfColors.grey300, width: .3))),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 140,
                      child: pw.Text(chunk.first ? field.label : '',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700))),
                  pw.Expanded(
                      child: pw.Text(chunk.value,
                          style: pw.TextStyle(
                              font: field.technical ? technical : body,
                              fontSize: 9))),
                ],
              ),
            ),
        pw.SizedBox(height: 20),
      ],
    ],
  ));
  return doc.save();
}

String _primary(Transaction tx, MovementMoney money) {
  final includeFees = tx.isDebit && (tx.showsNetworkFee || tx.showsServiceFee);
  final frozen = switch (money.currency) {
    Currency.usd => tx.displayAmountUsd,
    Currency.eur => tx.displayAmountEur,
    Currency.brl => tx.displayAmountBrl,
    Currency.btc => null,
  };
  return MoneyDisplay.formatOperationAmount(
      satoshis:
          tx.isDebit ? -tx.signedDisplaySatoshis : tx.signedDisplaySatoshis,
      currency: money.currency,
      recordedFiat: includeFees ? null : frozen,
      signed: true,
      appLocale: money.locale);
}

String _type(Transaction tx, AppLocalizations tr) => switch (tx.type) {
      TransactionType.send => tr.typeSend,
      TransactionType.receive => tr.typeReceive,
      TransactionType.deposit => tr.txListDeposit,
      TransactionType.withdrawal => tr.txListWithdraw,
      TransactionType.fee => tr.txListFee,
      TransactionType.swap => tr.txListSwap,
    };

String _network(TxRail rail, AppLocalizations tr) => switch (rail) {
      TxRail.internal => tr.txListInstant,
      TxRail.onchain => tr.activityFilterOnchain,
      TxRail.lightning => tr.activityFilterLightning,
      TxRail.cold => tr.activityFilterCold,
    };

String _status(TxLifecycle lifecycle, AppLocalizations tr) =>
    switch (lifecycle) {
      TxLifecycle.pending => tr.txListPending,
      TxLifecycle.confirming => tr.txListConfirming,
      TxLifecycle.confirmed => tr.txListConfirmed,
      TxLifecycle.failed => tr.txListFailed,
      TxLifecycle.cancelled => tr.txListCancelled,
      TxLifecycle.reconciling => tr.txListNeedsReview,
      TxLifecycle.unconfirmedExpired => tr.txListUnconfirmed,
    };

({String label, String value, bool technical}) _field(
        String label, String value,
        {bool technical = false}) =>
    (label: label, value: value, technical: technical);

List<({String label, String value, bool technical})> _fields(
    Transaction tx, AppLocalizations tr, Locale? locale) {
  String exact(int sats) =>
      MoneyDisplay.formatOperationAmount(satoshis: sats, appLocale: locale);
  final axes = TransactionAxes.classify(tx);
  final rows = [
    _field(tr.txListId, tx.id, technical: true),
    _field(
        '${tr.txListDateTime} (UTC)', tx.timestamp.toUtc().toIso8601String()),
    _field(tr.txListStatus, _status(axes.lifecycle, tr)),
    _field(tr.txListNetwork, _network(axes.rail, tr)),
    _field(tr.txListAmountBtc,
        exact(tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis)),
    _field(tr.statementPdfAmountSats,
        '${tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis}'),
  ];
  void add(String label, String? value, {bool technical = false}) {
    if (value?.trim().isNotEmpty == true) {
      rows.add(_field(label, value!.trim(), technical: technical));
    }
  }

  if (tx.showsNetworkFee) {
    rows.add(_field(tr.txListNetworkFee,
        '${exact(tx.feeSatoshis)} / ${tx.feeSatoshis} sats'));
  }
  if (tx.showsServiceFee) {
    rows.add(_field(tr.txListServiceFee,
        '${exact(tx.serviceFeeSatoshis)} / ${tx.serviceFeeSatoshis} sats'));
  }
  if (tx.isDebit) {
    rows.add(_field(
        tx.isConfirmed ? tr.txListTotalDebited : tr.movementOperationTotal,
        '${exact(tx.signedDisplaySatoshis)} / ${tx.signedDisplaySatoshis} sats'));
  }
  add(tr.txListYourWallet, tx.walletLabel);
  add(tr.txListSourceWallet, tx.sourceWalletId, technical: true);
  add(tr.txListDestinationWallet, tx.destinationWalletId, technical: true);
  add(tr.txListFromAddress, tx.fromAddress, technical: true);
  add(tr.txListToAddress, tx.toAddress, technical: true);
  add(tr.statementPdfCounterparty, tx.counterpartyLabel);
  add(tr.txListDescription, tx.description);
  add(tr.txListOnchainTxid, tx.blockchainTxid, technical: true);
  add(tr.txListPaymentHash, tx.paymentHash, technical: true);
  add(tr.txListLightningInvoice, tx.lightningInvoice, technical: true);
  add(tr.txListExternalRef, tx.externalReference, technical: true);
  add(tr.statementPdfFailureCode, tx.failureCode, technical: true);
  if (tx.showsOnchainConfirmations) {
    rows.add(_field(tr.txListConfirmations, '${tx.confirmations}'));
  }
  return rows;
}

/// Each row remains small enough to fit on a page, even for a long invoice or
/// description. Splitting by Unicode code point preserves the complete value.
Iterable<({bool first, String value})> _chunks(String text) sync* {
  final runes = text.runes.toList();
  var start = 0;
  while (start < runes.length) {
    var end = (start + 720).clamp(0, runes.length);
    var lineBreaks = 0;
    for (var index = start; index < end; index++) {
      if (runes[index] == 10 && ++lineBreaks >= 12) {
        end = index + 1;
        break;
      }
    }
    if (end < runes.length) {
      for (var index = end - 1; index > (end - 80).clamp(start, end); index--) {
        if (String.fromCharCode(runes[index]).trim().isEmpty) {
          end = index + 1;
          break;
        }
      }
    }
    yield (
      first: start == 0,
      value: String.fromCharCodes(runes.sublist(start, end))
    );
    start = end;
  }
}

/// Shares the PDF and acknowledges only the platform's confirmed share result.
Future<StatementExportResult> exportStatementPdf(
  List<Transaction> transactions, {
  String filePrefix = 'kerosene_statement',
  AppLocalizations? localizations,
  MovementMoney money = const MovementMoney(),
}) async {
  final tr = localizations ?? lookupAppLocalizations(const Locale('en'));
  final bytes = await buildStatementPdfBytes(transactions,
      localizations: tr, money: money);
  String? path;
  try {
    final XFile attachment;
    if (kIsWeb) {
      attachment = XFile.fromData(bytes,
          mimeType: 'application/pdf', name: 'statement.pdf');
    } else {
      final dir = await getTemporaryDirectory();
      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/${filePrefix}_$stamp.pdf');
      await file.writeAsBytes(bytes, flush: true);
      path = file.path;
      attachment =
          XFile(path, mimeType: 'application/pdf', name: 'statement.pdf');
    }
    final result = await SharePlus.instance.share(ShareParams(
        files: [attachment],
        subject: tr.statementExportDocumentTitle,
        text: tr.statementPdfSummary(transactions.length)));
    return StatementExportResult(
        copiedToClipboard: false,
        shared: result.status == ShareResultStatus.success,
        shareDismissed: result.status == ShareResultStatus.dismissed,
        path: path,
        rowCount: transactions.length);
  } catch (_) {
    // The caller displays a failure/unconfirmed message; never expose file or
    // financial data in platform exception logs.
    return StatementExportResult(
        copiedToClipboard: false,
        shared: false,
        path: path,
        rowCount: transactions.length);
  }
}
