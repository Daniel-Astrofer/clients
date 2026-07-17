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

/// Cards ready for the home education carousel.
///
/// PLATFORM / TOTAL: always the **3 tier cards** (Bronze / White / Black).
/// Remote copy (fees/rules) is preferred when the backend sends `edu-card-*`;
/// mock PNG promos and the old fixed 3 generic tips are not shown here.
/// ONCHAIN / COLD: remote network tips, else local on-chain fallback.
List<HomeFeedItem> resolveHomeFeedCards({
  required BuildContext context,
  required HomeLedgerBalanceView view,
  required List<HomeFeedItem>? remote,
}) {
  if (view == HomeLedgerBalanceView.platform ||
      view == HomeLedgerBalanceView.total) {
    return _resolveTierEducationCards(context, remote);
  }
  if (remote != null && remote.isNotEmpty) {
    // Drop legacy mock card product shots on non-platform views.
    final cleaned = remote.where((item) => !_isLegacyMockCardPromo(item)).toList();
    if (cleaned.isNotEmpty) return cleaned;
  }
  return localEducationFallback(context, view);
}

/// Exactly 3 EDUCATION tier items — remote text when present, else local defaults.
List<HomeFeedItem> _resolveTierEducationCards(
  BuildContext context,
  List<HomeFeedItem>? remote,
) {
  final local = _localCardTierEducation(context);
  if (remote == null || remote.isEmpty) return local;

  HomeFeedItem? pick(String code) {
    final needle = code.toLowerCase();
    for (final item in remote) {
      final id = item.id.toLowerCase();
      final tag = item.tag.toUpperCase();
      final campaign = (item.campaignId ?? '').toLowerCase();
      if (tag == code ||
          id.contains('edu-card-$needle') ||
          id.contains('card-$needle') ||
          (id.contains(needle) && id.contains('card')) ||
          (campaign.contains(needle) && campaign.contains('card'))) {
        // Keep remote title/body (backend fees) but force tag for 3D mapping.
        return HomeFeedItem(
          id: item.id,
          kind: HomeFeedKind.education,
          priority: item.priority,
          title: item.title,
          body: item.body,
          tag: code,
          media: item.media,
          cta: item.cta,
          surfaceTint: 'PLATFORM',
          campaignId: item.campaignId ?? item.id,
        );
      }
    }
    return null;
  }

  return [
    pick('BRONZE') ?? local[0],
    pick('WHITE') ?? local[1],
    pick('BLACK') ?? local[2],
  ];
}

bool _isLegacyMockCardPromo(HomeFeedItem item) {
  final id = item.id.toLowerCase();
  final campaign = (item.campaignId ?? '').toLowerCase();
  return id.contains('kerosene-cards-trio') ||
      id.contains('feat-card-metal') ||
      id.contains('feat-card-gold') ||
      id.contains('ann-kerosene-cards') ||
      campaign.contains('kerosene-cards-trio') ||
      (item.media.url?.contains('feed/cards/') ?? false);
}

List<HomeFeedItem> localEducationFallback(
  BuildContext context,
  HomeLedgerBalanceView view,
) {
  final tr = context.tr;
  // Offline mirror of backend tier education (BRONZE / WHITE / BLACK).
  // Prefer remote feed when online so fees and rules stay reactive.
  if (view == HomeLedgerBalanceView.platform ||
      view == HomeLedgerBalanceView.total) {
    return _localCardTierEducation(context);
  }

  // On-chain / cold: network tips only (no hard-coded platform tiers).
  return [
    _local(
      'local-onchain',
      'bitcoin',
      tr.homeEducationOnchainTitle,
      tr.homeEducationOnchainBody,
      tr.homeEducationOnchainTag,
    ),
    _local(
      'local-conf',
      'sync',
      tr.homeEducationConfirmationsTitle,
      tr.homeEducationConfirmationsBody,
      tr.homeEducationConfirmationsTag,
    ),
    _local(
      'local-fees',
      'gauge',
      tr.homeEducationFeesTitle,
      tr.homeEducationFeesBody,
      tr.homeEducationFeesTag,
    ),
  ];
}

/// Offline defaults matching backend wallet.card.* policy.
/// Keep in sync with `WalletCardTierCatalog` / application.properties.
List<HomeFeedItem> _localCardTierEducation(BuildContext context) {
  final lang = Localizations.localeOf(context).languageCode;
  return [
    _localTierCard(
      id: 'local-edu-card-bronze',
      priority: 200,
      title: switch (lang) {
        'en' => 'Bronze card',
        'es' => 'Tarjeta Bronze',
        _ => 'Cartão Bronze',
      },
      body: switch (lang) {
        'en' =>
          'Entry secured-account tier. External fee: 0.9%. Granted automatically to new accounts. Stay active longer and grow monthly volume to unlock lower tiers.',
        'es' =>
          'Nivel inicial de la cuenta asegurada. Comisión externa: 0.9%. Disponible automáticamente para cuentas nuevas. Gana antigüedad y volumen mensual para subir de nivel y pagar menos.',
        _ =>
          'Nível inicial da Conta Assegurada. Taxa externa: 0.9%. Disponível automaticamente para contas novas. Use a plataforma e aumente o tempo e a movimentação mensal para subir de nível e pagar menos.',
      },
      tag: 'BRONZE',
      asset: 'assets/feed/cards/bronze.png',
    ),
    _localTierCard(
      id: 'local-edu-card-white',
      priority: 199,
      title: switch (lang) {
        'en' => 'White card',
        'es' => 'Tarjeta White',
        _ => 'Cartão White',
      },
      body: switch (lang) {
        'en' =>
          'External deposit/withdrawal fee: 0.8%. How to unlock: monthly volume above 1,500 and at least 6 months of account age. The card upgrades automatically when rules are met.',
        'es' =>
          'Comisión de depósito/retiro externo: 0.8%. Cómo conseguirlo: volumen mensual superior a 1,500 y al menos 6 meses de cuenta. La tarjeta sube automáticamente al cumplir las reglas.',
        _ =>
          'Taxa de saque/depósito externo: 0.8%. Como conseguir: movimentação mensal acima de 1,500 e pelo menos 6 meses de conta. O cartão sobe automaticamente quando a conta atinge as regras.',
      },
      tag: 'WHITE',
      asset: 'assets/feed/cards/metal.png',
    ),
    _localTierCard(
      id: 'local-edu-card-black',
      priority: 198,
      title: switch (lang) {
        'en' => 'Black card',
        'es' => 'Tarjeta Black',
        _ => 'Cartão Black',
      },
      body: switch (lang) {
        'en' =>
          'Lowest platform fee: 0.7% on external deposits and withdrawals. How to unlock: monthly volume above 4,000 and at least 12 months of account age. Internal Kerosene transfers stay 0%.',
        'es' =>
          'Menor comisión de la plataforma: 0.7% en depósitos y retiros externos. Cómo conseguirlo: volumen mensual superior a 4,000 y al menos 12 meses de cuenta. Las transferencias internas Kerosene siguen en 0%.',
        _ =>
          'Menor taxa da plataforma: 0.7% em saques e depósitos externos. Como conseguir: movimentação mensal acima de 4,000 e pelo menos 12 meses de conta. Transferências internas entre usuários Kerosene continuam 0%.',
      },
      tag: 'BLACK',
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

HomeFeedItem _localTierCard({
  required String id,
  required int priority,
  required String title,
  required String body,
  required String tag,
  required String asset,
}) {
  // No mock PNG: FE renders a live 3D tier card from [tag] / appearance.
  return HomeFeedItem(
    id: id,
    kind: HomeFeedKind.education,
    priority: priority,
    title: title,
    body: body,
    tag: tag,
    media: HomeFeedMedia(
      type: HomeFeedMediaType.icon,
      iconKey: 'creditCard',
      aspectRatio: 1.6,
    ),
    surfaceTint: 'PLATFORM',
    campaignId: id,
  );
}
