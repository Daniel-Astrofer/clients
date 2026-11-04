import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
// architecture-allow-large-file: transaction card states and interaction
// choreography remain co-located to preserve the existing widget API.
import 'activity_actions.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_party_display.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_glyph.dart';
import 'package:kerosene/features/movement/presentation/activity/home_activity_surface.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_palette.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

enum StatementTransactionCardMode { stacked, separated }

/// How much chrome the card carries.
///
/// - [home]: quick scan only — glyph + amount; expand is just actions + "details".
/// - [full]: extrato — can show field table when expanded.
enum StatementTransactionCardDensity { home, full }

/// Cached home-row presentation — avoids recomputing labels on every scroll frame.
final class _HomeStatementSnapshot {
  final TransactionPresentation presentation;
  final TransactionCardColors colors;

  const _HomeStatementSnapshot({
    required this.presentation,
    required this.colors,
  });
}

const _homeStatementSnapshotCacheMax = 96;
typedef _HomeStatementKey = ({
  Transaction transaction,
  Currency currency,
  Locale locale,
  int decimals,
  double? usd,
  double? eur,
  double? brl,
  String walletLabels,
  int minute
});
final _homeStatementSnapshotCache =
    <_HomeStatementKey, _HomeStatementSnapshot>{};

bool _fiatRateReady(
  Currency currency,
  double? btcUsd,
  double? btcEur,
  double? btcBrl,
) {
  return switch (currency) {
    Currency.btc => true,
    Currency.usd => (btcUsd ?? 0) > 0,
    Currency.eur => (btcEur ?? 0) > 0,
    Currency.brl => (btcBrl ?? 0) > 0,
  };
}

_HomeStatementKey _homeSnapshotKey(
        Transaction tx,
        Currency currency,
        Locale locale,
        int decimals,
        double? usd,
        double? eur,
        double? brl,
        List<Wallet> wallets,
        List<BitcoinAccount> accounts) =>
    (
      transaction: tx,
      currency: currency,
      locale: locale,
      decimals: decimals,
      usd: usd,
      eur: eur,
      brl: brl,
      walletLabels: jsonEncode([
        for (final wallet in wallets)
          [wallet.id, wallet.name, wallet.walletMode, wallet.type.name],
        for (final account in accounts)
          [
            account.id,
            account.label,
            account.type,
            account.custody,
            account.status
          ],
      ]),
      minute: DateTime.now().millisecondsSinceEpoch ~/ 60000,
    );

void _pruneHomeSnapshotCache() {
  while (_homeStatementSnapshotCache.length > _homeStatementSnapshotCacheMax) {
    _homeStatementSnapshotCache.remove(_homeStatementSnapshotCache.keys.first);
  }
}

String _homePartyLabel(
  BuildContext context,
  Transaction transaction,
  TransactionPresentation presentation,
  List<Wallet> wallets,
  List<BitcoinAccount> accounts,
) {
  String? clean(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      return null;
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('de ')) value = value.substring(3).trim();
    if (lower.startsWith('from ')) value = value.substring(5).trim();
    if (lower.startsWith('para ')) value = value.substring(5).trim();
    if (lower.startsWith('to ')) value = value.substring(3).trim();
    if (value.isEmpty) return null;

    final normalized = value.toLowerCase();
    // These are rail fallbacks, not people or addresses. Home should never
    // spend the party line on a generic "Bitcoin network" label.
    if (normalized.contains('rede bitcoin') ||
        normalized.contains('bitcoin network') ||
        normalized.contains('on-chain') ||
        normalized.contains('onchain') ||
        normalized.contains('endereço externo') ||
        normalized.contains('external address') ||
        normalized == 'destino' ||
        normalized == 'origem') {
      return null;
    }
    return looksLikeOnchainAddress(value) ? shortenHash(value) : value;
  }

  final direct = transaction.isCredit
      ? <String?>[
          transaction.counterpartyLabel,
          transaction.senderDisplayName,
          transaction.fromAddress,
          transaction.sourceWalletLabel,
          transaction.blockchainTxid,
          transaction.id,
        ]
      : <String?>[
          transaction.counterpartyLabel,
          transaction.receiverDisplayName,
          transaction.destinationWalletLabel,
          transaction.toAddress,
          transaction.externalReference,
          transaction.blockchainTxid,
          transaction.id,
        ];
  for (final candidate in direct) {
    final resolved = clean(candidate ?? '');
    if (resolved != null) return resolved;
  }

  final resolvedParty = transaction.isCredit
      ? resolveTransactionFromParty(
          transaction,
          wallets: wallets,
          accounts: accounts,
          languageCode: Localizations.localeOf(context).languageCode,
        )
      : resolveTransactionToParty(
          transaction,
          wallets: wallets,
          accounts: accounts,
          compactHash: true,
          languageCode: Localizations.localeOf(context).languageCode,
        );
  return clean(resolvedParty) ?? clean(presentation.subtitle) ?? '—';
}

String _trimAmountTrailingZeros(String amount) {
  final trimmedDecimals = amount.replaceAllMapped(
    RegExp(r'([.,]\d*?[1-9])0+(?=\s|[^\d]|$)'),
    (match) => match.group(1)!,
  );
  return trimmedDecimals.replaceAllMapped(
    RegExp(r'[.,]0+(?=\s|[^\d]|$)'),
    (match) => '',
  );
}

String _abbreviateHash(String hash) {
  final trimmed = hash.trim();
  if (trimmed.length <= 14) return trimmed;
  return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 6)}';
}

bool _looksLikeHashOrAddress(String text) {
  final clean = text.trim();
  if (clean.length < 10) return false;
  final lower = clean.toLowerCase();
  if (lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('bcrt1') ||
      lower.startsWith('lnbc') ||
      lower.startsWith('lntb') ||
      lower.startsWith('lnbcrt') ||
      lower.startsWith('1') ||
      lower.startsWith('3') ||
      lower.startsWith('2') ||
      lower.startsWith('0x')) {
    return true;
  }
  if (RegExp(r'^[0-9a-fA-F]{16,}$').hasMatch(clean)) {
    return true;
  }
  return false;
}

bool _isGenericNetworkWord(String text) {
  final valLower = text.toLowerCase().trim();
  if (valLower.isEmpty || valLower == '—') return true;
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(valLower)) {
    return true;
  }
  return valLower.contains('rede bitcoin') ||
      valLower.contains('bitcoin network') ||
      valLower.contains('on-chain') ||
      valLower.contains('onchain') ||
      valLower.contains('lightning') ||
      valLower.contains('endereço externo') ||
      valLower.contains('external address') ||
      valLower.contains('link de pagamento') ||
      valLower.contains('link de cobrança') ||
      valLower.contains('payment link') ||
      valLower.contains('pagador') ||
      valLower.contains('payer') ||
      valLower.contains('recebimento') ||
      valLower.contains('carteira receptora') ||
      valLower.contains('carteira') ||
      valLower.contains('minha carteira') ||
      valLower.contains('depósito') ||
      valLower.contains('deposito') ||
      valLower == 'destino' ||
      valLower == 'origem' ||
      valLower == 'kerosene';
}

String? _resolvePayerHash(Transaction tx) {
  // 1. Direct fromAddress if it's a real address or hash
  final from = tx.fromAddress.trim();
  if (from.isNotEmpty &&
      !_isGenericNetworkWord(from) &&
      (looksLikeOnchainAddress(from) || _looksLikeHashOrAddress(from))) {
    return _abbreviateHash(from);
  }

  // 2. Blockchain txid (hash da transação que pagou)
  final txid = tx.blockchainTxid?.trim();
  if (txid != null && txid.isNotEmpty && txid != '—') {
    return _abbreviateHash(txid);
  }

  // 3. Lightning payment hash
  final ph = tx.paymentHash?.trim();
  if (ph != null && ph.isNotEmpty && ph != '—') {
    return _abbreviateHash(ph);
  }

  // 4. External reference (txid, hash or address)
  final ext = tx.externalReference?.trim();
  if (ext != null &&
      ext.isNotEmpty &&
      ext != '—' &&
      !_isGenericNetworkWord(ext) &&
      (looksLikeOnchainAddress(ext) || _looksLikeHashOrAddress(ext))) {
    return _abbreviateHash(ext);
  }

  // 5. Receiving/deposit address of the link
  final to = tx.toAddress.trim();
  if (to.isNotEmpty &&
      to != '—' &&
      !_isGenericNetworkWord(to) &&
      (looksLikeOnchainAddress(to) || _looksLikeHashOrAddress(to))) {
    return _abbreviateHash(to);
  }

  return null;
}

String _resolveDestinationTitle(
  Transaction tx,
  String subtitle,
  String defaultTitle,
) {
  // If it's a payment link, prioritize the hash address of who paid
  if (tx.isPaymentLink) {
    final directSender = tx.senderDisplayName?.trim();
    if (directSender != null &&
        directSender.isNotEmpty &&
        directSender != '—' &&
        !_isGenericNetworkWord(directSender) &&
        looksLikeUsername(directSender)) {
      return directSender;
    }

    final payerHash = _resolvePayerHash(tx);
    if (payerHash != null && payerHash.isNotEmpty) {
      return payerHash;
    }
  }

  final directName =
      (tx.isCredit ? tx.senderDisplayName : tx.receiverDisplayName)?.trim();
  if (directName != null &&
      directName.isNotEmpty &&
      directName != '—' &&
      !_isGenericNetworkWord(directName)) {
    return directName;
  }

  final label = tx.counterpartyLabel?.trim();
  if (label != null &&
      label.isNotEmpty &&
      label != '—' &&
      !_isGenericNetworkWord(label)) {
    return label;
  }

  var clean = subtitle.trim();
  final lower = clean.toLowerCase();
  if (lower.startsWith('para: ')) {
    clean = clean.substring(6).trim();
  } else if (lower.startsWith('para ')) {
    clean = clean.substring(5).trim();
  } else if (lower.startsWith('de: ')) {
    clean = clean.substring(4).trim();
  } else if (lower.startsWith('de ')) {
    clean = clean.substring(3).trim();
  } else if (lower.startsWith('to: ')) {
    clean = clean.substring(4).trim();
  } else if (lower.startsWith('to ')) {
    clean = clean.substring(3).trim();
  } else if (lower.startsWith('from: ')) {
    clean = clean.substring(6).trim();
  } else if (lower.startsWith('from ')) {
    clean = clean.substring(5).trim();
  }

  if (clean.isNotEmpty &&
      clean != '—' &&
      !_isGenericNetworkWord(clean)) {
    if (_looksLikeHashOrAddress(clean) || looksLikeOnchainAddress(clean)) {
      return _abbreviateHash(clean);
    }
    return clean;
  }

  final address = (tx.isCredit ? tx.fromAddress : tx.toAddress).trim();
  if (address.isNotEmpty &&
      address != '—' &&
      !_isGenericNetworkWord(address)) {
    return _abbreviateHash(address);
  }

  final txid = tx.blockchainTxid?.trim();
  if (txid != null && txid.isNotEmpty && txid != '—') {
    return _abbreviateHash(txid);
  }

  final paymentHash = tx.paymentHash?.trim();
  if (paymentHash != null && paymentHash.isNotEmpty && paymentHash != '—') {
    return _abbreviateHash(paymentHash);
  }

  final ext = tx.externalReference?.trim();
  if (ext != null &&
      ext.isNotEmpty &&
      ext != '—' &&
      !_isGenericNetworkWord(ext) &&
      (_looksLikeHashOrAddress(ext) || looksLikeOnchainAddress(ext))) {
    return _abbreviateHash(ext);
  }

  if (tx.isCredit) {
    final toAddr = tx.toAddress.trim();
    if (toAddr.isNotEmpty &&
        toAddr != '—' &&
        !_isGenericNetworkWord(toAddr)) {
      return _abbreviateHash(toAddr);
    }
  }

  final desc = tx.description?.trim();
  if (desc != null &&
      desc.isNotEmpty &&
      desc != '—' &&
      !_isGenericNetworkWord(desc)) {
    return desc;
  }

  return defaultTitle;
}

String _resolveNetwork(Transaction tx) {
  if (tx.isLightningEffective || tx.isLightning) {
    return 'Lightning';
  }
  return 'Onchain';
}

String _formatTimeAndWeekday(BuildContext context, DateTime timestamp) {
  final local = AppDateTime.inDisplayZone(context, timestamp);
  final lang = AppDateTime.languageCodeOf(context);
  final use24 = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? true;
  final timePattern = use24 ? 'HH:mm' : 'h:mm a';
  final timeStr = DateFormat(timePattern, lang).format(local);
  final weekdayStr = DateFormat('EEEE', lang).format(local);
  return '$timeStr $weekdayStr';
}

Widget _buildDualFontText({
  required String text,
  required TextStyle letterStyle,
  required TextStyle numberStyle,
  TextAlign textAlign = TextAlign.start,
  int maxLines = 1,
  TextOverflow overflow = TextOverflow.ellipsis,
}) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'([+-]?\d[\d.,:+/-]*)');
  var lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: letterStyle,
      ));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: numberStyle,
    ));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: letterStyle,
    ));
  }

  return Text.rich(
    TextSpan(children: spans),
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

_HomeStatementSnapshot _resolveHomeSnapshot({
  required BuildContext context,
  required Transaction transaction,
  required List<Wallet> wallets,
  required List<BitcoinAccount> accounts,
  required Currency currency,
  required Locale locale,
  required int btcDecimalPlaces,
  required double? btcUsd,
  required double? btcEur,
  required double? btcBrl,
}) {
  final key = _homeSnapshotKey(transaction, currency, locale, btcDecimalPlaces,
      btcUsd, btcEur, btcBrl, wallets, accounts);
  final hit = _homeStatementSnapshotCache.remove(key);
  if (hit != null) {
    _homeStatementSnapshotCache[key] = hit;
    return hit;
  }

  final presentation = TransactionPresentation.fromTransaction(
    context,
    transaction,
    wallets: wallets,
    accounts: accounts,
    displayCurrency: currency,
    btcUsd: btcUsd,
    btcEur: btcEur,
    btcBrl: btcBrl,
    appLocale: locale,
    btcDecimalPlaces: btcDecimalPlaces,
    includeExpandPayload: false,
  );
  final colors = TransactionCardColors.resolve(
    transaction,
    wallets: wallets,
    accounts: accounts,
  );
  final snap = _HomeStatementSnapshot(
    presentation: presentation,
    colors: colors,
  );
  _homeStatementSnapshotCache[key] = snap;
  _pruneHomeSnapshotCache();
  return snap;
}

/// Vertical list of statement cards. Expansion only grows downward so cards
/// below are pushed away; multiple cards may stay expanded at once.
class StatementTransactionScrollStack extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemGap;

  /// Kept for call-site compatibility; layout no longer uses fixed extents.
  final double itemExtent;
  final double expandedItemExtent;
  final double stackGap;
  final double topAnchorOffset;
  final double collapseStartFraction;
  final int? expandedIndex;
  final Set<int>? expandedIndices;

  const StatementTransactionScrollStack({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent = 172,
    this.expandedItemExtent = 360,
    this.itemGap = 12,
    this.stackGap = 112,
    this.topAnchorOffset = 10,
    this.collapseStartFraction = 0.75,
    this.expandedIndex,
    this.expandedIndices,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    // Each row is its own repaint layer so scrolling only dirty-paints
    // the cards that move into view (Column still lays out all children,
    // but avoids full-stack recomposite on every tick).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          if (index > 0) SizedBox(height: itemGap),
          RepaintBoundary(child: itemBuilder(context, index)),
        ],
      ],
    );
  }
}

class StatementTransactionCard extends ConsumerStatefulWidget {
  final Transaction transaction;
  final bool expanded;
  final VoidCallback? onTap;
  final StatementTransactionCardMode mode;
  final StatementTransactionCardDensity density;

  const StatementTransactionCard({
    super.key,
    required this.transaction,
    this.expanded = false,
    this.onTap,
    this.mode = StatementTransactionCardMode.stacked,
    this.density = StatementTransactionCardDensity.full,
  });

  @override
  ConsumerState<StatementTransactionCard> createState() =>
      _StatementTransactionCardState();
}

class _StatementTransactionCardState
    extends ConsumerState<StatementTransactionCard> {
  Transaction? _accepted;
  String? _acceptedScope;
  Transaction get transaction {
    final accepted = _accepted;
    if (accepted == null ||
        accepted.id != widget.transaction.id ||
        _acceptedScope != ref.read(sessionStorageScopeProvider) ||
        widget.transaction.effectiveUpdatedAt
            .isAfter(accepted.effectiveUpdatedAt)) {
      return widget.transaction;
    }
    return accepted;
  }

  bool get expanded => widget.expanded;
  VoidCallback? get onTap => widget.onTap;
  StatementTransactionCardMode get mode => widget.mode;
  StatementTransactionCardDensity get density => widget.density;
  void _accept(Transaction next) {
    if (!mounted) return;
    setState(() {
      _accepted = next;
      _acceptedScope = ref.read(sessionStorageScopeProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    final isHome = density == StatementTransactionCardDensity.home;
    final money = ref.watch(moneyFormatConfigProvider);
    final selectedCurrency = money.currency;
    // Home observes the selected quote and preferences. Unrelated price ticks
    // do not rebuild a BTC row, and a valid changing quote cannot stay stale.
    final btcUsd = !isHome || selectedCurrency == Currency.usd
        ? ref.watch(latestBtcPriceProvider)
        : null;
    final btcEur = !isHome || selectedCurrency == Currency.eur
        ? ref.watch(btcEurPriceProvider)
        : null;
    final btcBrl = !isHome || selectedCurrency == Currency.brl
        ? ref.watch(btcBrlPriceProvider)
        : null;
    // Prefer BTC until the selected fiat rate exists — never flash +R$ 0,00.
    final displayCurrency = (isHome &&
            !_fiatRateReady(selectedCurrency, btcUsd, btcEur, btcBrl) &&
            transaction.amountSatoshis != 0)
        ? Currency.btc
        : selectedCurrency;
    final wallets = isHome ? _walletsFromRefRead(ref) : _walletsFromRef(ref);
    final accounts = isHome ? _accountsFromRefRead(ref) : _accountsFromRef(ref);

    final TransactionPresentation presentation;
    final TransactionCardColors resolvedColors;
    if (isHome && !expanded) {
      final snap = _resolveHomeSnapshot(
        context: context,
        transaction: transaction,
        wallets: wallets,
        accounts: accounts,
        currency: displayCurrency,
        locale: money.locale,
        btcDecimalPlaces: money.btcDecimalPlaces,
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
      );
      presentation = snap.presentation;
      resolvedColors = snap.colors;
    } else {
      presentation = TransactionPresentation.fromTransaction(
        context,
        transaction,
        wallets: wallets,
        accounts: accounts,
        displayCurrency: displayCurrency,
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
        appLocale: money.locale,
        btcDecimalPlaces: money.btcDecimalPlaces,
        includeExpandPayload: !isHome || expanded,
      );
      resolvedColors = TransactionCardColors.resolve(
        transaction,
        wallets: wallets,
        accounts: accounts,
      );
    }
    final colors = resolvedColors.forHomeSurface(HomeSurfaceTheme.of(context));
    final amountLabel = presentation.primaryAmountLabel;
    final title = presentation.title;
    final counterparty = presentation.subtitle;
    final timestampLabel = presentation.tertiary;
    final homeParty = isHome
        ? _homePartyLabel(context, transaction, presentation, wallets, accounts)
        : '';
    final homeTitle = isHome ? title.split(' · ').first.trim() : title;
    final compact = mode == StatementTransactionCardMode.stacked && !expanded;
    final cardPadding = isHome ? 14.0 : (compact ? 16.0 : 20.0);
    final iconSize = isHome ? 40.0 : (compact ? 42.0 : 48.0);
    final titleFontSize =
        isHome ? HomeTypography.bodySize : (compact ? 15.0 : 17.0);
    final counterpartyFontSize =
        isHome ? HomeTypography.captionSize : (compact ? 12.0 : 13.0);
    final titleColor = colors.title;
    final subtitleColor = colors.subtitle;
    final metaColor = colors.meta;
    final amountColor = colors.title;
    final networkLabel = TransactionPresentationCopy.of(
      context,
    ).railShort(presentation.axes.rail);

    if (mode == StatementTransactionCardMode.separated) {
      return _BankStatementTransactionRow(
        transaction: transaction,
        presentation: presentation,
        amountLabel: amountLabel,
        btcAmount: MoneyDisplay.formatAmountFromBtc(
          btcAmount: transaction.signedAmountBTC,
          currency: Currency.btc,
          btcUsd: btcUsd,
          btcEur: btcEur,
          btcBrl: btcBrl,
          signed: true,
          appLocale: money.locale,
        ),
        expanded: expanded,
        onTap: onTap,
        wallets: wallets,
        accounts: accounts,
        onChanged: _accept,
      );
    }

    final destinationTitle = isHome
        ? _resolveDestinationTitle(transaction, counterparty, title)
        : title;
    final homeNetwork = _resolveNetwork(transaction);
    final homeTimeAndWeekday =
        _formatTimeAndWeekday(context, transaction.timestamp);
    final homeAmount = _trimAmountTrailingZeros(amountLabel);

    final a11yLabel = isHome
        ? [
            destinationTitle,
            homeNetwork,
            homeAmount,
            homeTimeAndWeekday,
          ].where((s) => s.trim().isNotEmpty && s != '—').join('. ')
        : [
            title,
            counterparty,
            amountLabel,
            timestampLabel,
            if (expanded) 'expandido',
          ].where((s) => s.trim().isNotEmpty).join('. ');

    final radius = BorderRadius.circular(isHome ? 0 : 28);
    final decoration = isHome
        ? null
        : BoxDecoration(
            color: colors.background,
            borderRadius: radius,
            border: Border.all(color: colors.border, width: 1),
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isHome)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ActivityStatusIcon(
                transaction: transaction,
                colors: colors,
                iconSize: iconSize,
                axes: presentation.axes,
                expanded: false,
                pauseWhileScrolling: isHome,
                originalHomeStyle: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDualFontText(
                      text: destinationTitle,
                      letterStyle: AppTypography.inter(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: AppTypography.w590,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      numberStyle: AppTypography.inter(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: AppTypography.w590,
                        letterSpacing: -0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      homeNetwork,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.inter(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: AppTypography.w500,
                        letterSpacing: 0.1,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _buildDualFontText(
                      text: homeAmount,
                      letterStyle: AppTypography.inter(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: AppTypography.w590,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      numberStyle: AppTypography.inter(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: AppTypography.w590,
                        letterSpacing: -0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.2,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDualFontText(
                    text: homeTimeAndWeekday,
                    letterStyle: AppTypography.inter(
                      color: metaColor,
                      fontSize: 12,
                      fontWeight: AppTypography.w400,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                    numberStyle: AppTypography.inter(
                      color: metaColor,
                      fontSize: 12,
                      fontWeight: AppTypography.w400,
                      letterSpacing: -0.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.2,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ActivityStatusIcon(
                transaction: transaction,
                colors: colors,
                iconSize: iconSize,
                axes: presentation.axes,
                expanded: expanded,
                pauseWhileScrolling: isHome,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: AppTypography.bodyFontFamily,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (isHome) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${timestampLabel.trim()} · ${presentation.axes.direction == TxDirection.outgoing ? TransactionPresentationCopy.of(context).toPrefix : presentation.axes.direction == TxDirection.incoming ? TransactionPresentationCopy.of(context).fromPrefix : ''} $homeParty',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontFamily: AppTypography.bodyFontFamily,
                          fontSize: HomeTypography.captionSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          height: 1.15,
                        ),
                      ),
                    ] else if (counterparty.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        counterparty,
                        style: TextStyle(
                          color: subtitleColor,
                          fontFamily: AppTypography.bodyFontFamily,
                          fontSize: counterpartyFontSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    _ActivityStatusLine(
                      transaction: transaction,
                      presentation: presentation,
                      color: colors.statusStrong,
                      includeRail: !isHome,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: isHome ? 116 : (compact ? 108 : 156),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          amountLabel,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: HomeTypography.transactionAmount(
                            color: amountColor,
                          ).copyWith(fontSize: isHome ? 15 : 16),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isHome ? networkLabel : timestampLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isHome ? subtitleColor : metaColor,
                          fontFamily: AppTypography.bodyFontFamily,
                          fontSize: isHome ? HomeTypography.captionSize : 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        // Keep details in the tree while height collapses — swapping to an
        // empty child makes content vanish before the close animation can run.
        _CollapsingDetails(
          expanded: expanded,
          duration: KeroseneMotion.duration(context, KeroseneMotion.medium),
          detailsBuilder: (context) => _TransactionDetailsTable(
            transaction: transaction,
            presentation: presentation,
            colors: colors,
            onChanged: _accept,
          ),
        ),
        if (!expanded && !isHome) _SeeDetailsLink(transaction: transaction),
      ],
    );

    final effectiveOnTap = onTap ??
        (isHome
            ? () {
                HapticFeedback.selectionClick();
                TransactionDetailScreen.open(
                  context,
                  transaction,
                  originRect: keroseneOriginRectFromContext(context),
                );
              }
            : null);

    return Semantics(
      button: effectiveOnTap != null,
      label: a11yLabel,
      child: Material(
        type: isHome ? MaterialType.transparency : MaterialType.canvas,
        color: isHome ? Colors.transparent : colors.background,
        borderRadius: radius,
        clipBehavior: isHome ? Clip.none : Clip.hardEdge,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: radius,
          child: Ink(
            decoration: decoration,
            padding: isHome
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : EdgeInsets.all(cardPadding),
            child: body,
          ),
        ),
      ),
    );
  }
}

List<Wallet> _walletsFromRef(WidgetRef ref) {
  final state = ref.watch(walletProvider);
  if (state is WalletLoaded) return state.wallets;
  return const [];
}

/// Expands/collapses details with height animation while keeping content
/// painted during the close (unlike AnimatedSize + empty swap).
class _CollapsingDetails extends StatefulWidget {
  final bool expanded;
  final Duration duration;
  final WidgetBuilder detailsBuilder;

  const _CollapsingDetails({
    required this.expanded,
    required this.duration,
    required this.detailsBuilder,
  });

  @override
  State<_CollapsingDetails> createState() => _CollapsingDetailsState();
}

class _CollapsingDetailsState extends State<_CollapsingDetails>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _heldChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.expanded) {
      _heldChild = widget.detailsBuilder(context);
      _controller.value = 1;
    }
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant _CollapsingDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.expanded) {
      // Refresh content while open; capture snapshot for close animation.
      _heldChild = widget.detailsBuilder(context);
      if (_controller.status != AnimationStatus.forward &&
          _controller.value < 1) {
        _controller.forward();
      }
    } else if (oldWidget.expanded && !widget.expanded) {
      // Keep last open details — do NOT rebuild via detailsBuilder: the parent
      // may already be collapsed (empty expand payload / zero fields).
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.expanded) {
      if (_heldChild == null) return;
      setState(() => _heldChild = null);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = _heldChild;
    if (details == null && _controller.isDismissed) {
      return const SizedBox(width: double.infinity);
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: details ?? const SizedBox.shrink(),
        ),
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: KeroseneMotion.standardInOut.transform(
              _controller.value,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

List<Wallet> _walletsFromRefRead(WidgetRef ref) {
  final state = ref.read(walletProvider);
  if (state is WalletLoaded) return state.wallets;
  return const [];
}

List<BitcoinAccount> _accountsFromRef(WidgetRef ref) {
  return ref.watch(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];
}

List<BitcoinAccount> _accountsFromRefRead(WidgetRef ref) {
  return ref.read(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];
}

class _BankStatementTransactionRow extends StatelessWidget {
  final Transaction transaction;
  final TransactionPresentation presentation;
  final String amountLabel;
  final String btcAmount;
  final bool expanded;
  final VoidCallback? onTap;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;

  final ValueChanged<Transaction>? onChanged;

  const _BankStatementTransactionRow({
    required this.transaction,
    this.onChanged,
    required this.presentation,
    required this.amountLabel,
    required this.btcAmount,
    required this.expanded,
    required this.onTap,
    this.wallets = const [],
    this.accounts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final title = presentation.title;
    final counterparty = presentation.subtitle;
    // Amounts stay neutral (white/ink); status lives in the pill, not the value.
    final amountColor = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: KeroseneMotion.duration(context, KeroseneMotion.short),
          curve: KeroseneMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: KeroseneBrandTheme.of(context).border)),
          ),
          child: Column(
            children: [
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth >= 360 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 17) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ActivityGlyph.forAxes(presentation.axes, size: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: HomeTypography.bodySize,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              counterparty,
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                letterSpacing: 0,
                                height: 1.22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 132),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountLabel,
                              textAlign: TextAlign.right,
                              style: HomeTypography.transactionAmount(
                                color: amountColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _DarkStatusPill(transaction: transaction),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final theme = Theme.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      ActivityGlyph.forAxes(presentation.axes, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(title,
                              style: AppTypography.bodyMedium.copyWith(
                                  color: theme.colorScheme.onSurface))),
                    ]),
                    const SizedBox(height: 8),
                    Text(counterparty,
                        style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Text(amountLabel,
                        style: HomeTypography.transactionAmount(
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: _DarkStatusPill(transaction: transaction)),
                  ],
                );
              }),
              AnimatedSize(
                duration: KeroseneMotion.duration(
                  context,
                  KeroseneMotion.medium,
                ),
                curve: KeroseneMotion.standard,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.base),
                        child: _TransactionDetailsTable(
                          transaction: transaction,
                          presentation: presentation,
                          colors: TransactionCardColors.resolve(
                            transaction,
                            wallets: wallets,
                            accounts: accounts,
                          ),
                          dark: Theme.of(context).brightness == Brightness.dark,
                          onChanged: onChanged,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (!expanded)
                _SeeDetailsLink(
                    transaction: transaction,
                    dark: Theme.of(context).brightness == Brightness.dark),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkStatusPill extends StatelessWidget {
  final Transaction transaction;

  const _DarkStatusPill({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tone = TransactionPalette.toneFor(transaction);
    final fg = Theme.of(context).colorScheme.onSurface;
    final axes = TransactionAxes.classify(transaction);
    final label = TransactionPresentationCopy.of(
      context,
    ).lifecycleLabel(axes.lifecycle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeroseneIcon(_statusIcon(tone), size: 13, color: fg),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(TransactionStatusTone tone) => switch (tone) {
        TransactionStatusTone.confirmed => KeroseneIcons.success,
        TransactionStatusTone.confirming ||
        TransactionStatusTone.pending =>
          KeroseneIcons.timer,
        TransactionStatusTone.cancelled => KeroseneIcons.closeCircle,
        TransactionStatusTone.failed => KeroseneIcons.error,
      };
}

/// Compact, explicit status metadata for every history row. Status is always
/// conveyed by icon, label, and semantic colour; colour alone is insufficient.
class _ActivityStatusLine extends StatelessWidget {
  final Transaction transaction;
  final TransactionPresentation presentation;
  final bool includeRail;
  final Color color;

  const _ActivityStatusLine({
    required this.transaction,
    required this.presentation,
    required this.color,
    this.includeRail = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = TransactionPalette.toneFor(transaction);
    final copy = TransactionPresentationCopy.of(context);
    final type = copy.railShort(presentation.axes.rail);
    final label = includeRail
        ? '${presentation.statusLabel} · $type'
        : presentation.statusLabel;
    return Row(
      children: [
        KeroseneIcon(_statusIcon(tone), size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: AppTypography.w590,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(TransactionStatusTone tone) => switch (tone) {
        TransactionStatusTone.confirmed => KeroseneIcons.success,
        TransactionStatusTone.confirming ||
        TransactionStatusTone.pending =>
          KeroseneIcons.timer,
        TransactionStatusTone.cancelled => KeroseneIcons.closeCircle,
        TransactionStatusTone.failed => KeroseneIcons.error,
      };
}

class _TransactionDetailsTable extends StatelessWidget {
  final Transaction transaction;
  final TransactionPresentation presentation;
  final TransactionCardColors colors;
  final bool dark;

  final ValueChanged<Transaction>? onChanged;

  const _TransactionDetailsTable({
    required this.transaction,
    this.onChanged,
    required this.presentation,
    required this.colors,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = presentation.expandedFields;
    final labelColor = dark
        ? KeroseneBrandTheme.dark.textPrimary
        : KeroseneBrandTheme.light.textPrimary;
    final valueColor = dark
        ? KeroseneBrandTheme.dark.textPrimary
        : KeroseneBrandTheme.light.textPrimary;
    final lineColor =
        dark ? KeroseneBrandTheme.dark.border : KeroseneBrandTheme.light.border;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(height: 1, color: lineColor),
              ),
            _PresentationFieldRow(
              field: rows[index],
              labelColor: labelColor,
              valueColor: valueColor,
              dark: dark,
            ),
          ],
          const SizedBox(height: 16),
          ActivityActions(transaction: transaction, onChanged: onChanged),
          const SizedBox(height: 8),
          _SeeDetailsLink(transaction: transaction, dark: dark),
        ],
      ),
    );
  }
}



class _PresentationFieldRow extends StatelessWidget {
  final PresentationField field;
  final Color labelColor;
  final Color valueColor;
  final bool dark;

  const _PresentationFieldRow({
    required this.field,
    required this.labelColor,
    required this.valueColor,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isConf =
        field.key == 'confirmations' && field.hasConfirmationProgress;
    final label = Text(field.label,
        style: AppTypography.bodySmall.copyWith(color: labelColor));
    final value = SelectableText(field.value,
        textDirection: field.copyable ? TextDirection.ltr : null,
        style: field.copyable
            ? AppTypography.technicalMono(color: valueColor, fontSize: 13.5)
            : AppTypography.bodyMedium
                .copyWith(color: valueColor, fontSize: 13.5));
    final valueRow =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: value),
      if (field.copyable)
        IconButton(
          key: ValueKey('statement-copy-${field.key}'),
          tooltip: context.tr.copy,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: KeroseneIcon(KeroseneIcons.copy, size: 18, color: labelColor),
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: field.value));
              if (context.mounted) {
                AppNotice.showSuccess(context,
                    message: context.tr.paymentConfirmationCopied(field.label));
              }
            } catch (_) {
              if (context.mounted) {
                AppNotice.showError(context,
                    message: context.tr.copyDataFailed);
              }
            }
          },
        ),
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = field.copyable ||
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(14) > 17;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (stacked) ...[
          label,
          const SizedBox(height: 6),
          valueRow,
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: label),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: valueRow),
          ]),
        if (isConf) ...[
          const SizedBox(height: 8),
          _ConfirmationProgressLine(
            current: field.progressCurrent!,
            target: field.progressTarget!,
            dark: dark,
          ),
        ],
      ]);
    });
  }
}

/// Yellow progress = conf/target; remainder is a soft grey loading shimmer.
/// Only used under the Confirmations row for on-chain-eligible txs.
class _ConfirmationProgressLine extends StatefulWidget {
  final int current;
  final int target;
  final bool dark;

  const _ConfirmationProgressLine({
    required this.current,
    required this.target,
    this.dark = false,
  });

  @override
  State<_ConfirmationProgressLine> createState() =>
      _ConfirmationProgressLineState();
}

class _ConfirmationProgressLineState extends State<_ConfirmationProgressLine>
    with SingleTickerProviderStateMixin {
  Color get _yellow => widget.dark
      ? KeroseneBrandTheme.dark.textPrimary
      : KeroseneBrandTheme.light.textPrimary;
  Color get _yellowDone => widget.dark
      ? KeroseneBrandTheme.dark.textPrimary
      : KeroseneBrandTheme.light.textPrimary;

  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: KeroseneMotion.progressShimmer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShimmer();
  }

  void _syncShimmer() {
    if (_isComplete || KeroseneMotion.reduceMotion(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ConfirmationProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncShimmer();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  bool get _isComplete => widget.current >= widget.target;

  /// e.g. 1 conf of 4 → 25%; of 6 → ~16.7%. Uses conf/target.
  double get _filled => (widget.current / widget.target).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final trackBase = widget.dark
        ? KeroseneBrandTheme.dark.border
        : KeroseneBrandTheme.light.border;
    final trackHi = widget.dark
        ? KeroseneBrandTheme.dark.textMuted
        : KeroseneBrandTheme.light.textMuted;
    final fill = _isComplete ? _yellowDone : _yellow;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final filledW = w * _filled;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Remaining track — solid grey + sliding shimmer while open.
                if (!_isComplete)
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _shimmer,
                      builder: (context, _) {
                        final t = _shimmer.value;
                        return CustomPaint(
                          painter: _GreyLoadingTrackPainter(
                            base: trackBase,
                            highlight: trackHi,
                            phase: t,
                          ),
                        );
                      },
                    ),
                  )
                else
                  ColoredBox(color: trackBase),
                // Primary yellow (or green when complete) progress.
                Align(
                  alignment: Alignment.centerLeft,
                  child: RepaintBoundary(
                    child: AnimatedContainer(
                      duration: KeroseneMotion.duration(
                          context, KeroseneMotion.progressFill),
                      curve: KeroseneMotion.standard,
                      width: filledW,
                      height: 5,
                      color: fill,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GreyLoadingTrackPainter extends CustomPainter {
  final Color base;
  final Color highlight;
  final double phase;

  _GreyLoadingTrackPainter({
    required this.base,
    required this.highlight,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    // Soft band that sweeps left → right (loading remainder).
    final band = size.width * 0.42;
    final x = (phase * (size.width + band)) - band;
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [base, highlight, base],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawRect(
      Rect.fromLTWH(x, 0, band, size.height).intersect(rect),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GreyLoadingTrackPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        base != oldDelegate.base ||
        highlight != oldDelegate.highlight;
  }
}

class _SeeDetailsLink extends StatelessWidget {
  final Transaction transaction;
  final bool dark;

  const _SeeDetailsLink({required this.transaction, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final label = TransactionPresentationCopy.of(context).viewDetails;
    final color = dark ? TransactionPalette.inkOnDark : Colors.black;
    return Center(
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          // Circular reveal from this button (same family as notifications).
          final origin = keroseneOriginRectFromContext(context) ??
              Rect.fromCenter(
                center: MediaQuery.sizeOf(context).center(Offset.zero),
                width: 48,
                height: 48,
              );
          TransactionDetailScreen.open(
            context,
            transaction,
            originRect: origin,
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // No underline / “risca” under the label.
          textStyle: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            decoration: TextDecoration.none,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Status ring + glyph + corner badge (✓ / ✕ / 6). Never replaces glyph with "OK"/"0/6".
class _ActivityStatusIcon extends StatefulWidget {
  final Transaction transaction;
  final TransactionCardColors colors;
  final double iconSize;
  final TransactionAxes? axes;

  /// When true, status badge is larger so ✓ is obvious on open cards.
  final bool expanded;

  /// Pause ring spinners while the home list scrolls (120 Hz scroll path).
  final bool pauseWhileScrolling;
  final bool originalHomeStyle;

  const _ActivityStatusIcon({
    required this.transaction,
    required this.colors,
    required this.iconSize,
    this.axes,
    this.expanded = false,
    this.pauseWhileScrolling = false,
    this.originalHomeStyle = false,
  });

  @override
  State<_ActivityStatusIcon> createState() => _ActivityStatusIconState();
}

class _ActivityStatusIconState extends State<_ActivityStatusIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _spinController;
  ScrollPosition? _scrollPosition;
  bool _scrollPaused = false;
  bool _reducedMotion = false;

  Color get _yellow => widget.originalHomeStyle
      ? KeroseneBrandTokens.warning
      : widget.colors.title;
  Color get _green => widget.originalHomeStyle
      ? KeroseneBrandTokens.success
      : widget.colors.title;
  Color get _red => widget.originalHomeStyle
      ? KeroseneBrandTokens.error
      : widget.colors.title;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = KeroseneMotion.reduceMotion(context);
    _syncAnimations();
    if (!widget.pauseWhileScrolling) return;
    final scrollable = Scrollable.maybeOf(context);
    final pos = scrollable?.position;
    if (_scrollPosition != pos) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
      _scrollPosition = pos;
      _scrollPosition?.isScrollingNotifier.addListener(_onScrollChanged);
      _onScrollChanged();
    }
  }

  void _onScrollChanged() {
    if (!mounted || !widget.pauseWhileScrolling) return;
    final scrolling = _scrollPosition?.isScrollingNotifier.value ?? false;
    if (scrolling == _scrollPaused) return;
    _scrollPaused = scrolling;
    if (scrolling) {
      _spinController?.stop();
    } else {
      _resumeSpinIfNeeded();
    }
  }

  void _resumeSpinIfNeeded() {
    final mode = _ringMode(widget.transaction);
    final needsSpin = mode == _RingMode.spinning;
    if (needsSpin &&
        !_reducedMotion &&
        _spinController != null &&
        !(_spinController!.isAnimating)) {
      _spinController!.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ActivityStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.confirmations !=
            widget.transaction.confirmations ||
        oldWidget.transaction.status != widget.transaction.status ||
        oldWidget.transaction.displayStatus !=
            widget.transaction.displayStatus ||
        oldWidget.expanded != widget.expanded) {
      _syncAnimations();
    }
    if (oldWidget.pauseWhileScrolling != widget.pauseWhileScrolling &&
        widget.pauseWhileScrolling) {
      _onScrollChanged();
    }
  }

  void _syncAnimations() {
    final mode = _ringMode(widget.transaction);
    final needsSpin = mode == _RingMode.spinning;
    if (needsSpin && !_reducedMotion) {
      _spinController ??= AnimationController(
        vsync: this,
        duration: KeroseneMotion.progressRing,
      );
      if (!_scrollPaused && !(_spinController!.isAnimating)) {
        _spinController!.repeat();
      }
    } else {
      final c = _spinController;
      _spinController = null;
      c?.stop();
      c?.dispose();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
    _spinController?.dispose();
    super.dispose();
  }

  int _backendConfirmations(Transaction tx) {
    if (tx.isLightningEffective ||
        tx.isInternal ||
        !tx.showsOnchainConfirmations) {
      return 0;
    }
    if (tx.isCancelled ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.isUnconfirmedExpired) {
      return 0;
    }
    return tx.confirmations.clamp(0, tx.onchainConfirmationTarget);
  }

  bool _isInstantRail(Transaction tx) {
    return tx.isLightningEffective ||
        tx.isInternal ||
        !tx.showsOnchainConfirmations;
  }

  bool _isConfirmedLike(Transaction tx) {
    if (tx.isCancelled ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.isUnconfirmedExpired) {
      return false;
    }
    // Instant rails settle without block confs.
    if (_isInstantRail(tx)) {
      if (tx.displayStatus == TransactionStatus.confirmed || tx.isConfirmed) {
        return true;
      }
      if (tx.displayStatus != TransactionStatus.pending &&
          tx.displayStatus != TransactionStatus.confirming &&
          tx.displayStatus != TransactionStatus.reconciling) {
        return true;
      }
      return false;
    }
    // On-chain: only fully confirmed when live confs meet the target.
    // Backend SETTLED alone must not jump the icon to a fake "6".
    return tx.confirmations >= tx.onchainConfirmationTarget;
  }

  _RingMode _ringMode(Transaction tx) {
    if (tx.isCancelled ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.isUnconfirmedExpired) {
      return _RingMode.failed;
    }
    if (tx.displayStatus == TransactionStatus.reconciling) {
      return _RingMode.spinning;
    }
    // Internal / Lightning: fully settled -> none (no ring).
    if (_isInstantRail(tx)) {
      if (_isConfirmedLike(tx)) return _RingMode.none;
      if (tx.displayStatus == TransactionStatus.pending ||
          tx.displayStatus == TransactionStatus.confirming) {
        return _RingMode.spinning;
      }
      return _RingMode.none;
    }
    final conf = tx.confirmations;
    final target = tx.onchainConfirmationTarget;
    if (conf >= target) {
      // All 6 confirmations completed -> show nothing!
      return _RingMode.none;
    }
    if (conf > 0) return _RingMode.progress;
    if (tx.displayStatus == TransactionStatus.pending ||
        tx.displayStatus == TransactionStatus.confirming ||
        tx.displayStatus == TransactionStatus.confirmed ||
        tx.isConfirmed) {
      // Mempool / early SETTLED with 0 confs -> continuous spinning arc.
      return _RingMode.spinning;
    }
    return _RingMode.none;
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final mode = _ringMode(tx);
    final conf = _backendConfirmations(tx);
    final target = tx.onchainConfirmationTarget.clamp(1, 6);
    final spin = _spinController;
    Widget buildRing({required double spinValue, required double loadValue}) {
      return CustomPaint(
        size: Size(widget.iconSize, widget.iconSize),
        painter: _RingConfirmationPainter(
          mode: mode,
          confirmations: conf,
          target: target,
          yellowColor: _yellow,
          greenColor: _green,
          failedColor: _red,
          inactiveColor: widget.colors.iconWellBorder,
          spinValue: spinValue,
          loadValue: loadValue,
        ),
      );
    }

    // Rail and direction stay visible while status remains in the ring/text.
    final centerChild = ActivityGlyph(
      key: const ValueKey('icon-glyph'),
      spec: widget.axes != null
          ? ActivityGlyphSpec.fromAxes(widget.axes!)
          : ActivityGlyphSpec.fromTransaction(tx),
      size: widget.iconSize * 0.72,
      showWell: false,
      iconColor: widget.colors.icon,
      badgeWellColor: Colors.black,
      badgeIconColor: widget.colors.icon,
      wellBorder: widget.colors.iconWellBorder,
    );

    return SizedBox(
      width: widget.iconSize,
      height: widget.iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (spin != null)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: spin,
                builder: (_, __) =>
                    buildRing(spinValue: spin.value, loadValue: spin.value),
              ),
            )
          else
            buildRing(spinValue: 0, loadValue: 0),
          Container(
            width: widget.iconSize * 0.78,
            height: widget.iconSize * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colors.iconWell,
            ),
            alignment: Alignment.center,
            child: centerChild,
          ),
        ],
      ),
    );
  }
}

enum _RingMode {
  /// Mempool / unconfirmed on-chain or pending rail (0 confirmations).
  /// Shows full subtle track with a continuous spinning arc.
  spinning,

  /// In progress (e.g. 1 to 5 confirmations).
  /// Shows a static background track and a continuous progress arc that fills
  /// smoothly based on confirmations / target (without segment dividers).
  progress,

  /// Fully confirmed (all 6 / target met) or instant rail settled:
  /// Nothing is rendered around the icon.
  none,

  failed,
}

class _RingConfirmationPainter extends CustomPainter {
  final _RingMode mode;
  final int confirmations;
  final int target;
  final Color yellowColor;
  final Color greenColor;
  final Color failedColor;
  final Color inactiveColor;
  final double spinValue;
  final double loadValue;

  _RingConfirmationPainter({
    required this.mode,
    required this.confirmations,
    required this.target,
    required this.yellowColor,
    required this.greenColor,
    required this.failedColor,
    required this.inactiveColor,
    required this.spinValue,
    required this.loadValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == _RingMode.none) {
      return;
    }

    final origin = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;
    const strokeWidth = 2.6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (mode == _RingMode.spinning) {
      // Soft track + spinning arc (pending / 0 confs).
      paint.color = yellowColor.withValues(alpha: 0.22);
      canvas.drawCircle(origin, radius, paint);
      paint.color = yellowColor;
      final start = -math.pi / 2 + spinValue * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        start,
        math.pi * 1.35,
        false,
        paint,
      );
      return;
    }

    if (mode == _RingMode.failed) {
      paint.color = failedColor.withValues(alpha: 0.35);
      canvas.drawCircle(origin, radius, paint);
      paint.color = failedColor;
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        -math.pi / 2,
        math.pi * 1.6,
        false,
        paint,
      );
      return;
    }

    if (mode == _RingMode.progress) {
      // Static loading background track (subtle inactive ring).
      paint.color = inactiveColor.withValues(alpha: 0.45);
      canvas.drawCircle(origin, radius, paint);

      // Continuous arc filled proportionally based on confirmations received.
      final ringCount = target.clamp(1, 6);
      final fraction = (confirmations / ringCount).clamp(0.0, 1.0);
      if (fraction > 0) {
        paint.color = greenColor;
        const start = -math.pi / 2;
        final sweep = fraction * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: origin, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingConfirmationPainter oldDelegate) {
    return mode != oldDelegate.mode ||
        confirmations != oldDelegate.confirmations ||
        target != oldDelegate.target ||
        spinValue != oldDelegate.spinValue ||
        loadValue != oldDelegate.loadValue;
  }
}
