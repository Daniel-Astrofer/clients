import 'package:equatable/equatable.dart';

enum HomeCommunicationSource { notification, stage, feed }

enum HomeCommunicationSeverity { info, success, warning, error }

enum HomeCommunicationStatus {
  informational,
  pending,
  processing,
  confirmed,
  failed,
  cancelled,
  expired,
  unknown,
}

enum HomeCommunicationPresentation {
  autoDismiss,
  persistUntilSeen,
  persistUntilAction,
  inlineOnly,
}

enum HomeCommunicationMediaType { none, icon, image, lottie, video }

class HomeCommunicationMedia extends Equatable {
  final HomeCommunicationMediaType type;
  final String? source;
  final String? poster;
  final double aspectRatio;
  final bool autoplay;
  final bool muted;
  final bool loop;

  const HomeCommunicationMedia({
    this.type = HomeCommunicationMediaType.none,
    this.source,
    this.poster,
    this.aspectRatio = 1,
    this.autoplay = false,
    this.muted = true,
    this.loop = false,
  });

  @override
  List<Object?> get props => [
        type,
        source,
        poster,
        aspectRatio,
        autoplay,
        muted,
        loop,
      ];
}

class HomeCommunicationAction extends Equatable {
  final String label;
  final String target;
  final bool destructive;

  const HomeCommunicationAction({
    required this.label,
    required this.target,
    this.destructive = false,
  });

  bool get isValid => label.trim().isNotEmpty && target.trim().isNotEmpty;

  @override
  List<Object?> get props => [label, target, destructive];
}

/// Common presentation contract for the Home stage, feed cards and session
/// notifications. Adapters keep the current wire models compatible while the
/// UI migrates to one prioritised communication pipeline.
class HomeCommunicationItem extends Equatable {
  final String id;
  final HomeCommunicationSource source;
  final int priority;
  final HomeCommunicationSeverity severity;
  final HomeCommunicationStatus status;
  final String title;
  final String body;
  final String? amount;
  final String? currency;
  final DateTime? timestamp;
  final DateTime? expiresAt;
  final String? entityType;
  final String? entityId;
  final String? dedupeKey;
  final HomeCommunicationMedia media;
  final HomeCommunicationAction? primaryAction;
  final HomeCommunicationAction? secondaryAction;
  final HomeCommunicationPresentation presentation;
  final bool read;

  const HomeCommunicationItem({
    required this.id,
    required this.source,
    required this.title,
    required this.body,
    this.amount,
    this.currency,
    this.priority = 0,
    this.severity = HomeCommunicationSeverity.info,
    this.status = HomeCommunicationStatus.informational,
    this.timestamp,
    this.expiresAt,
    this.entityType,
    this.entityId,
    this.dedupeKey,
    this.media = const HomeCommunicationMedia(),
    this.primaryAction,
    this.secondaryAction,
    this.presentation = HomeCommunicationPresentation.autoDismiss,
    this.read = false,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get requiresAction =>
      presentation == HomeCommunicationPresentation.persistUntilAction;

  String get stableKey {
    if (dedupeKey != null && dedupeKey!.trim().isNotEmpty) {
      return dedupeKey!.trim();
    }
    if (entityType != null && entityId != null) {
      return '$source|$entityType|$entityId';
    }
    return '$source|$id';
  }

  @override
  List<Object?> get props => [
        id,
        source,
        priority,
        severity,
        status,
        title,
        body,
        amount,
        currency,
        timestamp,
        expiresAt,
        entityType,
        entityId,
        dedupeKey,
        media,
        primaryAction,
        secondaryAction,
        presentation,
        read,
      ];
}
