import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_communication_item.dart';
import 'package:kerosene/features/home/domain/home_communication_adapters.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

void main() {
  test('notification adapter preserves financial priority and action policy',
      () {
    final item = communicationFromNotification(
      SessionNotificationItem(
        id: 'tx-1',
        title: 'Pagamento pendente',
        body: 'Aguardando confirmação.',
        timestamp: DateTime(2026, 9, 26),
        kind: SessionNotificationItem.kindPaymentSent,
        severity: SessionNotificationItem.severityWarning,
        deeplink: '/activity/tx-1',
        entityType: 'transaction',
        entityId: 'tx-1',
        metadata: const {
          'status': 'pending',
          'amountBtc': '0.01000000',
          'currency': 'BTC',
        },
      ),
    );

    expect(item.source, HomeCommunicationSource.notification);
    expect(item.status, HomeCommunicationStatus.pending);
    expect(item.priority, greaterThan(200));
    expect(item.requiresAction, isTrue);
    expect(item.primaryAction?.target, '/activity/tx-1');
    expect(item.amount, '0.01000000');
    expect(item.currency, 'BTC');
  });

  test('stage adapter preserves video policy and navigation action', () {
    final stage = HomeStage(
      id: 'stage-video',
      kind: HomeStageKind.feature,
      playPolicy: HomeStagePlayPolicy.once,
      content: const HomeStageContent(
        title: 'Nova proteção',
        body: 'Ative a proteção da conta.',
        cta: HomeStageCta(
          label: 'Configurar',
          action: 'NAVIGATE',
          target: '/settings/security',
        ),
      ),
      media: const HomeStageMedia(
        type: HomeStageMediaType.video,
        url: 'https://cdn.example/video.mp4',
        posterUrl: 'https://cdn.example/poster.jpg',
        aspectRatio: 16 / 9,
        autoplay: false,
        muted: true,
      ),
    );
    final item = communicationFromStage(stage);

    expect(item.media.type, HomeCommunicationMediaType.video);
    expect(item.media.poster, contains('poster.jpg'));
    expect(item.media.autoplay, isFalse);
    expect(item.primaryAction?.target, '/settings/security');
    expect(item.presentation, HomeCommunicationPresentation.persistUntilSeen);
  });

  test('feed adapter remains inline-only and keeps CTA media', () {
    final feed = HomeFeedItem(
      id: 'promo-1',
      kind: HomeFeedKind.promo,
      priority: 120,
      title: 'Proteja sua conta',
      body: 'Use uma passkey.',
      tag: 'SECURITY',
      media: const HomeFeedMedia(
        type: HomeFeedMediaType.video,
        url: 'https://cdn.example/promo.mp4',
        posterUrl: 'https://cdn.example/promo.jpg',
      ),
      cta: const HomeFeedCta(
        label: 'Ativar',
        action: 'NAVIGATE',
        target: '/settings/security',
      ),
    );
    final item = communicationFromFeed(feed);

    expect(item.presentation, HomeCommunicationPresentation.inlineOnly);
    expect(item.media.type, HomeCommunicationMediaType.video);
    expect(item.primaryAction?.isValid, isTrue);
  });
}
