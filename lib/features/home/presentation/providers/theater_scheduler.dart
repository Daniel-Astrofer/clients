import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/home/presentation/providers/theater_catalog.dart';

/// Budget and cooldown rules for recurring education theater.
class TheaterSchedulerConfig {
  final int maxEducationPerSession;
  final Duration minGapBetweenEducation;
  final Duration familyCooldown;
  final Duration idleBeforeOffer;

  const TheaterSchedulerConfig({
    this.maxEducationPerSession = 2,
    this.minGapBetweenEducation = const Duration(seconds: 90),
    this.familyCooldown = const Duration(hours: 24),
    this.idleBeforeOffer = const Duration(seconds: 45),
  });
}

class TheaterSchedulerContext {
  final String? userId;
  final String lang;
  final Set<String> tags;
  /// True when receive / high-priority local stage is live.
  final bool highPriorityBusy;
  /// Milliseconds since home stage went idle (null if still active).
  final Duration? idleFor;

  const TheaterSchedulerContext({
    required this.userId,
    this.lang = 'pt',
    this.tags = const {},
    this.highPriorityBusy = false,
    this.idleFor,
  });
}

class TheaterSchedulerState {
  final int educationPresentedThisSession;
  final DateTime? lastEducationAt;
  final TheaterPieceFamily? lastFamily;

  const TheaterSchedulerState({
    this.educationPresentedThisSession = 0,
    this.lastEducationAt,
    this.lastFamily,
  });

  TheaterSchedulerState copyWith({
    int? educationPresentedThisSession,
    DateTime? lastEducationAt,
    TheaterPieceFamily? lastFamily,
  }) {
    return TheaterSchedulerState(
      educationPresentedThisSession:
          educationPresentedThisSession ?? this.educationPresentedThisSession,
      lastEducationAt: lastEducationAt ?? this.lastEducationAt,
      lastFamily: lastFamily ?? this.lastFamily,
    );
  }
}

String theaterPieceShownKey(String userId, String pieceId) =>
    'theater.edu.shown_at.$userId.$pieceId';

String theaterFamilyShownKey(String userId, TheaterPieceFamily family) =>
    'theater.edu.family_at.$userId.${family.name}';

/// Picks the next catalog piece or null if budget/cooldown/context block.
TheaterCatalogPiece? pickNextTheaterPiece({
  required SharedPreferences prefs,
  required TheaterSchedulerContext context,
  required TheaterSchedulerState session,
  TheaterSchedulerConfig config = const TheaterSchedulerConfig(),
  DateTime? now,
  List<TheaterCatalogPiece>? catalog,
}) {
  final clock = now ?? DateTime.now();
  final userId = context.userId;
  if (userId == null || userId.isEmpty) return null;
  if (context.highPriorityBusy) return null;

  if (session.educationPresentedThisSession >= config.maxEducationPerSession) {
    return null;
  }

  if (session.lastEducationAt != null &&
      clock.difference(session.lastEducationAt!) < config.minGapBetweenEducation) {
    return null;
  }

  final idle = context.idleFor;
  if (idle != null && idle < config.idleBeforeOffer) {
    return null;
  }

  final pieces = catalog ?? theaterCatalog;
  TheaterCatalogPiece? best;
  var bestScore = -1;

  for (final piece in pieces) {
    if (!_matchesContext(piece, context.tags)) continue;

    final shownRaw = prefs.getInt(theaterPieceShownKey(userId, piece.id));
    if (shownRaw != null) {
      final shown = DateTime.fromMillisecondsSinceEpoch(shownRaw);
      if (clock.difference(shown) < piece.cooldown) continue;
    }

    final famRaw = prefs.getInt(theaterFamilyShownKey(userId, piece.family));
    if (famRaw != null && piece.family == TheaterPieceFamily.learn) {
      final famAt = DateTime.fromMillisecondsSinceEpoch(famRaw);
      if (clock.difference(famAt) < config.familyCooldown) continue;
    }

    // Prefer pieces that match more context tags.
    var score = piece.priority;
    if (piece.contextTags.isNotEmpty) {
      final hits = piece.contextTags.intersection(context.tags).length;
      score += hits * 8;
    }
    // Slight freshness boost if never shown.
    if (shownRaw == null) score += 5;

    if (score > bestScore) {
      bestScore = score;
      best = piece;
    }
  }

  if (best != null && kDebugMode) {
    debugPrint(
      '[theaterScheduler] pick id=${best.id} family=${best.family.name} '
      'score=$bestScore session=${session.educationPresentedThisSession}',
    );
  }
  return best;
}

bool _matchesContext(TheaterCatalogPiece piece, Set<String> tags) {
  if (piece.contextTags.isEmpty) return true;
  // Cold-only tips require cold context.
  if (piece.contextTags.length == 1 && piece.contextTags.contains('cold')) {
    return tags.contains('cold');
  }
  // Otherwise soft: eligible everywhere; scoring boosts tag hits.
  return true;
}

Future<void> markTheaterPieceShown({
  required SharedPreferences prefs,
  required String userId,
  required TheaterCatalogPiece piece,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final ms = clock.millisecondsSinceEpoch;
  await prefs.setInt(theaterPieceShownKey(userId, piece.id), ms);
  await prefs.setInt(theaterFamilyShownKey(userId, piece.family), ms);
}
