import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/localization/app_timezone_scope.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/security/presentation/screens/settings_formatters.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_components.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  testWidgets('selected clock updates existing descendants and receipt helpers',
      (tester) async {
    final instant = DateTime.utc(2026, 10, 14, 1, 2);
    final zone = ValueNotifier<String?>('America/Sao_Paulo');
    addTearDown(zone.dispose);
    final child = Builder(
        builder: (context) => Text([
              AppDateTime.formatTime(context, instant),
              AppDateTime.formatFull(context, instant),
              settingsDateLabel(instant, context: context),
              formatReceiveDateTime(instant, context: context),
              bitcoinAccountHistoryTimestampLabel(instant, context: context),
            ].join(' | ')));
    await tester.pumpWidget(MaterialApp(
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: ValueListenableBuilder<String?>(
          valueListenable: zone,
          builder: (_, id, child) =>
              AppTimezoneScope(timeZoneId: id, child: child!),
          child: child,
        ),
      ),
    ));
    var text = tester.widget<Text>(find.byType(Text).first).data!;
    expect(text, contains('22:02'));
    expect(text, contains('13/10/2026'));
    expect(text, contains('13 Out 2026'));
    zone.value = 'Asia/Tokyo';
    await tester.pump();
    text = tester.widget<Text>(find.byType(Text).first).data!;
    expect(text, contains('10:02'));
    expect(text, contains('14/10/2026'));
    zone.value = null;
    await tester.pump();
    final context = tester.element(find.byType(Text).first);
    expect(AppDateTime.inDisplayZone(context, instant), instant.toLocal());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'today and yesterday use selected calendar across device midnight',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AppTimezoneScope(
            timeZoneId: 'America/Sao_Paulo', child: SizedBox.shrink())));
    final context = tester.element(find.byType(SizedBox));
    final now = DateTime.utc(2026, 10, 14, 1);
    expect(
        AppDateTime.formatDate(context, DateTime.utc(2026, 10, 13, 23),
            now: now),
        'Today');
    expect(
        AppDateTime.formatDate(context, DateTime.utc(2026, 10, 13, 1),
            now: now),
        'Yesterday');
  });

  testWidgets(
      'relative elapsed time is independent of the display zone and DST',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AppTimezoneScope(
            timeZoneId: 'America/New_York', child: SizedBox.shrink())));
    final context = tester.element(find.byType(SizedBox));
    final now = DateTime.utc(2026, 3, 8, 7, 1);
    expect(
        AppDateTime.formatRelative(context, DateTime.utc(2026, 3, 8, 6, 59),
            now: now),
        '2m ago');
    expect(AppDateTime.inDisplayZone(context, now).hour, 3);
  });
  testWidgets('device mode ignores a pinned ID but reacts to OS zone metadata',
      (tester) async {
    final metadata = ValueNotifier('UTC-03:00');
    addTearDown(metadata.dispose);
    var builds = 0;
    late DateTime shown;
    final instant = DateTime.utc(2026, 7, 15, 12);
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<String>(
      valueListenable: metadata,
      builder: (_, id, child) =>
          AppTimezoneScope(timeZoneId: id, followDevice: true, child: child!),
      child: Builder(builder: (context) {
        builds++;
        shown = AppDateTime.inDisplayZone(context, instant);
        return const SizedBox.shrink();
      }),
    )));
    expect(shown, instant.toLocal());
    final before = builds;
    metadata.value = 'UTC+09:00';
    await tester.pump();
    expect(builds, before + 1);
    expect(shown, instant.toLocal());
  });
}
