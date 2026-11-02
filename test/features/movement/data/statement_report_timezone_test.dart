import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kerosene/features/movement/data/statement_report_calculator.dart';
import 'package:kerosene/features/movement/domain/entities/statement_report.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

Transaction received(String id, DateTime at,
        {TransactionStatus status = TransactionStatus.confirmed}) =>
    Transaction(
      id: id,
      fromAddress: 'external',
      toAddress: 'owned',
      amountSatoshis: 101,
      feeSatoshis: 0,
      status: status,
      type: TransactionType.receive,
      confirmations: 6,
      timestamp: at,
    );

void main() {
  setUpAll(() => initializeDateFormatting());

  test('monthly totals use selected calendar and exclude exact end boundary',
      () {
    final report = StatementReportCalculator.calculate(
      transactions: [
        received('last-month', DateTime.utc(2026, 1, 1, 0, 30)),
        received('end', DateTime.utc(2026, 1, 1, 5)),
        received('failed', DateTime.utc(2026, 1, 1, 0, 31),
            status: TransactionStatus.failed),
      ],
      period: StatementReportPeriod.monthly,
      now: DateTime.utc(2026, 1, 1, 1),
      timeZoneId: 'America/New_York',
    );
    expect(report.periodStart.toUtc(), DateTime.utc(2025, 12, 1, 5));
    expect(report.periodEnd.toUtc(), DateTime.utc(2026, 1, 1, 5));
    expect(report.incomingSats, 101);
    expect(report.includedTransactionCount, 1);
    expect(report.ignoredFailedTransactionCount, 1);
    expect(report.ignoredOutOfPeriodTransactionCount, 1);
    expect(report.buckets.single.values.single.sats, 101);
  });

  test('weekly DST boundary keeps each bucket at calendar midnight', () {
    final report = StatementReportCalculator.calculate(
      transactions: [
        received('inside', DateTime.utc(2026, 3, 9, 3, 59)),
        received('after', DateTime.utc(2026, 3, 9, 4)),
      ],
      period: StatementReportPeriod.weekly,
      now: DateTime.utc(2026, 3, 8, 15),
      timeZoneId: 'America/New_York',
    );
    final week = report.buckets.last;
    for (final bucket in report.buckets) {
      expect(bucket.start.hour, 0);
      expect(bucket.end.hour, 0);
    }
    expect(report.buckets.first.end, week.start);
    expect(week.start.toUtc(), DateTime.utc(2026, 3, 2, 5));
    expect(week.end.toUtc(), DateTime.utc(2026, 3, 9, 4));
    expect(week.end.difference(week.start).inHours, 167);
    expect(report.incomingSats, 101);
    expect(week.values.single.sats, 101);
  });

  test('month rollover and fixed offset preserve satoshi totals', () {
    final at = DateTime.utc(2026, 1, 31, 20);
    final report = StatementReportCalculator.calculate(
      transactions: [received('february', at)],
      period: StatementReportPeriod.annual,
      now: at,
      timeZoneId: 'UTC+05:45',
    );
    expect(report.periodStart.toUtc(), DateTime.utc(2026, 1, 31, 18, 15));
    expect(report.periodEnd.toUtc(), DateTime.utc(2026, 2, 28, 18, 15));
    expect(report.incomingSats, 101);
    expect(report.netSats, 101);
  });
}
