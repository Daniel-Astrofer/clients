import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_csv_export.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_pdf_export.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';

const _share = MethodChannel('dev.fluttercommunity.plus/share');
const _paths = MethodChannel('plugins.flutter.io/path_provider');
final _hash = List.filled(4, '0123456789abcdef').join();
final _address = 'bc1q${List.filled(4, 'abcdefghijklmnop').join()}';
final _invoice = 'lnbc${List.filled(18, 'invoice0123456789abcdef').join()}';

Transaction fixture(int index, {TransactionStatus? status}) => Transaction(
    id: 'full-operation-identifier-${index.toString().padLeft(3, '0')}',
    fromAddress: _address,
    toAddress: 'bc1q${List.filled(3, 'destinationabcdefghijklmnop').join()}',
    amountSatoshis: index == 0 ? 1 : 12345678,
    feeSatoshis: 2,
    serviceFeeSatoshis: 3,
    totalDebitedSatoshis: index == 0 ? 6 : 12345683,
    status: status ??
        TransactionStatus.values[index % TransactionStatus.values.length],
    type: index == 1 ? TransactionType.receive : TransactionType.send,
    confirmations: index == 2 ? 7 : 0,
    timestamp: DateTime.utc(2026, 10, 12, 10, 30, 45),
    isLightning: index == 3,
    isInternal: index == 4,
    blockchainTxid: index == 3 || index == 4 ? null : _hash,
    paymentHash: index == 3 ? _hash : null,
    lightningInvoice: index == 3 ? _invoice : null,
    failureCode: index == 4 ? 'USER_CANCELLED' : null,
    walletLabel: 'Carteira demonstração - José',
    counterpartyLabel: 'Dados fictícios - revisão de frontend',
    description: index == 3
        ? List.filled(30, 'Descrição pública extensa. ').join()
        : 'Dados fictícios para verificação, sem transação real.');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  var rawShareResult = 'fixture.target';
  final shares = <MethodCall>[];

  setUp(() async {
    temporary =
        await Directory.systemTemp.createTemp('kerosene-statement-test-');
    shares.clear();
    rawShareResult = 'fixture.target';
    // Flutter's test asset handler supplies empty font bytes. Exercise the
    // PDF engine with the real bundled fonts used by the application.
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
        (message) async {
      final path = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final file = File(path);
      if (!await file.exists()) return null;
      return ByteData.sublistView(await file.readAsBytes());
    });
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_paths, (_) async => temporary.path);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_share,
        (call) async {
      shares.add(call);
      return rawShareResult;
    });
  });
  tearDown(() async {
    binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    for (final channel in [_share, _paths, SystemChannels.platform]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
    await temporary.delete(recursive: true);
  });

  for (final format in ['csv', 'pdf']) {
    for (final result in [
      'fixture.target',
      '',
      'dev.fluttercommunity.plus/share/unavailable'
    ]) {
      test('$format acknowledges the actual share result: $result', () async {
        rawShareResult = result;
        final rows = [fixture(0)];
        final exported = format == 'csv'
            ? await exportStatementCsv(rows)
            : await exportStatementPdf(rows);
        expect(exported.shared, result == 'fixture.target');
        expect(exported.shareDismissed, result.isEmpty);
        expect(exported.copiedToClipboard, format == 'csv');
        expect(exported.rowCount, 1);
        expect(shares, hasLength(1));
        expect(File(exported.path!).existsSync(), isTrue);
        expect(shares.single.arguments['text'], isNot(contains('shortened')));
        if (format == 'pdf') {
          expect(shares.single.arguments['mimeTypes'], ['application/pdf']);
        }
      });
    }
  }

  test(
      'clipboard rejection fails CSV without opening share or reporting success',
      () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => throw PlatformException(code: 'clipboard_denied'));
    await expectLater(
        exportStatementCsv([fixture(0)]), throwsA(isA<PlatformException>()));
    expect(shares, isEmpty);
  });

  test('platform share exception leaves CSV copy acknowledgement intact',
      () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _share, (_) async => throw PlatformException(code: 'share_denied'));
    final result = await exportStatementCsv([fixture(0)]);
    expect(result.copiedToClipboard, isTrue);
    expect(result.shared, isFalse);
  });

  test('empty PDF remains a valid localized document', () async {
    final bytes = await buildStatementPdfBytes([],
        localizations: lookupAppLocalizations(const Locale('pt')));
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  var canExtract = false;
  try {
    canExtract = Process.runSync('pdftotext', ['-v']).exitCode == 0;
  } catch (_) {}
  for (final language in ['pt', 'en', 'es']) {
    test('PDF preserves every movement, identifiers and exact money: $language',
        () async {
      final count = language == 'pt' ? 205 : 6;
      final bytes = await buildStatementPdfBytes(List.generate(count, fixture),
          localizations: lookupAppLocalizations(Locale(language)),
          money: MovementMoney(
              currency: Currency.btc,
              locale: Locale(language),
              btcDecimalPlaces: 2),
          generatedAt: DateTime.utc(2026, 10, 12, 12));
      final file = File('${temporary.path}/statement-$language.pdf');
      await file.writeAsBytes(bytes);
      final extraction =
          await Process.run('pdftotext', ['-layout', file.path, '-']);
      expect(extraction.exitCode, 0, reason: extraction.stderr.toString());
      final text = extraction.stdout.toString();
      final compact = text.replaceAll(RegExp(r'\s'), '');
      expect(compact, contains(_hash));
      expect(compact, contains(_address));
      expect(compact, contains(_invoice));
      final exportedIds = RegExp(r'full-operation-identifier-\d{3}')
          .allMatches(compact)
          .map((match) => match.group(0))
          .toList();
      expect(exportedIds, hasLength(count));
      expect(exportedIds.toSet(), hasLength(count));
      for (final page
          in text.split('\f').where((page) => page.trim().isNotEmpty)) {
        expect(page, contains('Kerosene'),
            reason: 'Every page retains its header');
      }
      expect(
          compact,
          contains(
              'full-operation-identifier-${(count - 1).toString().padLeft(3, '0')}'));
      final separator = language == 'en' ? '.' : ',';
      expect(text, contains('0${separator}00000001 BTC'));
      expect(text, contains('0${separator}00000006 BTC'));
      expect(text, isNot(contains('Valores aproximados')));
      expect(text, isNot(contains('Approximate values')));
      expect(text, isNot(contains('valores aproximados')));
      expect(text, isNot(contains('shortened')));
      expect(text, isNot(contains('aprox.')));
      expect(text, isNot(contains('approx.')));
      expect(text, isNot(contains('≈')));
      expect(text, isNot(contains('…')));
      expect(
          text,
          contains(lookupAppLocalizations(Locale(language))
              .statementExportDocumentTitle));
      expect(text, contains('UTC'));
      final qaDirectory = Platform.environment['KERO_PDF_QA_DIR'];
      if (qaDirectory != null) {
        await Directory(qaDirectory).create(recursive: true);
        await file.copy('$qaDirectory/statement-cohesion-$language.pdf');
      }
    },
        skip: canExtract
            ? false
            : 'Requires Poppler pdftotext for PDF content validation');
  }
}
