import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/currency_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/screens/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/utils/transaction_address_display.dart';
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
    final selectedCurrency = ref.watch(currencyProvider);
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
    );
    final wallets = _walletsFromRef(ref);
    final accounts = _accountsFromRef(ref);
    final title = resolveTransactionActionTitle(context, transaction);
    final counterparty = _counterparty(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final date = transaction.timestamp.toLocal();
    final timestampLabel = _timeFormat.format(date);
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
        ),
        expanded: expanded,
        onTap: onTap,
        wallets: wallets,
        accounts: accounts,
      );
    }

    final motion = KeroseneMotion.duration(context, KeroseneMotion.medium);

    return Material(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.subtitle,
                              fontFamily: AppTypography.bodyFontFamily,
                              fontSize: counterpartyFontSize,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
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
  }) {
    final signedAmount = transaction.signedAmountBTC;
    return MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: signedAmount,
      currency: currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: transaction.displayAmountUsd,
      displayAmountEur: transaction.displayAmountEur,
      displayAmountBrl: transaction.displayAmountBrl,
      displayBtcUsd: transaction.displayBtcUsd,
      displayBtcEur: transaction.displayBtcEur,
      displayBtcBrl: transaction.displayBtcBrl,
      signed: true,
    );
  }

  static String _counterparty(
    BuildContext context,
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    final sent = tx.isDebit;
    final label = sent ? 'Para' : 'De';
    final value = sent
        ? resolveTransactionToParty(
            tx,
            wallets: wallets,
            accounts: accounts,
            compactHash: true,
          )
        : resolveTransactionFromParty(
            tx,
            wallets: wallets,
            accounts: accounts,
          );
    return '$label: $value';
  }

  static IconData _iconFor(Transaction tx, TransactionVisualSpec visual) {
    if (tx.isInternal) return KeroseneIcons.group;
    if (tx.isLightning) return KeroseneIcons.lightning;
    if (tx.status == TransactionStatus.failed ||
        tx.status == TransactionStatus.cancelled) {
      return KeroseneIcons.warning;
    }
    return KeroseneIcons.archive;
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

String _bankRailLabel(Transaction tx) {
  if (tx.isInternal) return 'Transferência interna';
  if (tx.isLightning) return 'Lightning';
  if (tx.type == TransactionType.deposit) return 'Depósito on-chain';
  if (tx.type == TransactionType.withdrawal) return 'Saque on-chain';
  return 'On-chain';
}

String _bankStatusLabel(Transaction tx) {
  return switch (tx.status) {
    TransactionStatus.confirmed => 'Confirmado',
    TransactionStatus.confirming => '${tx.confirmations} confirmações',
    TransactionStatus.pending => 'Pendente',
    TransactionStatus.cancelled => 'Cancelada',
    TransactionStatus.failed => 'Falhou',
  };
}

String _bankSubtitle(Transaction tx) {
  final local = tx.timestamp.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute · ${_bankRailLabel(tx)} · ${_bankStatusLabel(tx)}';
}

String _bankCounterparty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final label = tx.isDebit ? 'Para' : 'De';
  final value = tx.isDebit
      ? resolveTransactionToParty(
          tx,
          wallets: wallets,
          accounts: accounts,
          compactHash: true,
        )
      : resolveTransactionFromParty(
          tx,
          wallets: wallets,
          accounts: accounts,
        );
  return '$label $value';
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
    final title = resolveTransactionActionTitle(context, transaction);
    final counterparty = _bankCounterparty(
      transaction,
      wallets: wallets,
      accounts: accounts,
    );
    final subtitle = _bankSubtitle(transaction);
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
    if (transaction.isLightning) {
      return KeroseneIcons.lightning;
    }
    if (transaction.isInternal) {
      return KeroseneIcons.moveHorizontal;
    }
    return transaction.isCredit ? KeroseneIcons.receive : KeroseneIcons.send;
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
      TransactionStatusTone.failed => 'Falhou',
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
  final network = resolveTransactionNetworkLabel(transaction);
  final networkFeeLabel = transaction.hasNetworkFee || transaction.feeSatoshis > 0
      ? formatSatsAsBtc(transaction.feeSatoshis)
      : '—';
  final serviceFeeLabel = transaction.hasServiceFee
      ? formatSatsAsBtc(transaction.serviceFeeSatoshis)
      : '—';

  return [
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
    _TransactionDetailRow(
      key: 'network-fee',
      label: _localizedCopy(
        context,
        pt: 'Taxa de transação',
        en: 'Network fee',
        es: 'Tarifa de red',
      ),
      displayValue: networkFeeLabel,
    ),
    _TransactionDetailRow(
      key: 'service-fee',
      label: _localizedCopy(
        context,
        pt: 'Taxa de serviço',
        en: 'Service fee',
        es: 'Tarifa de servicio',
      ),
      displayValue: serviceFeeLabel,
    ),
    _TransactionDetailRow(
      key: 'network',
      label: _localizedCopy(context, pt: 'Rede', en: 'Network', es: 'Red'),
      displayValue: network,
    ),
  ];
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

/// Compact confirmation rings at the bottom-right of a statement card.
///
/// Visual language:
/// - **Confirmed** — calm light green, static
/// - **Pending** (waiting, 0 confs) — orange, static
/// - **Confirming** (network progress) — orange with a soft pulse + sweep
/// - **Cancelled / failed** — red, static
///
/// Tap expands a short confirmation count label from the circle.
class _ConfirmationRingsIndicator extends StatefulWidget {
  final Transaction transaction;

  const _ConfirmationRingsIndicator({required this.transaction});

  @override
  State<_ConfirmationRingsIndicator> createState() =>
      _ConfirmationRingsIndicatorState();
}

enum _ConfirmationRingPhase {
  confirmed,
  confirming,
  pending,
  cancelled,
  failed,
}

class _ConfirmationRingsIndicatorState
    extends State<_ConfirmationRingsIndicator>
    with SingleTickerProviderStateMixin {
  static const int _ringCount = 3;
  static const int _targetConfirmations = 6;
  static const double _circleSize = 19;

  late final AnimationController _confirmingController;
  bool _labelOpen = false;

  Transaction get _tx => widget.transaction;

  TransactionStatusTone get _tone => TransactionPalette.toneFor(_tx);

  _ConfirmationRingPhase get _phase {
    return switch (_tone) {
      TransactionStatusTone.cancelled => _ConfirmationRingPhase.cancelled,
      TransactionStatusTone.failed => _ConfirmationRingPhase.failed,
      TransactionStatusTone.confirmed => _ConfirmationRingPhase.confirmed,
      TransactionStatusTone.confirming => _ConfirmationRingPhase.confirming,
      TransactionStatusTone.pending => _ConfirmationRingPhase.pending,
    };
  }

  bool get _shouldAnimate => _phase == _ConfirmationRingPhase.confirming;

  int get _filledRings {
    switch (_phase) {
      case _ConfirmationRingPhase.confirmed:
        return _ringCount;
      case _ConfirmationRingPhase.cancelled:
      case _ConfirmationRingPhase.failed:
      case _ConfirmationRingPhase.pending:
        return 0;
      case _ConfirmationRingPhase.confirming:
        final conf = _tx.confirmations.clamp(0, _targetConfirmations);
        if (conf <= 0) return 0;
        return ((conf / _targetConfirmations) * _ringCount)
            .ceil()
            .clamp(1, _ringCount);
    }
  }

  int get _displayCurrent {
    if (_phase == _ConfirmationRingPhase.confirmed) {
      return _targetConfirmations;
    }
    return _tx.confirmations.clamp(0, _targetConfirmations);
  }

  Color get _activeColor => TransactionPalette.statusStrong(_tone);

  Color get _centerColor => TransactionPalette.statusSoft(_tone);

  Color get _inactiveColor => TransactionPalette.statusTrack;

  String get _labelText {
    return switch (_phase) {
      _ConfirmationRingPhase.cancelled => 'Cancelada',
      _ConfirmationRingPhase.failed => 'Falhou',
      _ConfirmationRingPhase.confirmed =>
        '$_targetConfirmations de $_targetConfirmations confirmações',
      _ConfirmationRingPhase.pending => 'Aguardando confirmações',
      _ConfirmationRingPhase.confirming =>
        '$_displayCurrent de $_targetConfirmations confirmações',
    };
  }

  @override
  void initState() {
    super.initState();
    _confirmingController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.loop,
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ConfirmationRingsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.status != widget.transaction.status ||
        oldWidget.transaction.confirmations !=
            widget.transaction.confirmations ||
        oldWidget.transaction.id != widget.transaction.id) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _confirmingController.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (_shouldAnimate) {
      if (!_confirmingController.isAnimating) {
        _confirmingController.repeat(reverse: true);
      }
    } else {
      _confirmingController
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = KeroseneMotion.duration(context, KeroseneMotion.short);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Absorb the tap so the parent card does not expand/collapse.
        HapticFeedback.selectionClick();
        setState(() => _labelOpen = !_labelOpen);
      },
      child: AnimatedSize(
        duration: motion,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_labelOpen) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 148),
                child: Text(
                  _labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _activeColor,
                    fontFamily: AppTypography.bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            SizedBox(
              width: _circleSize,
              height: _circleSize,
              child: AnimatedBuilder(
                animation: _confirmingController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfirmationRingsPainter(
                      filledRings: _filledRings,
                      ringCount: _ringCount,
                      activeColor: _activeColor,
                      inactiveColor: _inactiveColor,
                      centerColor: _centerColor,
                      animating: _shouldAnimate,
                      // 0→1→0 when reverse; used for pulse + soft sweep.
                      animationValue: _confirmingController.value,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRingsPainter extends CustomPainter {
  final int filledRings;
  final int ringCount;
  final Color activeColor;
  final Color inactiveColor;
  final Color centerColor;
  final bool animating;
  final double animationValue;

  const _ConfirmationRingsPainter({
    required this.filledRings,
    required this.ringCount,
    required this.activeColor,
    required this.inactiveColor,
    required this.centerColor,
    this.animating = false,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    // Thin rings so the filled center can grow until it nearly meets them.
    final strokeWidth = outerRadius * 0.13;
    final ringRadius = outerRadius - strokeWidth / 2 - 0.4;
    final ringInnerEdge = ringRadius - strokeWidth / 2;
    // ~1.2 logical px air gap between disk and arcs.
    final baseCenterRadius =
        math.max(outerRadius * 0.52, ringInnerEdge - 1.2);
    // Subtle breathing only while confirming (product: “network is working”).
    final pulse = animating ? 1.0 + (0.06 * animationValue) : 1.0;
    final centerRadius = baseCenterRadius * pulse;
    final gapRadians = 0.32;
    final sweep = (2 * math.pi / ringCount) - gapRadians;
    final startOffset = -math.pi / 2 + gapRadians / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var i = 0; i < ringCount; i++) {
      final filled = i < filledRings;
      ringPaint.color = filled ? activeColor : inactiveColor;
      if (animating && filled) {
        // Filled arcs gently brighten with the pulse.
        ringPaint.color = Color.lerp(
              activeColor,
              activeColor.withValues(alpha: 0.72),
              animationValue,
            ) ??
            activeColor;
      }
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: ringRadius),
        startOffset + i * (2 * math.pi / ringCount),
        sweep,
        false,
        ringPaint,
      );
    }

    // Soft orange “next ring” highlight while confirming — draws attention to
    // the segment still waiting, without spinning like a generic spinner.
    if (animating && filledRings < ringCount) {
      final nextIndex = filledRings;
      final segmentStart =
          startOffset + nextIndex * (2 * math.pi / ringCount);
      final highlightSweep = sweep * (0.28 + 0.52 * animationValue);
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.15
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = activeColor.withValues(alpha: 0.35 + 0.45 * animationValue);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: ringRadius),
        segmentStart,
        highlightSweep,
        false,
        highlightPaint,
      );
    }

    // Soft outer glow while confirming — reads as “live” without dominating the card.
    if (animating) {
      canvas.drawCircle(
        origin,
        centerRadius * 1.18,
        Paint()
          ..style = PaintingStyle.fill
          ..color = centerColor.withValues(alpha: 0.18 + 0.14 * animationValue)
          ..isAntiAlias = true
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
    }

    canvas.drawCircle(
      origin,
      centerRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = centerColor
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfirmationRingsPainter oldDelegate) {
    return oldDelegate.filledRings != filledRings ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.centerColor != centerColor ||
        oldDelegate.animating != animating ||
        oldDelegate.animationValue != animationValue;
  }
}

class _AnimatedRingIconWrapper extends StatefulWidget {
  final Transaction transaction;
  final TransactionVisualSpec visual;
  final TransactionCardColors colors;
  final double iconSize;
  final bool expanded;

  const _AnimatedRingIconWrapper({
    required this.transaction,
    required this.visual,
    required this.colors,
    required this.iconSize,
    required this.expanded,
  });

  @override
  State<_AnimatedRingIconWrapper> createState() => _AnimatedRingIconWrapperState();
}

class _AnimatedRingIconWrapperState extends State<_AnimatedRingIconWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.loop,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _AnimatedRingIconWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.confirmations !=
            widget.transaction.confirmations ||
        oldWidget.transaction.status != widget.transaction.status) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final conf = widget.transaction.confirmations.clamp(0, 6);
    final needsPulse = conf < 6 &&
        (widget.transaction.status == TransactionStatus.confirming ||
            widget.transaction.status == TransactionStatus.pending);
    if (needsPulse) {
      if (!_pulseController.isAnimating) {
        // Color pulse only — ring geometry stays fixed (no rotation).
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final int conf = tx.confirmations.clamp(0, 6);
    final bool isConfirmed = conf >= 6;

    return SizedBox(
      width: widget.iconSize,
      height: widget.iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              // Ring stays fixed; only unconfirmed segments pulse in color.
              return CustomPaint(
                size: Size(widget.iconSize, widget.iconSize),
                painter: _RingConfirmationPainter(
                  confirmations: conf,
                  activeColor: const Color(0xFF34C759),
                  inactiveColor: widget.colors.iconWellBorder,
                  pulseValue: _pulseController.value,
                  isPulsing: !isConfirmed,
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
                ),
                color: widget.colors.icon,
                size: widget.iconSize * 0.45,
              ),
              secondChild: Text(
                '$conf/6',
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

class _RingConfirmationPainter extends CustomPainter {
  final int confirmations;
  final Color activeColor;
  final Color inactiveColor;
  final double pulseValue;
  final bool isPulsing;

  _RingConfirmationPainter({
    required this.confirmations,
    required this.activeColor,
    required this.inactiveColor,
    required this.pulseValue,
    required this.isPulsing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;
    final strokeWidth = 2.5;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const ringCount = 6;
    const gapRadians = 0.20;
    final sweep = (2 * math.pi / ringCount) - gapRadians;
    final startOffset = -math.pi / 2 + gapRadians / 2;

    for (var i = 0; i < ringCount; i++) {
      final isFilled = i < confirmations;
      // Fixed geometry: filled = confirmed color; current pending = color load pulse.
      if (isFilled) {
        ringPaint.color = activeColor;
      } else if (isPulsing && i == confirmations) {
        ringPaint.color = Color.lerp(
              inactiveColor,
              activeColor.withValues(alpha: 0.75),
              pulseValue,
            ) ??
            activeColor.withValues(alpha: 0.5);
      } else {
        ringPaint.color = inactiveColor;
      }

      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        startOffset + i * (2 * math.pi / ringCount),
        sweep,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingConfirmationPainter oldDelegate) {
    return confirmations != oldDelegate.confirmations ||
           pulseValue != oldDelegate.pulseValue;
  }
}


