import 'package:flutter/material.dart';
import 'package:kerosene/design_system/icons.dart';

enum HomeFeedKind { education, announcement, promo, feature, unknown }

enum HomeFeedMediaType { icon, image, lottie, video, unknown }

class HomeFeedMedia {
  final HomeFeedMediaType type;
  final String? iconKey;
  final String? url;
  final String? posterUrl;
  final double aspectRatio;

  const HomeFeedMedia({
    required this.type,
    this.iconKey,
    this.url,
    this.posterUrl,
    this.aspectRatio = 1,
  });

  factory HomeFeedMedia.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HomeFeedMedia(type: HomeFeedMediaType.icon, iconKey: 'info');
    }
    final type = switch ((json['type'] ?? '').toString().toUpperCase()) {
      'IMAGE' => HomeFeedMediaType.image,
      'LOTTIE' => HomeFeedMediaType.lottie,
      'VIDEO' => HomeFeedMediaType.video,
      'ICON' => HomeFeedMediaType.icon,
      _ => HomeFeedMediaType.icon,
    };
    final aspectRaw = json['aspectRatio'];
    final aspect = aspectRaw is num
        ? aspectRaw.toDouble()
        : double.tryParse(aspectRaw?.toString() ?? '') ?? 1;
    return HomeFeedMedia(
      type: type,
      iconKey: json['iconKey']?.toString(),
      url: json['url']?.toString(),
      posterUrl: json['posterUrl']?.toString(),
      aspectRatio: aspect,
    );
  }

  IconData resolveIcon() {
    return switch ((iconKey ?? '').trim()) {
      'internalTransfer' => KeroseneIcons.internalTransfer,
      'biometric' => KeroseneIcons.biometric,
      'lightning' => KeroseneIcons.lightning,
      'bitcoin' => KeroseneIcons.bitcoin,
      'sync' => KeroseneIcons.sync,
      'gauge' => KeroseneIcons.gauge,
      'wallet' => KeroseneIcons.wallet,
      'verified' => KeroseneIcons.verified,
      'play' => KeroseneIcons.next,
      'info' => KeroseneIcons.info,
      'creditCard' => KeroseneIcons.creditCard,
      _ => KeroseneIcons.info,
    };
  }
}

class HomeFeedCta {
  final String label;
  final String action;
  final String target;

  const HomeFeedCta({
    required this.label,
    required this.action,
    required this.target,
  });

  factory HomeFeedCta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HomeFeedCta(label: '', action: 'NONE', target: '');
    }
    return HomeFeedCta(
      label: (json['label'] ?? '').toString(),
      action: (json['action'] ?? 'NONE').toString(),
      target: (json['target'] ?? '').toString(),
    );
  }

  bool get isNavigate => action.toUpperCase() == 'NAVIGATE' && target.isNotEmpty;
}

class HomeFeedItem {
  final String id;
  final HomeFeedKind kind;
  final int priority;
  final String title;
  final String body;
  final String tag;
  final HomeFeedMedia media;
  final HomeFeedCta? cta;
  final String surfaceTint;
  final String? campaignId;

  const HomeFeedItem({
    required this.id,
    required this.kind,
    required this.priority,
    required this.title,
    required this.body,
    required this.tag,
    required this.media,
    this.cta,
    this.surfaceTint = 'TOTAL',
    this.campaignId,
  });

  factory HomeFeedItem.fromJson(Map<String, dynamic> json) {
    final kind = switch ((json['kind'] ?? '').toString().toUpperCase()) {
      'EDUCATION' => HomeFeedKind.education,
      'ANNOUNCEMENT' => HomeFeedKind.announcement,
      'PROMO' => HomeFeedKind.promo,
      'FEATURE' => HomeFeedKind.feature,
      _ => HomeFeedKind.unknown,
    };
    final mediaRaw = json['media'];
    final ctaRaw = json['cta'];
    final priorityRaw = json['priority'];
    final priority = priorityRaw is num
        ? priorityRaw.toInt()
        : int.tryParse(priorityRaw?.toString() ?? '') ?? 0;
    return HomeFeedItem(
      id: (json['id'] ?? '').toString(),
      kind: kind,
      priority: priority,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      tag: (json['tag'] ?? '').toString(),
      media: HomeFeedMedia.fromJson(
        mediaRaw is Map ? Map<String, dynamic>.from(mediaRaw) : null,
      ),
      cta: ctaRaw is Map
          ? HomeFeedCta.fromJson(Map<String, dynamic>.from(ctaRaw))
          : null,
      surfaceTint: (json['surfaceTint'] ?? 'TOTAL').toString(),
      campaignId: json['campaignId']?.toString(),
    );
  }
}

class HomeFeedResponse {
  final String version;
  final int ttlSeconds;
  final String balanceView;
  final String locale;
  final String timeZone;
  final List<HomeFeedItem> items;

  const HomeFeedResponse({
    required this.version,
    required this.ttlSeconds,
    required this.balanceView,
    required this.locale,
    this.timeZone = 'UTC',
    required this.items,
  });

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final ttlRaw = json['ttlSeconds'];
    final ttl = ttlRaw is num
        ? ttlRaw.toInt()
        : int.tryParse(ttlRaw?.toString() ?? '') ?? 300;
    return HomeFeedResponse(
      version: (json['version'] ?? '').toString(),
      ttlSeconds: ttl,
      balanceView: (json['balanceView'] ?? 'TOTAL').toString(),
      locale: (json['locale'] ?? 'pt').toString(),
      timeZone: (json['timeZone'] ?? json['timezone'] ?? 'UTC').toString(),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => HomeFeedItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
    );
  }
}
