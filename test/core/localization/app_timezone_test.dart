import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/localization/app_timezone.dart';

void main() {
  test('every settings choice resolves to a supported location', () {
    for (final id in [...AppTimezone.curatedZones, 'utc', 'gmt']) {
      expect(AppTimezone.isSupported(id), isTrue, reason: id);
    }
  });

  test('conversion preserves the instant including subsecond precision', () {
    final instant = DateTime.utc(2026, 10, 14, 1, 2, 3, 456, 789);
    final selected =
        AppTimezone.convert(instant, timeZoneId: 'America/Sao_Paulo');
    expect(selected.day, 13);
    expect(selected.hour, 22);
    expect(selected.microsecondsSinceEpoch, instant.microsecondsSinceEpoch);
    expect(selected.toUtc(), instant);
  });

  test('named location observes the offset at the operation date', () {
    final winter = AppTimezone.convert(DateTime.utc(2026, 1, 15, 12),
        timeZoneId: 'America/New_York');
    final summer = AppTimezone.convert(DateTime.utc(2026, 7, 15, 12),
        timeZoneId: 'America/New_York');
    expect(winter.hour, 7);
    expect(summer.hour, 8);
    expect(winter.timeZoneOffset, const Duration(hours: -5));
    expect(summer.timeZoneOffset, const Duration(hours: -4));
  });

  test('settings label reports selected offset, rather than device offset', () {
    expect(
        AppTimezone.displayLabel('Asia/Tokyo', now: DateTime.utc(2026, 1, 15)),
        'Asia/Tokyo (UTC+09:00)');
    expect(
        AppTimezone.displayLabel('America/New_York',
            now: DateTime.utc(2026, 7, 15)),
        'America/New_York (UTC-04:00)');
  });

  test('fixed offset retains minutes and crosses the correct calendar date',
      () {
    final instant = DateTime.utc(2026, 1, 1, 20);
    final selected = AppTimezone.convert(instant, timeZoneId: 'UTC+05:45');
    expect(selected.day, 2);
    expect(selected.hour, 1);
    expect(selected.minute, 45);
    expect(selected.toUtc(), instant);
    expect(AppTimezone.convert(instant, timeZoneId: 'UTC-03:30').minute, 30);
  });

  test('device following uses OS timezone and preserves instant', () {
    final instant = DateTime.utc(2026, 7, 15, 12);
    expect(AppTimezone.convert(instant), instant.toLocal());
  });

  test('invalid selections cannot be silently converted', () {
    for (final id in [
      'America/Invented',
      'BRT',
      '',
      'UTC+99:00',
      'UTC+05:99',
      'UTC+14:01'
    ]) {
      expect(AppTimezone.isSupported(id), isFalse, reason: id);
    }
    expect(
        () => AppTimezone.convert(DateTime.utc(2026), timeZoneId: 'UTC+99:00'),
        throwsArgumentError);
    expect(AppTimezone.resolve('America/Invented'), AppTimezone.detectId());
  });

  test('calendar weeks respect DST rather than elapsed 168 hours', () {
    final start = AppTimezone.calendar(2026, 3, 2, 'America/New_York');
    final end = AppTimezone.calendar(2026, 3, 9, 'America/New_York');
    expect(start.hour, 0);
    expect(end.hour, 0);
    expect(end.difference(start).inHours, 167);
  });
}
