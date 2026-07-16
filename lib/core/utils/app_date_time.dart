import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Coherent date/time formatting using the **app** locale (not only device).
///
/// Backend timestamps are treated as UTC when they lack a zone suffix, then
/// converted with [DateTime.toLocal] so list headers and history stay consistent
/// with the user's wall clock (e.g. America/Sao_Paulo vs UTC pods).
class AppDateTime {
  const AppDateTime._();

  /// Parse API timestamps robustly into the device local zone.
  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return raw.isUtc ? raw.toLocal() : raw.toLocal();
    }
    if (raw is int) {
      // Heuristic: seconds vs millis.
      final ms = raw > 20000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    // Normalize space separator → T for looser backends.
    final normalized = text.contains('T') ? text : text.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;

    final hasExplicitOffset = RegExp(
      r'(z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(normalized);

    if (parsed.isUtc || hasExplicitOffset) {
      return parsed.toLocal();
    }

    // Backend KFE historically emits LocalDateTime without zone while the JVM
    // clock is UTC. Treat bare ISO wall-clock as UTC, then convert to local.
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

  /// Human relative time for history cards: "agora", "há 3 min", "há 2 h", "ontem".
  /// Falls back to a short date for older items.
  static String formatRelative(
    BuildContext context,
    DateTime timestamp, {
    DateTime? now,
    String? languageCode,
  }) {
    final local = timestamp.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    var diff = n.difference(local);
    final lang = (languageCode ?? languageCodeOf(context)).toLowerCase();

    // Clock skew / future timestamps (e.g. slight server lead).
    if (diff.isNegative) {
      if (diff.inMinutes > -3) {
        return switch (lang) {
          'pt' => 'agora',
          'es' => 'ahora',
          _ => 'now',
        };
      }
      return formatDateTime(context, local);
    }

    if (diff.inSeconds < 45) {
      return switch (lang) {
        'pt' => 'agora',
        'es' => 'ahora',
        _ => 'now',
      };
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return switch (lang) {
        'pt' => 'há $m min',
        'es' => 'hace $m min',
        _ => '${m}m ago',
      };
    }
    if (diff.inHours < 24) {
      final h = diff.inHours.clamp(1, 23);
      return switch (lang) {
        'pt' => 'há $h h',
        'es' => 'hace $h h',
        _ => '${h}h ago',
      };
    }
    if (diff.inDays == 1) {
      return switch (lang) {
        'pt' => 'ontem',
        'es' => 'ayer',
        _ => 'yesterday',
      };
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return switch (lang) {
        'pt' => 'há $d d',
        'es' => 'hace $d d',
        _ => '${d}d ago',
      };
    }
    return formatDate(context, local);
  }

  /// Relative primary + absolute clock secondary (detail rows).
  static String formatRelativeWithClock(
    BuildContext context,
    DateTime timestamp, {
    DateTime? now,
  }) {
    final relative = formatRelative(context, timestamp, now: now);
    final clock = formatTime(context, timestamp);
    // Avoid "19:49 · 19:49" style when relative already is clock-like.
    if (relative.contains(':')) return relative;
    return '$relative · $clock';
  }
}
