import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/screens/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_visuals.dart';
import 'package:kerosene/features/movement/widgets/transaction_palette.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';

import 'package:kerosene/core/theme/app_typography.dart';

enum StatementTransactionCardMode { stacked, separated }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          if (index > 0) SizedBox(height: itemGap),
          itemBuilder(context, index),
        ],
      ],
    );
  }
}

class StatementTransactionCard extends ConsumerWidget {
  final Transaction transaction;
  final bool expanded;
  final VoidCallback? onTap;
  final StatementTransactionCardMode mode;

  const StatementTransactionCard({
    super.key,
    required this.transaction,
    this.expanded = false,
    this.onTap,
    this.mode = StatementTransactionCardMode.stacked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = TransactionVisualSpec.fromTransaction(transaction);
    final money = ref.watch(moneyFormatConfigProvider);
    final selectedCurrency = money.currency;
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final colors = TransactionCardColors.resolve(transaction);
    final amountLabel = _amountLabel(
      transaction: transaction,
      currency: selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: money.locale,
    );
    final wallets = _walletsFromRef(ref);
    final accounts = _accountsFromRef(ref);
    final title = resolveTransactionActionTitle(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final counterparty = _counterparty(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final timestampLabel = AppDateTime.formatRelative(
      context,
      transaction.timestamp,
    );
    final compact = mode == StatementTransactionCardMode.stacked && !expanded;
    final cardPadding = compact ? 16.0 : 20.0;
    final iconSize = compact ? 42.0 : 48.0;
    final titleFontSize = compact ? 15.0 : 17.0;
    final counterpartyFontSize = compact ? 12.0 : 13.0;
    final amountFontSize = compact ? 24.0 : 30.0;
    final headerAmountGap = compact ? 12.0 : 22.0;

    if (mode == StatementTransactionCardMode.separated) {
      return _BankStatementTransactionRow(
        transaction: transaction,
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
      );
    }

    final motion = KeroseneMotion.duration(context, KeroseneMotion.medium);
    final a11yLabel = [
      title,
      counterparty,
      amountLabel,
      timestampLabel,
      if (expanded) 'expandido',
    ].where((s) => s.trim().isNotEmpty).join('. ');

    return Semantics(
      button: onTap != null,
      label: a11yLabel,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: motion,
          curve: KeroseneMotion.standard,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          // Grow only downward: top content stays put, details open below.
          // Animações mais internas cuidarão da expansão
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _AnimatedRingIconWrapper(
                      transaction: transaction,
                      visual: visual,
                      colors: colors,
                      iconSize: iconSize,
                      expanded: expanded,
                      wallets: wallets,
                      accounts: accounts,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.title,
                              fontFamily: AppTypography.bodyFontFamily,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            counterparty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.subtitle,
                              fontFamily: AppTypography.bodyFontFamily,
                              fontSize: counterpartyFontSize,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.financial(
                            color: colors.title, // Ou TransactionPalette.inkPrimary se preferir
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Bottom-right yellow confirmation ball removed —
                        // confirmation progress lives only on the top-left ring.
                        Text(
                          timestampLabel,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: colors.meta,
                            fontFamily: AppTypography.bodyFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  firstCurve: Curves.easeOutCubic,
                  secondCurve: Curves.easeOutCubic,
                  sizeCurve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: _TransactionDetailsTable(
                      transaction: transaction,
                      colors: colors,
                      wallets: wallets,
                      accounts: accounts,
                    ),
                  ),
                ),
              ],
            ),
        ),
      ),
    ),
    );
  }

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String _amountLabel({
    required Transaction transaction,
    required Currency currency,
    required double? btcUsd,
    required double? btcEur,
    required double? btcBrl,
    Locale? appLocale,
  }) {
    // Debits show total leaving the wallet (amount + network + service fees).
    final signedAmount = transaction.signedDisplayAmountBTC;
    final includeFeesInDebit = transaction.isDebit &&
        (transaction.showsNetworkFee || transaction.showsServiceFee);
    return MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: signedAmount,
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      // Frozen fiat is principal-only; when fees apply, recompute from sats.
      displayAmountUsd:
          includeFeesInDebit ? null : transaction.displayAmountUsd,
      displayAmountEur:
          includeFeesInDebit ? null : transaction.displayAmountEur,
      displayAmountBrl:
          includeFeesInDebit ? null : transaction.displayAmountBrl,
      displayBtcUsd: transaction.displayBtcUsd,
      displayBtcEur: transaction.displayBtcEur,
      displayBtcBrl: transaction.displayBtcBrl,
      signed: true,
      appLocale: appLocale,
    );
  }

  static String _counterparty(
    BuildContext context,
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    // Full route so the user always sees origin, destination and network.
    return resolveTransactionRouteSummary(
      tx,
      wallets: wallets,
      accounts: accounts,
      compactHash: true,
    );
  }

  /// Network-reactive icon (not direction/type).
  /// cold → snowflake, onchain → chain link, internal → two people, LN → bolt.
  static IconData _iconFor(
    Transaction tx,
    TransactionVisualSpec visual, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    final network = resolveTransactionNetwork(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    if (tx.displayStatus == TransactionStatus.failed ||
        tx.displayStatus == TransactionStatus.cancelled) {
      return KeroseneIcons.warning;
    }
    return switch (network) {
      TransactionNetwork.internal ||
      TransactionNetwork.paymentLinkInternal =>
        KeroseneIcons.group,
      TransactionNetwork.lightning => KeroseneIcons.lightning,
      TransactionNetwork.cold => KeroseneIcons.coldWallet,
      TransactionNetwork.paymentLinkOnchain => KeroseneIcons.onchain,
      TransactionNetwork.onchain || TransactionNetwork.unknown =>
        KeroseneIcons.onchain,
    };
  }

  static String _shorten(String value, {int head = 12, int tail = 6}) {
    final normalized = value.trim();
    if (normalized.length <= head + tail + 3) return normalized;
    return '${normalized.substring(0, head)}...${normalized.substring(normalized.length - tail)}';
  }
}

List<Wallet> _walletsFromRef(WidgetRef ref) {
  final state = ref.watch(walletProvider);
  if (state is WalletLoaded) return state.wallets;
  return const [];
}

List<BitcoinAccount> _accountsFromRef(WidgetRef ref) {
  return ref.watch(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];
}

String _bankRailLabel(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  return resolveTransactionNetworkLabel(
    tx,
    wallets: wallets,
    accounts: accounts,
  );
}

String _bankStatusLabel(Transaction tx) {
  if (tx.isUnconfirmedExpired) return 'Não confirmada';
  if (tx.isOnChain &&
      tx.confirmations <= 0 &&
      tx.displayStatus != TransactionStatus.failed &&
      tx.displayStatus != TransactionStatus.cancelled) {
    return 'Na mempool';
  }
  if (tx.isOnChain && tx.confirmations > 0) {
    if (tx.confirmations >= tx.onchainConfirmationTarget ||
        tx.displayStatus == TransactionStatus.confirmed) {
      return tx.confirmations >= 6
          ? 'Confirmado (${tx.confirmations}+)'
          : 'Confirmado (${tx.confirmations}/6)';
    }
    return '${tx.confirmations}/6 confirmações';
  }
  return switch (tx.displayStatus) {
    TransactionStatus.confirmed => 'Confirmado',
    TransactionStatus.confirming => 'Em andamento',
    TransactionStatus.pending => 'Pendente',
    TransactionStatus.cancelled => 'Cancelada',
    TransactionStatus.failed => 'Falhou',
    TransactionStatus.reconciling => 'Em análise',
  };
}

String _bankSubtitle(
  BuildContext context,
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final when = AppDateTime.formatRelative(context, tx.timestamp);
  return '$when · ${_bankRailLabel(tx, wallets: wallets, accounts: accounts)} · ${_bankStatusLabel(tx)}';
}

String _bankCounterparty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  return resolveTransactionRouteSummary(
    tx,
    wallets: wallets,
    accounts: accounts,
    compactHash: true,
  );
}

String _darkDetailValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '—';
  return StatementTransactionCard._shorten(trimmed, head: 18, tail: 8);
}

class _BankStatementTransactionRow extends StatelessWidget {
  final Transaction transaction;
  final String amountLabel;
  final String btcAmount;
  final bool expanded;
  final VoidCallback? onTap;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;

  const _BankStatementTransactionRow({
    required this.transaction,
    required this.amountLabel,
    required this.btcAmount,
    required this.expanded,
    required this.onTap,
    this.wallets = const [],
    this.accounts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final title = resolveTransactionActionTitle(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final counterparty = _bankCounterparty(
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final subtitle = _bankSubtitle(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final tone = TransactionPalette.toneFor(transaction);
    final amountColor =
        tone == TransactionStatusTone.failed ||
                tone == TransactionStatusTone.cancelled
            ? TransactionPalette.statusStrong(tone)
            : TransactionPalette.inkOnDark;

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
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.hexFF222222),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _BankDirectionIcon(transaction: transaction),
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
                            color: TransactionPalette.inkOnDark,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          counterparty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: TransactionPalette.inkTertiary,
                            letterSpacing: 0,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: TransactionPalette.inkSecondary,
                            letterSpacing: 0,
                            height: 1.2,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.financial(
                            color: amountColor,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
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
              ),
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
                        child: _BankTransactionDetailsTable(
                          transaction: transaction,
                          wallets: wallets,
                          accounts: accounts,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankDirectionIcon extends StatelessWidget {
  final Transaction transaction;

  const _BankDirectionIcon({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tone = TransactionPalette.toneFor(transaction);
    final color = switch (tone) {
      TransactionStatusTone.failed ||
      TransactionStatusTone.cancelled =>
        TransactionPalette.statusStrong(tone),
      TransactionStatusTone.confirming ||
      TransactionStatusTone.pending =>
        TransactionPalette.statusStrong(tone),
      TransactionStatusTone.confirmed => transaction.isCredit
          ? TransactionPalette.amountCredit
          : transaction.isDebit
              ? TransactionPalette.amountDebit
              : TransactionPalette.inkTertiary,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: TransactionPalette.iconWell,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hexFF2A2A2A),
      ),
      child: Icon(_icon(), color: color, size: 18),
    );
  }

  IconData _icon() {
    if (transaction.status == TransactionStatus.failed ||
        transaction.isCancelled) {
      return KeroseneIcons.warning;
    }
    final network = resolveTransactionNetwork(transaction);
    return switch (network) {
      TransactionNetwork.lightning => KeroseneIcons.lightning,
      TransactionNetwork.internal ||
      TransactionNetwork.paymentLinkInternal =>
        KeroseneIcons.moveHorizontal,
      TransactionNetwork.cold => KeroseneIcons.coldWallet,
      TransactionNetwork.paymentLinkOnchain ||
      TransactionNetwork.onchain ||
      TransactionNetwork.unknown =>
        transaction.isCredit ? KeroseneIcons.receive : KeroseneIcons.send,
    };
  }
}

class _DarkStatusPill extends StatelessWidget {
  final Transaction transaction;

  const _DarkStatusPill({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tone = TransactionPalette.toneFor(transaction);
    final fg = TransactionPalette.statusStrong(tone);
    final label = switch (tone) {
      TransactionStatusTone.confirmed => 'Confirmado',
      TransactionStatusTone.confirming => 'Confirmando',
      TransactionStatusTone.pending => 'Pendente',
      TransactionStatusTone.cancelled => 'Cancelada',
      TransactionStatusTone.failed =>
        transaction.isUnconfirmedExpired ? 'Não confirmada' : 'Falhou',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: fg,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
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
}

class _BankTransactionDetailsTable extends StatelessWidget {
  final Transaction transaction;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;

  const _BankTransactionDetailsTable({
    required this.transaction,
    this.wallets = const [],
    this.accounts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final rows = _compactDetailRows(
      context,
      transaction,
      wallets,
      accounts: accounts,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hexFF222222)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Divider(height: 1, color: AppColors.hexFF222222),
                ),
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                child: _BankTransactionDetailsRow(row: rows[index]),
              ),
            ],
            const SizedBox(height: 16),
            _SeeDetailsLink(transaction: transaction),
          ],
        ),
      ),
    );
  }
}

class _BankTransactionDetailsRow extends StatelessWidget {
  final _TransactionDetailRow row;

  const _BankTransactionDetailsRow({required this.row});

  @override
  Widget build(BuildContext context) {
    // Solid black data on expanded rows (light paper cards / bank expanded).
    const ink = Colors.black;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          row.label,
          style: AppTypography.caption.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        if (row.copyValue != null) ...[
          const SizedBox(width: 6),
          _DarkTransactionDetailCopyButton(row: row),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            row.displayValue,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: ink,
              fontFamily: row.displayValue.length > 20
                  ? AppTypography.financialFontFamily
                  : AppTypography.bodyFontFamily,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkTransactionDetailCopyButton extends StatelessWidget {
  final _TransactionDetailRow row;

  const _DarkTransactionDetailCopyButton({required this.row});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr.copy,
      child: IconButton(
        key: ValueKey('statement-detail-copy-${row.key}'),
        onPressed: () => _copyDetail(context, row),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(
          KeroseneIcons.copy,
          size: 15,
          color: Colors.black,
        ),
      ),
    );
  }

  Future<void> _copyDetail(
    BuildContext context,
    _TransactionDetailRow row,
  ) async {
    final value = row.copyValue;
    if (value == null) return;

    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _localizedCopy(
              context,
              pt: 'Detalhe copiado.',
              en: 'Transaction detail copied.',
              es: 'Detalle copiado.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: KeroseneMotion.loop,
        ),
      );
  }
}

List<_TransactionDetailRow> _compactDetailRows(
  BuildContext context,
  Transaction transaction,
  List<Wallet> wallets, {
  List<BitcoinAccount> accounts = const [],
}) {
  final from = resolveTransactionFromParty(
    transaction,
    wallets: wallets,
    accounts: accounts,
  );
  final to = resolveTransactionToParty(
    transaction,
    wallets: wallets,
    accounts: accounts,
    compactHash: true,
  );
  final ownWallet = resolveOwnWalletLabel(
    transaction,
    wallets: wallets,
    accounts: accounts,
  );
  final network = resolveTransactionNetworkLabel(
    transaction,
    wallets: wallets,
    accounts: accounts,
  );
  final rows = <_TransactionDetailRow>[
    _TransactionDetailRow(
      key: 'when',
      label: _localizedCopy(context, pt: 'Quando', en: 'When', es: 'Cuándo'),
      displayValue: AppDateTime.formatRelativeWithClock(
        context,
        transaction.timestamp,
      ),
    ),
    _TransactionDetailRow(
      key: 'wallet',
      label: _localizedCopy(
        context,
        pt: 'Sua carteira',
        en: 'Your wallet',
        es: 'Tu billetera',
      ),
      displayValue: ownWallet,
    ),
    _TransactionDetailRow(
      key: 'from',
      label: _localizedCopy(context, pt: 'De', en: 'From', es: 'De'),
      displayValue: from,
    ),
    _TransactionDetailRow(
      key: 'to',
      label: _localizedCopy(context, pt: 'Para', en: 'To', es: 'Para'),
      displayValue: to,
      copyValue: looksLikeOnchainAddress(to) ? to : null,
    ),
  ];

  // Network / miner fee only for external rails with a real fee.
  if (transaction.showsNetworkFee) {
    rows.add(
      _TransactionDetailRow(
        key: 'network-fee',
        label: _localizedCopy(
          context,
          pt: context.tr.sendReviewNetworkFee,
          en: 'Network fee',
          es: 'Tarifa de red',
        ),
        displayValue: formatSatsAsBtc(transaction.feeSatoshis),
      ),
    );
  } else if (transaction.isLedgerInternal) {
    // Explicit: internal ledger has no miner fee (don't show "—").
  }

  if (transaction.showsServiceFee) {
    rows.add(
      _TransactionDetailRow(
        key: 'service-fee',
        label: _localizedCopy(
          context,
          pt: 'Taxa de serviço',
          en: 'Service fee',
          es: 'Tarifa de servicio',
        ),
        displayValue: formatSatsAsBtc(transaction.serviceFeeSatoshis),
      ),
    );
  }

  rows.add(
    _TransactionDetailRow(
      key: 'network',
      label: _localizedCopy(context, pt: 'Rede', en: 'Network', es: 'Red'),
      displayValue: network,
    ),
  );

  if (transaction.showsOnchainConfirmations) {
    final confLabel = transaction.status == TransactionStatus.confirmed &&
            transaction.confirmations <= 0
        ? _localizedCopy(
            context,
            pt: 'Confirmada na rede',
            en: 'Confirmed on-chain',
            es: 'Confirmada en red',
          )
        : transaction.confirmations >= transaction.onchainConfirmationTarget
            ? '${transaction.confirmations}+'
            : '${transaction.confirmations}/${transaction.onchainConfirmationTarget}';
    rows.add(
      _TransactionDetailRow(
        key: 'confirmations',
        label: _localizedCopy(
          context,
          pt: 'Confirmações',
          en: 'Confirmations',
          es: 'Confirmaciones',
        ),
        displayValue: confLabel,
      ),
    );
  }

  return rows;
}

class _SeeDetailsLink extends StatelessWidget {
  final Transaction transaction;

  const _SeeDetailsLink({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final label = _localizedCopy(
      context,
      pt: 'ver detalhes',
      en: 'see details',
      es: 'ver detalles',
    );
    return Center(
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          TransactionDetailScreen.open(context, transaction);
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            decoration: TextDecoration.underline,
            decorationColor: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _TransactionDetailsTable extends StatelessWidget {
  final Transaction transaction;
  final TransactionCardColors colors;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;

  const _TransactionDetailsTable({
    required this.transaction,
    required this.colors,
    this.wallets = const [],
    this.accounts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final rows = _compactDetailRows(
      context,
      transaction,
      wallets,
      accounts: accounts,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Divider(height: 1, color: colors.divider),
                ),
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: _TransactionDetailsRow(row: rows[index], colors: colors),
              ),
            ],
            const SizedBox(height: 16),
            _SeeDetailsLink(transaction: transaction),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailsRow extends StatelessWidget {
  final _TransactionDetailRow row;
  final TransactionCardColors colors;

  const _TransactionDetailsRow({required this.row, required this.colors});

  @override
  Widget build(BuildContext context) {
    const ink = Colors.black;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          row.label,
          style: TextStyle(
            color: ink,
            fontFamily: AppTypography.bodyFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (row.copyValue != null) ...[
          const SizedBox(width: 6),
          _TransactionDetailCopyButton(row: row, colors: colors),
        ],
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            row.displayValue,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontFamily: row.displayValue.length > 20
                  ? AppTypography.financialFontFamily
                  : AppTypography.bodyFontFamily,
              fontSize: row.displayValue.length > 20 ? 12 : 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionDetailCopyButton extends StatelessWidget {
  final _TransactionDetailRow row;
  final TransactionCardColors colors;

  const _TransactionDetailCopyButton({required this.row, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr.copy,
      child: IconButton(
        key: ValueKey('statement-detail-copy-${row.key}'),
        onPressed: () => _copyDetail(context, row),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(KeroseneIcons.copy, size: 15, color: Colors.black),
      ),
    );
  }

  Future<void> _copyDetail(
    BuildContext context,
    _TransactionDetailRow row,
  ) async {
    final value = row.copyValue;
    if (value == null) return;

    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _localizedCopy(
              context,
              pt: 'Detalhe copiado.',
              en: 'Transaction detail copied.',
              es: 'Detalle copiado.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: KeroseneMotion.loop,
        ),
      );
  }
}

class _TransactionDetailRow {
  final String key;
  final String label;
  final String displayValue;
  final String? copyValue;

  const _TransactionDetailRow({
    required this.key,
    required this.label,
    required this.displayValue,
    this.copyValue,
  });
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String? _copyValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _titleCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _localizedCopy(
  BuildContext context, {
  required String pt,
  required String en,
  required String es,
}) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => en,
    'es' => es,
    _ => pt,
  };
}

class _AnimatedRingIconWrapper extends StatefulWidget {
  final Transaction transaction;
  final TransactionVisualSpec visual;
  final TransactionCardColors colors;
  final double iconSize;
  final bool expanded;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;

  const _AnimatedRingIconWrapper({
    required this.transaction,
    required this.visual,
    required this.colors,
    required this.iconSize,
    required this.expanded,
    this.wallets = const [],
    this.accounts = const [],
  });

  @override
  State<_AnimatedRingIconWrapper> createState() =>
      _AnimatedRingIconWrapperState();
}

class _AnimatedRingIconWrapperState extends State<_AnimatedRingIconWrapper>
    with TickerProviderStateMixin {
  /// Yellow full-ring spin at 0 backend confirmations.
  late final AnimationController _spinController;

  /// Green "loading" pulse on the next confirmation segment.
  late final AnimationController _loadController;

  static const Color _yellow = Color(0xFFE0A012);
  static const Color _green = Color(0xFF34C759);
  static const Color _red = Color(0xFFFF453A);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _loadController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.loop,
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant _AnimatedRingIconWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.confirmations !=
            widget.transaction.confirmations ||
        oldWidget.transaction.status != widget.transaction.status ||
        oldWidget.transaction.isUnconfirmedExpired !=
            widget.transaction.isUnconfirmedExpired) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    final mode = _ringMode(widget.transaction);
    switch (mode) {
      case _RingMode.yellowSpin:
        if (!_spinController.isAnimating) _spinController.repeat();
        _loadController
          ..stop()
          ..value = 0;
      case _RingMode.greenProgress:
        _spinController
          ..stop()
          ..value = 0;
        if (!_loadController.isAnimating) _loadController.repeat(reverse: true);
      case _RingMode.settled:
      case _RingMode.failed:
        _spinController
          ..stop()
          ..value = 0;
        _loadController
          ..stop()
          ..value = 0;
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  /// On-chain confs = **backend only**. Internal/LN: full ring when settled.
  int _backendConfirmations(Transaction tx) {
    if (tx.isUnconfirmedExpired ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.displayStatus == TransactionStatus.cancelled ||
        tx.displayStatus == TransactionStatus.reconciling) {
      return 0;
    }
    if (!tx.showsOnchainConfirmations) {
      return tx.displayStatus == TransactionStatus.confirmed
          ? tx.onchainConfirmationTarget
          : 0;
    }
    // Do not invent confs from status alone when payload is 0 and still open.
    return tx.confirmations.clamp(0, tx.onchainConfirmationTarget);
  }

  _RingMode _ringMode(Transaction tx) {
    if (tx.isUnconfirmedExpired ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.displayStatus == TransactionStatus.cancelled) {
      return _RingMode.failed;
    }
    if (tx.displayStatus == TransactionStatus.reconciling) {
      return _RingMode.yellowSpin;
    }
    if (!tx.showsOnchainConfirmations) {
      if (tx.displayStatus == TransactionStatus.confirmed) {
        return _RingMode.settled;
      }
      if (tx.displayStatus == TransactionStatus.pending ||
          tx.displayStatus == TransactionStatus.confirming) {
        return _RingMode.yellowSpin;
      }
      return _RingMode.settled;
    }
    final conf = tx.confirmations;
    final target = tx.onchainConfirmationTarget;
    if (conf <= 0 &&
        (tx.displayStatus == TransactionStatus.pending ||
            tx.displayStatus == TransactionStatus.confirming)) {
      return _RingMode.yellowSpin;
    }
    if (conf >= target || tx.displayStatus == TransactionStatus.confirmed) {
      return _RingMode.settled;
    }
    if (conf > 0) return _RingMode.greenProgress;
    return _RingMode.settled;
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final mode = _ringMode(tx);
    final conf = _backendConfirmations(tx);
    final target = tx.onchainConfirmationTarget;
    final isSettledVisual = mode == _RingMode.settled;

    return SizedBox(
      width: widget.iconSize,
      height: widget.iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_spinController, _loadController]),
            builder: (context, _) {
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
                  spinValue: _spinController.value,
                  loadValue: _loadController.value,
                ),
              );
            },
          ),
          Container(
            width: widget.iconSize * 0.78,
            height: widget.iconSize * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colors.iconWell,
            ),
            alignment: Alignment.center,
            child: AnimatedCrossFade(
              duration: KeroseneMotion.duration(context, KeroseneMotion.short),
              crossFadeState: widget.expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Icon(
                StatementTransactionCard._iconFor(
                  widget.transaction,
                  widget.visual,
                  wallets: widget.wallets,
                  accounts: widget.accounts,
                ),
                color: widget.colors.icon,
                size: widget.iconSize * 0.45,
              ),
              secondChild: Text(
                isSettledVisual && conf <= 0
                    ? 'OK'
                    : tx.isUnconfirmedExpired
                        ? '!'
                        : '$conf/$target',
                style: TextStyle(
                  color: widget.colors.icon,
                  fontFamily: AppTypography.bodyFontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: widget.iconSize * 0.28,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RingMode { yellowSpin, greenProgress, settled, failed }

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
    final origin = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;
    final strokeWidth = 2.6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (mode == _RingMode.yellowSpin) {
      // Full yellow arc spinning around the icon (0 confirmations).
      paint.color = yellowColor;
      final start = -math.pi / 2 + spinValue * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        start,
        math.pi * 1.35,
        false,
        paint,
      );
      paint.color = yellowColor.withValues(alpha: 0.22);
      canvas.drawCircle(origin, radius, paint);
      return;
    }

    final ringCount = target.clamp(3, 6);
    const gapRadians = 0.18;
    final sweep = (2 * math.pi / ringCount) - gapRadians;
    final startOffset = -math.pi / 2 + gapRadians / 2;
    final filled = confirmations.clamp(0, ringCount);

    for (var i = 0; i < ringCount; i++) {
      if (mode == _RingMode.failed) {
        paint.color = i == 0 ? failedColor : inactiveColor;
      } else if (mode == _RingMode.settled) {
        paint.color = greenColor;
      } else if (i < filled) {
        // Confirmed slices — solid green.
        paint.color = greenColor;
      } else if (i == filled && mode == _RingMode.greenProgress) {
        // Next confirmation — green loading pulse.
        paint.color = Color.lerp(
              greenColor.withValues(alpha: 0.25),
              greenColor,
              loadValue,
            ) ??
            greenColor.withValues(alpha: 0.6);
      } else {
        paint.color = inactiveColor;
      }

      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        startOffset + i * (2 * math.pi / ringCount),
        sweep,
        false,
        paint,
      );
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


