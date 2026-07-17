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
    final wallets = _walletsFromRef(ref);
    final accounts = _accountsFromRef(ref);
    final colors = TransactionCardColors.resolve(
      transaction,
      wallets: wallets,
      accounts: accounts,
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
    final compact = mode == StatementTransactionCardMode.stacked && !expanded;
    final cardPadding = compact ? 16.0 : 20.0;
    final iconSize = compact ? 42.0 : 48.0;
    final titleFontSize = compact ? 15.0 : 17.0;
    final counterpartyFontSize = compact ? 12.0 : 13.0;

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
                      // Composite: rail primary + direction badge (status = ring).
                      axes: presentation.axes,
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
                      presentation: presentation,
                      colors: colors,
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
    final labelColor = dark ? TransactionPalette.inkTertiary : Colors.black;
    final valueColor = dark ? TransactionPalette.inkOnDark : Colors.black;
    final divider = dark ? AppColors.hexFF222222 : colors.divider;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Divider(height: 1, color: divider),
                ),
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: _PresentationFieldRow(
                  field: rows[index],
                  labelColor: labelColor,
                  valueColor: valueColor,
                ),
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
      ),
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

  const _PresentationFieldRow({
    required this.field,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            field.label,
            style: TextStyle(
              color: labelColor,
              fontFamily: AppTypography.bodyFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (field.copyable) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await Clipboard.setData(ClipboardData(text: field.value));
                  },
                  child: Icon(
                    KeroseneIcons.copy,
                    size: 14,
                    color: labelColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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

class _AnimatedRingIconWrapper extends StatefulWidget {
  final Transaction transaction;
  final TransactionVisualSpec visual;
  final TransactionCardColors colors;
  final double iconSize;
  final bool expanded;
  final List<Wallet> wallets;
  final List<BitcoinAccount> accounts;
  final TransactionAxes? axes;

  const _AnimatedRingIconWrapper({
    required this.transaction,
    required this.visual,
    required this.colors,
    required this.iconSize,
    required this.expanded,
    this.wallets = const [],
    this.accounts = const [],
    this.axes,
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

  /// On-chain confs = **backend only**. Lightning/internal never use N/6 confs.
  int _backendConfirmations(Transaction tx) {
    if (tx.isLightningEffective ||
        tx.isInternal ||
        !tx.showsOnchainConfirmations) {
      return 0;
    }
    if (tx.isUnconfirmedExpired ||
        tx.displayStatus == TransactionStatus.failed ||
        tx.displayStatus == TransactionStatus.cancelled ||
        tx.displayStatus == TransactionStatus.reconciling) {
      return 0;
    }
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
    // Lightning / internal: no block-conf ring segments — settled or soft pending.
    if (tx.isLightningEffective ||
        tx.isInternal ||
        !tx.showsOnchainConfirmations) {
      if (tx.displayStatus == TransactionStatus.confirmed) {
        return _RingMode.settled;
      }
      if (tx.displayStatus == TransactionStatus.pending ||
          tx.displayStatus == TransactionStatus.confirming) {
        // Soft amber spin = "em processamento", never 0/6 conf UI.
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
              firstChild: ActivityGlyph(
                spec: widget.axes != null
                    ? ActivityGlyphSpec.fromAxes(widget.axes!)
                    : ActivityGlyphSpec.fromTransaction(tx),
                size: widget.iconSize * 0.72,
                showWell: false,
                iconColor: widget.colors.icon,
                badgeWellColor: widget.colors.iconWellBorder,
                badgeIconColor: widget.colors.icon,
                wellBorder: widget.colors.iconWellBorder,
              ),
              secondChild: Text(
                // Never show N/6 for Lightning or internal.
                (tx.isLightningEffective ||
                        tx.isInternal ||
                        !tx.showsOnchainConfirmations)
                    ? (tx.isUnconfirmedExpired ||
                            tx.displayStatus == TransactionStatus.failed
                        ? '!'
                        : isSettledVisual
                            ? 'OK'
                            : '…')
                    : isSettledVisual && conf <= 0
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


