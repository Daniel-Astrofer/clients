import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/network/api_client_provider.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/app_display_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';

/// Remote personalized feed with local fallback (always shows something).
///
/// Re-runs when the user authenticates so a failed anonymous/pre-login fetch
/// does not stick as an empty result after login.
final homeFeedProvider =
    FutureProvider.autoDispose<List<HomeFeedItem>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthAuthenticated) {
    return const [];
  }

  final view = ref.watch(homeLedgerBalanceViewProvider);
  final displayPrefs = ref.watch(appDisplayPreferencesProvider);
  // Keep TZ fresh when following the device (travel / DST).
  await ref
      .read(appDisplayPreferencesProvider.notifier)
      .refreshDeviceTimeZoneIfFollowing();
  final locale = displayPrefs.locale.languageCode;
  final timeZone = ref.read(appDisplayPreferencesProvider).timeZoneId;
  final balanceView = switch (view) {
    HomeLedgerBalanceView.platform => 'PLATFORM',
    HomeLedgerBalanceView.onChain => 'ONCHAIN',
    HomeLedgerBalanceView.cold => 'COLD',
    HomeLedgerBalanceView.total => 'TOTAL',
  };

  try {
    final client = ref.watch(apiClientProvider);
    // Always hit the network — feed is personalized and short-lived.
    final cacheOpts = CacheOptions(
      store: null,
      policy: CachePolicy.refresh,
    ).toOptions();
    final response = await client.get(
      AppConfig.contentHomeFeed(
        balanceView: balanceView,
        locale: locale,
        timeZone: timeZone,
      ),
      options: cacheOpts.copyWith(
        responseType: ResponseType.json,
        extra: cacheOpts.extra,
      ),
    );
    final payload = _extractFeedPayload(response.data);
    if (payload == null) {
      final raw = response.data;
      final preview =
          raw is String ? raw.substring(0, raw.length.clamp(0, 180)) : '$raw';
      // ignore: avoid_print
      print(
        '[homeFeed] unexpected payload type: ${raw.runtimeType} preview=$preview',
      );
      return const [];
    }
    final feed = HomeFeedResponse.fromJson(payload);
    if (feed.items.isNotEmpty) {
      // ignore: avoid_print
      print(
        '[homeFeed] remote ${feed.items.length} items '
        '(first=${feed.items.first.id})',
      );
      return feed.items;
    }
    // ignore: avoid_print
    print('[homeFeed] remote returned empty items');
  } catch (e, st) {
    // ignore: avoid_print
    print('[homeFeed] fetch failed: $e\n$st');
  }
  return const [];
});

/// ApiResponseInterceptor already unwraps `{ success, data }` → `data`.
/// Tolerate JSON strings, unwrapped feed maps, and still-wrapped envelopes.
Map<String, dynamic>? _extractFeedPayload(dynamic body) {
  dynamic current = body;

  // Dio/Tor/cache sometimes leave a JSON string body (known app pattern).
  for (var i = 0; i < 3; i++) {
    if (current is! String) break;
    final decoded = _tryDecodeJsonObject(current);
    if (decoded == null) return null;
    current = decoded;
  }

  if (current is! Map) return null;
  final root = Map<String, dynamic>.from(current);

  // Nested data may also still be a JSON string.
  dynamic nested = root['data'];
  if (nested is String) {
    nested = _tryDecodeJsonObject(nested);
  }

  if (nested is Map &&
      (nested.containsKey('items') || nested.containsKey('version'))) {
    return Map<String, dynamic>.from(nested);
  }

  // Unwrapped HomeFeedResponse.
  if (root.containsKey('items') || root.containsKey('version')) {
    return root;
  }

  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return root;
}

/// Best-effort JSON object decode (strips BOM / leading junk from proxies).
dynamic _tryDecodeJsonObject(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  // UTF-8 BOM
  if (text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1).trim();
  }
  // Some relays leave trailing noise — slice outer object/array.
  final objStart = text.indexOf('{');
  final arrStart = text.indexOf('[');
  int start = -1;
  if (objStart >= 0 && (arrStart < 0 || objStart < arrStart)) {
    start = objStart;
    final end = text.lastIndexOf('}');
    if (end > start) text = text.substring(start, end + 1);
  } else if (arrStart >= 0) {
    start = arrStart;
    final end = text.lastIndexOf(']');
    if (end > start) text = text.substring(start, end + 1);
  }
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

/// Cards ready for UI: remote feed or local catalog.
/// Always ensures card promos (Bronze/Metal/Gold) are visible even if the
/// remote catalog omits them or the request fails.
List<HomeFeedItem> resolveHomeFeedCards({
  required BuildContext context,
  required HomeLedgerBalanceView view,
  required List<HomeFeedItem>? remote,
}) {
  final localCards = _localCardPromos(view);
  if (remote != null && remote.isNotEmpty) {
    final hasCardPromo = remote.any(_isCardPromoItem);
    if (hasCardPromo) {
      return remote;
    }
    // Remote education arrived without card ads — prepend local promos.
    return [...localCards, ...remote];
  }
  return localEducationFallback(context, view);
}

bool _isCardPromoItem(HomeFeedItem item) {
  final id = item.id.toLowerCase();
  final campaign = (item.campaignId ?? '').toLowerCase();
  return id.contains('card') ||
      id.contains('kerosene-cards') ||
      campaign.contains('card') ||
      campaign.contains('kerosene-cards');
}

List<HomeFeedItem> localEducationFallback(
  BuildContext context,
  HomeLedgerBalanceView view,
) {
  final tr = context.tr;
  List<HomeFeedItem> three(
    String aId,
    String aIcon,
    String aTitle,
    String aBody,
    String aTag,
    String bId,
    String bIcon,
    String bTitle,
    String bBody,
    String bTag,
    String cId,
    String cIcon,
    String cTitle,
    String cBody,
    String cTag,
  ) {
    return [
      _local(aId, aIcon, aTitle, aBody, aTag),
      _local(bId, bIcon, bTitle, bBody, bTag),
      _local(cId, cIcon, cTitle, cBody, cTag),
    ];
  }

  final education = switch (view) {
    HomeLedgerBalanceView.platform => three(
        'local-internal',
        'internalTransfer',
        tr.homeEducationInternalTitle,
        tr.homeEducationInternalBody,
        tr.homeEducationInternalTag,
        'local-hash',
        'biometric',
        tr.homeEducationWalletHashTitle,
        tr.homeEducationWalletHashBody,
        tr.homeEducationWalletHashTag,
        'local-ln-p',
        'lightning',
        tr.homeEducationLightningTitle,
        tr.homeEducationLightningBody,
        tr.homeEducationLightningTag,
      ),
    HomeLedgerBalanceView.onChain => three(
        'local-onchain',
        'bitcoin',
        tr.homeEducationOnchainTitle,
        tr.homeEducationOnchainBody,
        tr.homeEducationOnchainTag,
        'local-conf',
        'sync',
        tr.homeEducationConfirmationsTitle,
        tr.homeEducationConfirmationsBody,
        tr.homeEducationConfirmationsTag,
        'local-fees',
        'gauge',
        tr.homeEducationFeesTitle,
        tr.homeEducationFeesBody,
        tr.homeEducationFeesTag,
      ),
    HomeLedgerBalanceView.cold => three(
        'local-cold',
        'bitcoin',
        tr.homeEducationOnchainTitle,
        tr.homeEducationOnchainBody,
        tr.homeEducationOnchainTag,
        'local-cold-conf',
        'sync',
        tr.homeEducationConfirmationsTitle,
        tr.homeEducationConfirmationsBody,
        tr.homeEducationConfirmationsTag,
        'local-cold-fees',
        'gauge',
        tr.homeEducationFeesTitle,
        tr.homeEducationFeesBody,
        tr.homeEducationFeesTag,
      ),
    HomeLedgerBalanceView.total => three(
        'local-btc',
        'bitcoin',
        tr.homeEducationBitcoinTitle,
        tr.homeEducationBitcoinBody,
        tr.homeEducationBitcoinTag,
        'local-ln',
        'lightning',
        tr.homeEducationLightningTitle,
        tr.homeEducationLightningGeneralBody,
        tr.homeEducationLightningGeneralTag,
        'local-kero',
        'wallet',
        tr.homeEducationInternalTitle,
        tr.homeEducationKeroseneGeneralBody,
        tr.homeEducationKeroseneGeneralTag,
      ),
  };

  // Card promos always available offline / when remote fails.
  // Prepended so they appear first in the carousel after a cold start.
  return [
    ..._localCardPromos(view),
    ...education,
  ];
}

/// Offline mirror of backend card catalog (Bronze / Metal / Gold).
List<HomeFeedItem> _localCardPromos(HomeLedgerBalanceView view) {
  // On-chain / cold surface: only the trio announcement (matches backend views).
  if (view == HomeLedgerBalanceView.onChain ||
      view == HomeLedgerBalanceView.cold) {
    return [
      _localCard(
        id: 'local-ann-kerosene-cards-trio',
        kind: HomeFeedKind.announcement,
        title: 'Cartões Kerosene',
        body:
            'Três níveis: Bronze, Metal e Gold. Cada cartão assegurado com taxas e aparência próprias.',
        tag: 'CARTÕES',
        asset: 'assets/feed/cards/trio.png',
      ),
    ];
  }

  return [
    _localCard(
      id: 'local-ann-kerosene-cards-trio',
      kind: HomeFeedKind.announcement,
      title: 'Cartões Kerosene',
      body:
          'Três níveis: Bronze, Metal e Gold. Cada cartão assegurado com taxas e aparência próprias.',
      tag: 'CARTÕES',
      asset: 'assets/feed/cards/trio.png',
    ),
    _localCard(
      id: 'local-feat-card-bronze',
      kind: HomeFeedKind.feature,
      title: 'Cartão Bronze',
      body:
          'Entrada na Conta Assegurada. Ideal para começar com transferências internas e on-chain.',
      tag: 'BRONZE',
      asset: 'assets/feed/cards/bronze.png',
    ),
    _localCard(
      id: 'local-feat-card-metal',
      kind: HomeFeedKind.feature,
      title: 'Cartão Metal',
      body:
          'Acabamento metálico premium. Taxas mais competitivas que o Bronze para uso frequente.',
      tag: 'METAL',
      asset: 'assets/feed/cards/metal.png',
    ),
    _localCard(
      id: 'local-feat-card-gold',
      kind: HomeFeedKind.feature,
      title: 'Cartão Gold',
      body:
          'Topo de linha: visual escuro com detalhes dourados e as menores taxas da linha assegurada.',
      tag: 'GOLD',
      asset: 'assets/feed/cards/gold.png',
    ),
  ];
}

HomeFeedItem _local(
  String id,
  String iconKey,
  String title,
  String body,
  String tag,
) {
  return HomeFeedItem(
    id: id,
    kind: HomeFeedKind.education,
    priority: 0,
    title: title,
    body: body,
    tag: tag,
    media: HomeFeedMedia(type: HomeFeedMediaType.icon, iconKey: iconKey),
  );
}

HomeFeedItem _localCard({
  required String id,
  required HomeFeedKind kind,
  required String title,
  required String body,
  required String tag,
  required String asset,
}) {
  final assetUrl = 'asset:$asset';
  return HomeFeedItem(
    id: id,
    kind: kind,
    priority: 130,
    title: title,
    body: body,
    tag: tag,
    media: HomeFeedMedia(
      type: HomeFeedMediaType.image,
      iconKey: 'creditCard',
      url: assetUrl,
      posterUrl: assetUrl,
      aspectRatio: 1.6,
    ),
    surfaceTint: 'TOTAL',
    campaignId: id,
  );
}
