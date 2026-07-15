import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Coherent date/time formatting using the **app** locale (not only device).
///
/// Backend timestamps are treated as UTC when they lack a zone suffix, then
/// converted with [DateTime.toLocal] so list headers and news stay consistent.
class AppDateTime {
  const AppDateTime._();

  /// Parse API timestamps robustly.
  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw.toLocal();
    if (raw is int) {
      // Heuristic: seconds vs millis.
      final ms = raw > 20000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    // If string had no zone, DateTime.tryParse treats as local — prefer UTC
    // when the payload looks like ISO without Z (backend often sends UTC wall).
    if (!text.endsWith('Z') &&
        !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text) &&
        text.contains('T')) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).toLocal();
    }
    return parsed.toLocal();
  }

  static String languageCodeOf(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }

  static String formatTime(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final use24 = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? true;
    final pattern = use24 ? 'HH:mm' : 'h:mm a';
    return DateFormat(pattern, languageCodeOf(context)).format(local);
  }

  static String formatDate(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final lang = languageCodeOf(context);

    if (day == today) {
      return switch (lang) {
        'pt' => 'Hoje',
        'es' => 'Hoy',
        _ => 'Today',
      };
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return switch (lang) {
        'pt' => 'Ontem',
        'es' => 'Ayer',
        _ => 'Yesterday',
      };
    }
    if (local.year == now.year) {
      return DateFormat('d MMM', lang).format(local);
    }
    return DateFormat('d MMM y', lang).format(local);
  }

  static String formatDateTime(BuildContext context, DateTime timestamp) {
    return '${formatDate(context, timestamp)} · ${formatTime(context, timestamp)}';
  }

  static String formatFull(BuildContext context, DateTime timestamp) {
    return DateFormat.yMMMd(languageCodeOf(context))
        .add_Hm()
        .format(timestamp.toLocal());
  }
}
