import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Device / app timezone helpers (IANA when available, robust fallbacks otherwise).
///
/// Flutter does not always expose a full IANA id. We:
/// 1. Prefer an explicit user override (settings)
/// 2. Else try platform timezone name if it looks like IANA (`America/Sao_Paulo`)
/// 3. Else persist a stable `UTC±HH:MM` label derived from the current offset
class AppTimezone {
  const AppTimezone._();

  static final RegExp _ianaLike = RegExp(r'^[A-Za-z_]+(?:/[A-Za-z0-9_+\-]+)+$');
  static final RegExp _utcOffset = RegExp(r'^UTC([+-])(\d{2}):(\d{2})$');
  static bool _initialized = false;

  static void _initialize() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// Named zones use the offset at the instant, including historical DST.
  static tz.Location location(String id) {
    final normalized = id.trim();
    if (normalized.toUpperCase() == 'GMT' ||
        normalized.toUpperCase() == 'UTC') {
      return tz.UTC;
    }
    final match = _utcOffset.firstMatch(normalized.toUpperCase());
    if (match != null) {
      final hours = int.parse(match[2]!);
      final minutes = int.parse(match[3]!);
      if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
        throw ArgumentError.value(id, 'id', 'Invalid UTC offset');
      }
      final sign = match[1] == '-' ? -1 : 1;
      final offset = Duration(minutes: sign * (hours * 60 + minutes));
      return tz.Location(normalized, const [], const [], [
        tz.TimeZone(offset, isDst: false, abbreviation: normalized),
      ]);
    }
    _initialize();
    return tz.getLocation(normalized);
  }

  static bool isSupported(String id) {
    try {
      location(id);
      return true;
    } on ArgumentError {
      return false;
    } on tz.LocationNotFoundException {
      return false;
    }
  }

  /// Null means follow the device; the stored instant is never changed.
  static DateTime convert(DateTime instant, {String? timeZoneId}) =>
      timeZoneId == null
          ? DateTime.fromMicrosecondsSinceEpoch(instant.microsecondsSinceEpoch)
          : tz.TZDateTime.from(instant, location(timeZoneId));

  /// Construct a calendar boundary in the selected zone, without adding 24h
  /// across a daylight-saving transition.
  static DateTime calendar(int year,
          [int month = 1, int day = 1, String? timeZoneId]) =>
      timeZoneId == null
          ? DateTime(year, month, day)
          : tz.TZDateTime(location(timeZoneId), year, month, day);

  /// Curated list for settings picker (covers main Kerosene markets).
  static const curatedZones = <String>[
    'America/Sao_Paulo',
    'America/Manaus',
    'America/Fortaleza',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Mexico_City',
    'America/Bogota',
    'America/Lima',
    'America/Argentina/Buenos_Aires',
    'America/Santiago',
    'Europe/Lisbon',
    'Europe/Madrid',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Europe/Amsterdam',
    'Africa/Lagos',
    'Asia/Dubai',
    'Asia/Tokyo',
    'Asia/Singapore',
    'Australia/Sydney',
    'UTC',
  ];

  /// Best-effort id for API headers and backend content scheduling.
  static String detectId() {
    // PlatformDispatcher has no timezoneName; DateTime does.
    final zoneName = DateTime.now().timeZoneName.trim();
    if (_ianaLike.hasMatch(zoneName) && isSupported(zoneName)) {
      return zoneName;
    }
    // Some platforms return abbreviations (BRT, PST). Fall back to offset label.
    return offsetLabel(DateTime.now().timeZoneOffset);
  }

  static String offsetLabel(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final abs = totalMinutes.abs();
    final hours = (abs ~/ 60).toString().padLeft(2, '0');
    final minutes = (abs % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  static bool looksLikeIana(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (_ianaLike.hasMatch(v)) return true;
    if (_utcOffset.hasMatch(v.toUpperCase())) return true;
    if (v.toUpperCase() == 'UTC' || v.toUpperCase() == 'GMT') return true;
    return false;
  }

  static String resolve(String? preferred) {
    final p = preferred?.trim() ?? '';
    if (p.isNotEmpty && isSupported(p)) {
      return p;
    }
    return detectId();
  }

  /// Human label for settings UI.
  static String displayLabel(String timeZoneId, {DateTime? now}) {
    final id = timeZoneId.trim();
    if (id.isEmpty) return detectId();
    final offset = offsetLabel(
        convert(now ?? DateTime.now(), timeZoneId: id).timeZoneOffset);
    if (id == offset || id.startsWith('UTC')) {
      return id;
    }
    return '$id ($offset)';
  }

  /// Short city-style label for curated zones.
  static String shortLabel(String timeZoneId) {
    final id = timeZoneId.trim();
    if (id.isEmpty || id.toUpperCase() == 'UTC') return 'UTC';
    final slash = id.lastIndexOf('/');
    if (slash < 0) return id;
    return id.substring(slash + 1).replaceAll('_', ' ');
  }

  /// Minutes east of UTC for the running device (for headers).
  static int deviceOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;
}
