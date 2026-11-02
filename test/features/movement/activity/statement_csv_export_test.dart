import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_csv_export.dart';

void main() {
  test('CSV preserves complete addresses, hash and exact integer amounts', () {
    final from = 'bc1q${List.filled(4, 'abcdefgh01234567').join()}';
    final to = 'bc1q${List.filled(4, 'ijklmnop76543210').join()}';
    final hash = List.filled(4, '0123456789abcdef').join();
    final csv = buildStatementCsv([
      Transaction(
        id: 'ledger-operation-12345678901234567890',
        fromAddress: from,
        toAddress: to,
        blockchainTxid: hash,
        amountSatoshis: 1,
        feeSatoshis: 0,
        status: TransactionStatus.confirmed,
        type: TransactionType.send,
        confirmations: 6,
        timestamp: DateTime.utc(2026, 10, 11, 12),
      ),
    ]);
    expect(csv, contains(',$from,$to,'));
    expect(csv, contains(',$hash,6,'));
    expect(csv, contains(',-1,0,0,'));
    expect(csv, isNot(contains('…')));
  });
  test(
      'CSV escapes spreadsheet formulas without changing numeric satoshi columns',
      () {
    final csv = buildStatementCsv([
      Transaction(
          id: '=1+1',
          fromAddress: '@external',
          toAddress: '+destination',
          counterpartyLabel: '-counterparty',
          walletLabel: 'José, carteira',
          amountSatoshis: 1,
          feeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.send,
          confirmations: 6,
          timestamp: DateTime.utc(2026)),
    ]);
    expect(csv, contains("'=1+1,"));
    expect(csv, contains(",'@external,'+destination,'-counterparty,"));
    expect(csv, contains(',-1,0,0,'));
    expect(csv, contains('"José, carteira"'));
  });
}
