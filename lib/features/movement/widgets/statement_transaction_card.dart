import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/activity_cancel.dart';
import 'package:kerosene/features/movement/domain/transaction_presentation.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/movement/screens/transaction_detail_screen.dart';
import 'package:kerosene/features/movement/widgets/activity_glyph.dart';
import 'package:kerosene/features/movement/widgets/transaction_palette.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/core/theme/app_typography.dart';

enum StatementTransactionCardMode { stacked, separated }

/// How much chrome the card carries.
///
/// - [home]: quick scan only — glyph + amount; expand is just actions + "details".
/// - [full]: extrato — can show field table when expanded.
enum StatementTransactionCardDensity { home, full }

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
  final StatementTransactionCardDensity density;

  /// Optional paper override (home ledger tab: onchain/cold/total).
  final Color? paperBackground;
  final Color? paperBorder;

  const StatementTransactionCard({
    super.key,
    required this.transaction,
    this.expanded = false,
    this.onTap,
    this.mode = StatementTransactionCardMode.stacked,
    this.density = StatementTransactionCardDensity.full,
    this.paperBackground,
    this.paperBorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyFormatConfigProvider);
    final selectedCurrency = money.currency;
    // Home skips multi-fiat price watches when not needed for the primary label
    // path — presentation still may need them for amount format.
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final wallets = _walletsFromRef(ref);
    final accounts = _accountsFromRef(ref);
    final colors = TransactionCardColors.resolve(
      transaction,
      wallets: wallets,
      accounts: accounts,
      paperBackground: paperBackground,
      paperBorder: paperBorder,
    );
    final presentation = TransactionPresentation.fromTransaction(
      context,
      transaction,
      wallets: wallets,
      accounts: accounts,
      displayCurrency: selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: money.locale,
    );
    final amountLabel = presentation.primaryAmountLabel;
    final title = presentation.title;
    final counterparty = presentation.subtitle;
    final timestampLabel = presentation.tertiary;
    final isHome = density == StatementTransactionCardDensity.home;
    final compact = mode == StatementTransactionCardMode.stacked && !expanded;
    final cardPadding = isHome ? 14.0 : (compact ? 16.0 : 20.0);
    final iconSize = isHome ? 40.0 : (compact ? 42.0 : 48.0);
    final titleFontSize = isHome ? 14.5 : (compact ? 15.0 : 17.0);
    final counterpartyFontSize = isHome ? 11.5 : (compact ? 12.0 : 13.0);

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
      );
    }

    final a11yLabel = [
      title,
      counterparty,
      amountLabel,
      timestampLabel,
      if (expanded) 'expandido',
    ].where((s) => s.trim().isNotEmpty).join('. ');

    // Home: no AnimatedContainer / heavy shadows — list scroll stays cheap.
    final decoration = BoxDecoration(
      color: colors.background,
      borderRadius: BorderRadius.circular(isHome ? 20 : 28),
      border: Border.all(color: colors.border),
      boxShadow: isHome
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ActivityStatusIcon(
              transaction: transaction,
              colors: colors,
              iconSize: iconSize,
              axes: presentation.axes,
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
                  if (!isHome || counterparty.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      counterparty,
                      maxLines: isHome ? 1 : 2,
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
                    color: colors.title,
                    fontSize: isHome ? 15 : 16,
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
                    fontSize: isHome ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 1.2s ease-in-out: slow start → fast middle → slow end (open & close).
        AnimatedSize(
          duration: KeroseneMotion.duration(
            context,
            const Duration(milliseconds: 1200),
          ),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: isHome
                      ? _HomeQuickExpand(
                          transaction: transaction,
                          presentation: presentation,
                          colors: colors,
                        )
                      : _TransactionDetailsTable(
                          transaction: transaction,
                          presentation: presentation,
                          colors: colors,
                        ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      label: a11yLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isHome ? 20 : 28),
          // Allow check / conf badges to paint outside the icon box.
          child: Container(
            clipBehavior: Clip.none,
            padding: EdgeInsets.all(cardPadding),
            decoration: decoration,
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

List<BitcoinAccount> _accountsFromRef(WidgetRef ref) {
  return ref.watch(bitcoinAccountsProvider).asData?.value ??
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

  const _BankStatementTransactionRow({
    required this.transaction,
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
    final statusLine = presentation.statusLabel;
    // Amounts stay neutral (white/ink); status lives in the pill, not the value.
    final amountColor = TransactionPalette.inkOnDark;

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
                  ActivityGlyph.forAxes(
                    presentation.axes,
                    size: 40,
                  ),
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
                          statusLine,
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
                        child: _TransactionDetailsTable(
                          transaction: transaction,
                          presentation: presentation,
                          colors: TransactionCardColors.resolve(
                            transaction,
                            wallets: wallets,
                            accounts: accounts,
                          ),
                          dark: true,
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


class _DarkStatusPill extends StatelessWidget {
  final Transaction transaction;

  const _DarkStatusPill({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tone = TransactionPalette.toneFor(transaction);
    final fg = TransactionPalette.statusStrong(tone);
    final axes = TransactionAxes.classify(transaction);
    final label =
        TransactionPresentationCopy.of(context).lifecycleLabel(axes.lifecycle);
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

class _TransactionDetailsTable extends StatelessWidget {
  final Transaction transaction;
  final TransactionPresentation presentation;
  final TransactionCardColors colors;
  final bool dark;

  const _TransactionDetailsTable({
    required this.transaction,
    required this.presentation,
    required this.colors,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = presentation.expandedFields;
    final labelColor =
        dark ? const Color(0xFFC8CCD4) : const Color(0xFF1C1C1F);
    final valueColor =
        dark ? const Color(0xFFF4F5F7) : const Color(0xFF0A0A0B);
    final lineColor =
        dark ? const Color(0xFF3A3A40) : const Color(0xFFD4D4D8);

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
          _ActivityExpandedActions(
            transaction: transaction,
            dark: dark,
          ),
          const SizedBox(height: 8),
          _SeeDetailsLink(transaction: transaction, dark: dark),
        ],
      ),
    );
  }
}

/// Home expand: curated fields by rail/product + cancel + full dossier link.
class _HomeQuickExpand extends StatelessWidget {
  final Transaction transaction;
  final TransactionPresentation presentation;
  final TransactionCardColors colors;

  const _HomeQuickExpand({
    required this.transaction,
    required this.presentation,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final rows = presentation.listExpandFields;
    const labelColor = Color(0xFF1C1C1F);
    const valueColor = Color(0xFF0A0A0B);
    // Solid divider — same weight on every paper wash.
    const lineColor = Color(0xFFD0D0D4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isNotEmpty) ...[
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: ColoredBox(
                  color: lineColor,
                  child: SizedBox(height: 1, width: double.infinity),
                ),
              ),
            _PresentationFieldRow(
              field: rows[i],
              labelColor: labelColor,
              valueColor: valueColor,
            ),
          ],
          const SizedBox(height: 12),
        ],
        _ActivityExpandedActions(transaction: transaction, dark: false),
        const SizedBox(height: 4),
        _SeeDetailsLink(transaction: transaction, dark: false),
      ],
    );
  }
}

/// Cancel / Archive now on expanded home + extrato cards.
class _ActivityExpandedActions extends ConsumerStatefulWidget {
  final Transaction transaction;
  final bool dark;

  const _ActivityExpandedActions({
    required this.transaction,
    required this.dark,
  });

  @override
  ConsumerState<_ActivityExpandedActions> createState() =>
      _ActivityExpandedActionsState();
}

class _ActivityExpandedActionsState
    extends ConsumerState<_ActivityExpandedActions> {
  bool _busy = false;

  Transaction get tx => widget.transaction;

  bool get _canCancel => tx.cancellable && !_busy;

  bool get _canArchiveNow {
    if (!tx.isArchiveEligible || _busy) return false;
    final archived = ref.watch(activityArchiveProvider);
    return !archived.contains(tx.id.trim());
  }

  Future<void> _confirmAndCancel() async {
    if (!_canCancel) return;
    final tr = context.tr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.txDetailCancelTitle),
        content: Text(tr.txDetailCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr.txDetailCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await cancelActivity(ref.read(transactionRepositoryProvider), tx);
      // Stay in global feed until user archives or opens detail.
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(paymentLinksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr.txDetailCancelSuccess),
          action: SnackBarAction(
            label: tr.activityArchiveNow,
            onPressed: () => unawaited(_archiveNow(silent: true)),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.txDetailCancelError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveNow({bool silent = false}) async {
    if (_busy && !silent) return;
    setState(() => _busy = true);
    try {
      await archiveActivity(
        ref.read(activityArchiveProvider.notifier),
        tx,
      );
      ref.invalidate(paymentLinksProvider);
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.activityArchiveNowSuccess)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCancel && !_canArchiveNow) {
      return const SizedBox.shrink();
    }
    final tr = context.tr;
    final error = Theme.of(context).colorScheme.error;
    final foreground = widget.dark ? TransactionPalette.inkOnDark : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canCancel)
          OutlinedButton(
            onPressed: _busy ? null : _confirmAndCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error.withValues(alpha: 0.55)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: error,
                    ),
                  )
                : Text(tr.txDetailCancelAction),
          ),
        if (_canArchiveNow) ...[
          if (_canCancel) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => unawaited(_archiveNow()),
            icon: Icon(KeroseneIcons.archive, size: 16, color: foreground),
            label: Text(tr.activityArchiveNow),
            style: OutlinedButton.styleFrom(
              foregroundColor: foreground,
              side: BorderSide(color: foreground.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
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
    final isConf = field.key == 'confirmations' && field.hasConfirmationProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                field.label,
                style: TextStyle(
                  color: labelColor,
                  fontFamily: AppTypography.bodyFontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      field.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: valueColor,
                        fontFamily: AppTypography.bodyFontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (field.copyable) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await Clipboard.setData(
                          ClipboardData(text: field.value),
                        );
                      },
                      child: Icon(
                        KeroseneIcons.copy,
                        size: 15,
                        color: labelColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (isConf) ...[
          const SizedBox(height: 8),
          _ConfirmationProgressLine(
            current: field.progressCurrent!,
            target: field.progressTarget!,
            dark: dark,
          ),
        ],
      ],
    );
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
  static const _yellow = Color(0xFFE0A012);
  static const _yellowDone = Color(0xFF34C759);

  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_isComplete) {
      _shimmer.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ConfirmationProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isComplete) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  bool get _isComplete => widget.current >= widget.target;

  /// e.g. 1 conf of 4 → 25%; of 6 → ~16.7%. Uses conf/target.
  double get _filled =>
      (widget.current / widget.target).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final trackBase =
        widget.dark ? const Color(0xFF3A3A40) : const Color(0xFFE4E4E8);
    final trackHi =
        widget.dark ? const Color(0xFF55555C) : const Color(0xFFF0F0F3);
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
                  AnimatedBuilder(
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
                  )
                else
                  ColoredBox(color: trackBase),
                // Primary yellow (or green when complete) progress.
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: filledW,
                    height: 5,
                    color: fill,
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
      colors: [
        base,
        highlight,
        base,
      ],
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

  const _SeeDetailsLink({
    required this.transaction,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = TransactionPresentationCopy.of(context).viewDetails;
    final color = dark ? TransactionPalette.inkOnDark : Colors.black;
    return Center(
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          TransactionDetailScreen.open(context, transaction);
        },
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            decoration: TextDecoration.underline,
            decorationColor: color.withValues(alpha: 0.55),
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

  const _ActivityStatusIcon({
    required this.transaction,
    required this.colors,
    required this.iconSize,
    this.axes,
    this.expanded = false,
  });

  @override
  State<_ActivityStatusIcon> createState() => _ActivityStatusIconState();
}

class _ActivityStatusIconState extends State<_ActivityStatusIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _spinController;

  static const Color _yellow = Color(0xFFE0A012);
  static const Color _green = Color(0xFF34C759);
  static const Color _red = Color(0xFFFF453A);

  @override
  void initState() {
    super.initState();
    _syncAnimations();
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
  }

  void _syncAnimations() {
    final mode = _ringMode(widget.transaction);
    final needsSpin =
        mode == _RingMode.yellowSpin || mode == _RingMode.greenProgress;
    if (needsSpin) {
      _spinController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
      if (!(_spinController!.isAnimating)) {
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
    if (tx.displayStatus == TransactionStatus.confirmed || tx.isConfirmed) {
      return true;
    }
    // Instant rails settle without block confs.
    if (_isInstantRail(tx) &&
        tx.displayStatus != TransactionStatus.pending &&
        tx.displayStatus != TransactionStatus.confirming &&
        tx.displayStatus != TransactionStatus.reconciling) {
      return true;
    }
    if (!_isInstantRail(tx) &&
        tx.confirmations >= tx.onchainConfirmationTarget) {
      return true;
    }
    return false;
  }

  _RingMode _ringMode(Transaction tx) {
    if (tx.isCancelled ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.isUnconfirmedExpired) {
      return _RingMode.failed;
    }
    if (tx.displayStatus == TransactionStatus.reconciling) {
      return _RingMode.yellowSpin;
    }
    // Internal / Lightning: solid green when settled (not segmented 6-slice).
    if (_isInstantRail(tx)) {
      if (_isConfirmedLike(tx)) return _RingMode.settledSolid;
      if (tx.displayStatus == TransactionStatus.pending ||
          tx.displayStatus == TransactionStatus.confirming) {
        return _RingMode.yellowSpin;
      }
      return _RingMode.settledSolid;
    }
    final conf = tx.confirmations;
    final target = tx.onchainConfirmationTarget;
    if (_isConfirmedLike(tx) || conf >= target) {
      return _RingMode.settled;
    }
    if (conf > 0) return _RingMode.greenProgress;
    if (tx.displayStatus == TransactionStatus.pending ||
        tx.displayStatus == TransactionStatus.confirming) {
      return _RingMode.yellowSpin;
    }
    return _RingMode.settled;
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final mode = _ringMode(tx);
    final conf = _backendConfirmations(tx);
    final target = tx.onchainConfirmationTarget.clamp(1, 6);
    final spin = _spinController;
    final onchain = !_isInstantRail(tx);
    final failed = mode == _RingMode.failed || tx.isCancelled;
    final settled = mode == _RingMode.settled ||
        mode == _RingMode.settledSolid ||
        _isConfirmedLike(tx);
    final fullOnchain = settled &&
        onchain &&
        (conf >= target ||
            tx.isConfirmed ||
            tx.displayStatus == TransactionStatus.confirmed);
    final confirmingOnchain =
        onchain && !failed && !settled && (mode == _RingMode.greenProgress ||
            mode == _RingMode.yellowSpin);

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

    // Center of the well: glyph when collapsed; ✓ / conf / ✕ only when expanded.
    Widget centerChild;
    if (widget.expanded && failed) {
      // Error/cancel: red X only while the card is open.
      centerChild = Icon(
        Icons.close_rounded,
        key: const ValueKey('icon-x'),
        size: widget.iconSize * 0.42,
        color: _red,
      );
    } else if (widget.expanded && settled) {
      // Confirmed (internal / LN / on-chain): green check inside.
      centerChild = Icon(
        Icons.check_rounded,
        key: ValueKey(fullOnchain ? 'icon-check-6' : 'icon-check'),
        size: widget.iconSize * 0.44,
        color: _green,
      );
    } else if (widget.expanded && confirmingOnchain) {
      // On-chain in progress: show conf count (and target) inside.
      centerChild = Text(
        conf > 0 ? '$conf/$target' : '0/$target',
        key: ValueKey('icon-conf-$conf'),
        style: TextStyle(
          color: conf > 0 ? _green : _yellow,
          fontFamily: AppTypography.bodyFontFamily,
          fontWeight: FontWeight.w800,
          fontSize: widget.iconSize * 0.22,
          height: 1,
          letterSpacing: -0.2,
        ),
      );
    } else {
      centerChild = ActivityGlyph(
        key: const ValueKey('icon-glyph'),
        spec: widget.axes != null
            ? ActivityGlyphSpec.fromAxes(widget.axes!)
            : ActivityGlyphSpec.fromTransaction(tx),
        size: widget.iconSize * 0.72,
        showWell: false,
        iconColor: widget.colors.icon,
        badgeWellColor: widget.colors.iconWellBorder,
        badgeIconColor: widget.colors.icon,
        wellBorder: widget.colors.iconWellBorder,
      );
    }

    // On-chain fully confirmed + expanded: small "6" under the check inside well.
    final showConfPip =
        widget.expanded && fullOnchain && !failed;

    return SizedBox(
      width: widget.iconSize,
      height: widget.iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (spin != null)
            AnimatedBuilder(
              animation: spin,
              builder: (_, __) => buildRing(
                spinValue: spin.value,
                loadValue: spin.value,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: showConfPip
                  ? Column(
                      key: const ValueKey('check-with-6'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: widget.iconSize * 0.36,
                          color: _green,
                        ),
                        Text(
                          '$target',
                          style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w800,
                            fontSize: widget.iconSize * 0.16,
                            height: 1,
                          ),
                        ),
                      ],
                    )
                  : centerChild,
            ),
          ),
        ],
      ),
    );
  }
}

enum _RingMode {
  yellowSpin,
  greenProgress,
  /// On-chain fully confirmed — segmented green ring (6 slices).
  settled,
  /// Internal / Lightning confirmed — continuous solid green ring.
  settledSolid,
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
    final origin = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.5;
    final strokeWidth = 2.6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (mode == _RingMode.yellowSpin) {
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

    if (mode == _RingMode.settledSolid) {
      // Instant rails: one continuous green ring (not 6 slices).
      paint.color = greenColor;
      canvas.drawCircle(origin, radius, paint);
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

    final ringCount = target.clamp(3, 6);
    const gapRadians = 0.18;
    final sweep = (2 * math.pi / ringCount) - gapRadians;
    final startOffset = -math.pi / 2 + gapRadians / 2;
    final filled = confirmations.clamp(0, ringCount);

    for (var i = 0; i < ringCount; i++) {
      if (mode == _RingMode.settled) {
        paint.color = greenColor;
      } else if (i < filled) {
        paint.color = greenColor;
      } else if (i == filled && mode == _RingMode.greenProgress) {
        // Next confirmation segment pulses with the animation clock.
        final t = (math.sin(loadValue * 2 * math.pi) + 1) / 2;
        paint.color = Color.lerp(
              greenColor.withValues(alpha: 0.28),
              greenColor,
              t,
            ) ??
            greenColor.withValues(alpha: 0.6);
      } else {
        paint.color = inactiveColor.withValues(alpha: 0.55);
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


