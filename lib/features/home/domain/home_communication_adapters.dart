import 'package:kerosene/features/home/domain/entities/home_communication_item.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

HomeCommunicationItem communicationFromNotification(
  SessionNotificationItem item,
) {
  final severity = switch (item.severity) {
    SessionNotificationItem.severitySuccess =>
      HomeCommunicationSeverity.success,
    SessionNotificationItem.severityWarning =>
      HomeCommunicationSeverity.warning,
    SessionNotificationItem.severityError => HomeCommunicationSeverity.error,
    _ => HomeCommunicationSeverity.info,
  };
  final status = _statusFromNotification(item);
  final action = item.isActionable
      ? HomeCommunicationAction(
          label: item.metadata['cta'] ?? 'Ver detalhes',
          target: item.deeplink!.trim(),
        )
      : null;
  return HomeCommunicationItem(
    id: item.id,
    source: HomeCommunicationSource.notification,
    priority: item.presentationPriority,
    severity: severity,
    status: status,
    title: item.title,
    body: item.body,
    amount: item.metadata['amount'] ??
        item.metadata['amountBtc'] ??
        item.metadata['amountSats'],
    currency: item.metadata['currency'] ?? item.metadata['ticker'],
    timestamp: item.timestamp,
    entityType: item.entityType,
    entityId: item.entityId,
    dedupeKey: item.dedupeKey,
    primaryAction: action,
    presentation: switch (item.presentationPolicy) {
      NotificationPresentationPolicy.persistUntilAction =>
        HomeCommunicationPresentation.persistUntilAction,
      NotificationPresentationPolicy.persistUntilSeen =>
        HomeCommunicationPresentation.persistUntilSeen,
      NotificationPresentationPolicy.autoDismiss =>
        HomeCommunicationPresentation.autoDismiss,
    },
    read: item.read,
  );
}

HomeCommunicationItem communicationFromStage(HomeStage stage) {
  final media = stage.media;
  return HomeCommunicationItem(
    id: stage.id,
    source: HomeCommunicationSource.stage,
    priority: stage.priority,
    title: stage.content.title,
    body: stage.content.body ?? '',
    media: HomeCommunicationMedia(
      type: _mediaTypeFromStage(media.type),
      source: media.url,
      poster: media.posterUrl,
      aspectRatio: media.aspectRatio,
      autoplay: media.autoplay,
      muted: media.muted,
      loop: media.loop,
    ),
    primaryAction: stage.content.cta?.isNavigate == true
        ? HomeCommunicationAction(
            label: stage.content.cta!.label,
            target: stage.content.cta!.target,
          )
        : null,
    presentation: stage.playPolicy == HomeStagePlayPolicy.once
        ? HomeCommunicationPresentation.persistUntilSeen
        : HomeCommunicationPresentation.autoDismiss,
  );
}

HomeCommunicationItem communicationFromFeed(HomeFeedItem item) {
  final media = item.media;
  return HomeCommunicationItem(
    id: item.id,
    source: HomeCommunicationSource.feed,
    priority: item.priority,
    title: item.title,
    body: item.body,
    media: HomeCommunicationMedia(
      type: _mediaTypeFromFeed(media.type),
      source: media.url,
      poster: media.posterUrl,
      aspectRatio: media.aspectRatio,
      muted: true,
    ),
    primaryAction: item.cta?.isNavigate == true
        ? HomeCommunicationAction(
            label: item.cta!.label,
            target: item.cta!.target,
          )
        : null,
    presentation: HomeCommunicationPresentation.inlineOnly,
  );
}

HomeCommunicationStatus _statusFromNotification(
  SessionNotificationItem item,
) {
  final raw = (item.metadata['status'] ?? '').trim().toLowerCase();
  return switch (raw) {
    'pending' || 'awaiting_confirmation' => HomeCommunicationStatus.pending,
    'processing' => HomeCommunicationStatus.processing,
    'confirmed' ||
    'complete' ||
    'completed' =>
      HomeCommunicationStatus.confirmed,
    'failed' || 'error' => HomeCommunicationStatus.failed,
    'cancelled' || 'canceled' => HomeCommunicationStatus.cancelled,
    'expired' => HomeCommunicationStatus.expired,
    _ => item.severity == SessionNotificationItem.severityError
        ? HomeCommunicationStatus.failed
        : HomeCommunicationStatus.informational,
  };
}

HomeCommunicationMediaType _mediaTypeFromStage(HomeStageMediaType type) =>
    switch (type) {
      HomeStageMediaType.icon => HomeCommunicationMediaType.icon,
      HomeStageMediaType.image => HomeCommunicationMediaType.image,
      HomeStageMediaType.lottie => HomeCommunicationMediaType.lottie,
      HomeStageMediaType.video => HomeCommunicationMediaType.video,
      _ => HomeCommunicationMediaType.none,
    };

HomeCommunicationMediaType _mediaTypeFromFeed(HomeFeedMediaType type) =>
    switch (type) {
      HomeFeedMediaType.icon => HomeCommunicationMediaType.icon,
      HomeFeedMediaType.image => HomeCommunicationMediaType.image,
      HomeFeedMediaType.lottie => HomeCommunicationMediaType.lottie,
      HomeFeedMediaType.video => HomeCommunicationMediaType.video,
      _ => HomeCommunicationMediaType.none,
    };
