import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/data/activity_archive_store.dart';
import 'package:kerosene/features/movement/data/activity_cancel.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/movement/data/blockchain_explorer.dart';
import 'package:kerosene/features/movement/data/transaction_display.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_glyph.dart';
import 'package:kerosene/features/movement/presentation/activity/home_activity_surface.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_palette.dart';

/// Full-screen transaction dossier — black canvas, Newsreader title, staggered
/// field reveal. Opened from compact card "ver detalhes".
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  /// Opens with the same circular-reveal family as the notification center.
  static Future<void> open(
    BuildContext context,
    Transaction transaction, {
    Rect? originRect,
  }) {
    final size = MediaQuery.sizeOf(context);
    final origin = originRect ??
        keroseneOriginRectFromContext(context) ??
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 48,
          height: 48,
        );
    return Navigator.of(context).push<void>(
      keroseneCircularRevealRoute<void>(
        page: TransactionDetailScreen(transaction: transaction),
        originRect: origin,
        transitionDuration: KeroseneMotion.long,
        reverseTransitionDuration: KeroseneMotion.medium,
      ),
    );
  }

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _technicalExpanded = false;
  bool _cancelling = false;
  late Transaction _tx;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    // Cancelled items stay in the global feed until the user opens them;
    // opening the dossier moves them to Arquivadas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tx.isArchiveEligible) {
        unawaited(
          ref.read(activityArchiveProvider.notifier).markArchived(_tx.id),
        );
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Transaction get tx => _tx;

  Future<void> _confirmAndCancel() async {
    if (_cancelling || !tx.cancellable) return;
    final tr = context.tr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          tr.txDetailCancelTitle,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          tr.txDetailCancelBody,
          style: AppTypography.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
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

    setState(() => _cancelling = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final updated = await cancelActivity(repo, tx);
      if (!mounted) return;
      setState(() {
        _tx = updated;
        _cancelling = false;
      });
      // Refresh feeds; archive after cancel from open detail (already viewed).
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(paymentLinksProvider);
      if (updated.isArchiveEligible) {
        await archiveActivity(
          ref.read(activityArchiveProvider.notifier),
          updated,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.txDetailCancelSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.txDetailCancelError)),
      );
    }
  }

  List<Wallet> get _wallets {
    final state = ref.watch(walletProvider);
    if (state is WalletLoaded) return state.wallets;
    return const [];
  }

  List<BitcoinAccount> get _accounts {
    return ref.watch(bitcoinAccountsProvider).asData?.value ??
        const <BitcoinAccount>[];
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(moneyFormatConfigProvider);
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final presentation = TransactionPresentation.fromTransaction(
      context,
      tx,
      wallets: _wallets,
      accounts: _accounts,
      displayCurrency: money.currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: money.locale,
    );
    final actionTitle = presentation.title;
    final amountLabel = presentation.primaryAmountLabel;
    final btcLabel = money.formatAmountFromBtc(
      btcAmount: tx.signedAmountBTC,
      currency: Currency.btc,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      signed: true,
    );
    final copy = TransactionPresentationCopy.of(context);
    final network = copy.railShort(presentation.axes.rail);
    final statusLabel = presentation.statusLabel;

    final primaryRows = <_DetailRowData>[
      for (final field in presentation.expandedFields)
        _DetailRowData(
          field.label,
          field.value,
          copyable: field.copyable,
        ),
    ];

    final technicalRows = <_DetailRowData>[
      for (final field in presentation.technicalFields)
        _DetailRowData(
          field.label,
          field.value,
          copyable: field.copyable,
          mono: field.technical,
        ),
      _DetailRowData(copy.amountBtc, btcLabel),
      if (resolveTransactionFailureLabel(context, tx) != null)
        _DetailRowData(
          copy.reason,
          resolveTransactionFailureLabel(context, tx)!,
        ),
      _DetailRowData(copy.type, actionTitle),
      _DetailRowData(
        copy.dateTime,
        AppDateTime.formatFull(context, tx.timestamp),
      ),
      if (tx.showsOnchainConfirmations &&
          (tx.blockHash ?? '').trim().isNotEmpty)
        _DetailRowData(copy.blockHash, tx.blockHash!.trim(), copyable: true),
      if (tx.showsOnchainConfirmations &&
          (tx.blockchainTxid ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.onchainTxid,
          tx.blockchainTxid!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.paymentHash ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.paymentHash,
          tx.paymentHash!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.invoiceId ?? '').trim().isNotEmpty)
        _DetailRowData(copy.invoiceId, tx.invoiceId!.trim(), copyable: true),
      if ((tx.lightningInvoice ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.lightningInvoice,
          tx.lightningInvoice!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.externalReference ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.externalRef,
          tx.externalReference!.trim(),
          copyable: true,
        ),
      if ((tx.externalTransferId ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.externalTransferId,
          tx.externalTransferId!.trim(),
          copyable: true,
        ),
      if ((tx.externalTransferStatus ?? '').trim().isNotEmpty)
        _DetailRowData(copy.externalStatus, tx.externalTransferStatus!.trim()),
      if ((tx.externalTransferType ?? '').trim().isNotEmpty)
        _DetailRowData(copy.externalType, tx.externalTransferType!.trim()),
      if ((tx.walletId ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.yourWallet,
          tx.walletId!.trim(),
          copyable: true,
        ),
      if ((tx.sourceWalletId ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.sourceWallet,
          tx.sourceWalletId!.trim(),
          copyable: true,
        ),
      if ((tx.destinationWalletId ?? '').trim().isNotEmpty)
        _DetailRowData(
          copy.destinationWallet,
          tx.destinationWalletId!.trim(),
          copyable: true,
        ),
      if ((tx.senderDisplayName ?? '').trim().isNotEmpty)
        _DetailRowData(
          context.tr.sendReviewSender,
          tx.senderDisplayName!.trim(),
        ),
      if ((tx.receiverDisplayName ?? '').trim().isNotEmpty)
        _DetailRowData(
          context.tr.sendReviewDestination,
          tx.receiverDisplayName!.trim(),
        ),
      if ((tx.fromAddress).trim().isNotEmpty)
        _DetailRowData(
          copy.fromAddress,
          tx.fromAddress.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.toAddress).trim().isNotEmpty)
        _DetailRowData(
          copy.toAddress,
          tx.toAddress.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.description ?? '').trim().isNotEmpty)
        _DetailRowData(copy.description, tx.description!.trim()),
      _DetailRowData(copy.internalId, tx.id, copyable: true, mono: true),
      if (tx.displayAmountUsd != null)
        _DetailRowData(
          copy.frozenUsd,
          money.format(
            amount: tx.displayAmountUsd!,
            currency: Currency.usd,
          ),
        ),
      if (tx.displayAmountBrl != null)
        _DetailRowData(
          copy.frozenBrl,
          money.format(
            amount: tx.displayAmountBrl!,
            currency: Currency.brl,
          ),
        ),
      if (tx.displayAmountEur != null)
        _DetailRowData(
          copy.frozenEur,
          money.format(
            amount: tx.displayAmountEur!,
            currency: Currency.eur,
          ),
        ),
    ];

    final explorerUri = BlockchainExplorer.txUri(tx.blockchainTxid);

    return FinancialSecureScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Semantics(
            label: '$actionTitle. $amountLabel. $network. $statusLabel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          KeroseneIcons.back,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (explorerUri != null)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            unawaited(
                              BlockchainExplorer.openTx(tx.blockchainTxid),
                            );
                          },
                          child: Text(
                            SendMoneyCopy.detailExplorer(context),
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: AppTypography.caption.copyWith(
                            color: TransactionPalette.statusStrong(
                              TransactionPalette.toneFor(tx),
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                    children: [
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(0, 0.35, curve: Curves.easeOut),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ActivityGlyph.forAxes(
                              presentation.axes,
                              size: 56,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                actionTitle,
                                style: HomeTypography.heroTitle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0.08,
                            0.42,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: Text(
                          amountLabel,
                          style: AppTypography.financial(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0.12,
                            0.48,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: Text(
                          btcLabel,
                          style: AppTypography.inter(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0.14,
                            0.5,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Text(
                              network,
                              style: AppTypography.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (var i = 0; i < primaryRows.length; i++)
                        _StaggeredDetailRow(
                          animation: _entrance,
                          index: i,
                          total: primaryRows.length,
                          row: primaryRows[i],
                        ),
                      if (technicalRows.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _technicalExpanded = !_technicalExpanded,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    SendMoneyCopy.detailTechnical(context),
                                    style: AppTypography.inter(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _technicalExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_technicalExpanded)
                          for (var i = 0; i < technicalRows.length; i++)
                            _StaggeredDetailRow(
                              animation: _entrance,
                              index: i + primaryRows.length,
                              total: primaryRows.length + technicalRows.length,
                              row: technicalRows[i],
                            ),
                      ],
                      if (tx.cancellable) ...[
                        SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _cancelling ? null : _confirmAndCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.55),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _cancelling
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.tr.txDetailCancelAction),
                          ),
                        ),
                      ],
                    ],
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

class _DetailRowData {
  final String label;
  final String value;
  final bool copyable;
  final bool mono;

  const _DetailRowData(
    this.label,
    this.value, {
    this.copyable = false,
    this.mono = false,
  });
}

class _StaggeredDetailRow extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final int total;
  final _DetailRowData row;

  const _StaggeredDetailRow({
    required this.animation,
    required this.index,
    required this.total,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final start = (0.18 + (index / (total + 4)) * 0.7).clamp(0.0, 0.9);
    final end = (start + 0.18).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.base),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: row.mono
                                ? AppTypography.technicalMono(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    height: 1.35,
                                  )
                                : AppTypography.bodyMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    height: 1.35,
                                  ),
                          ),
                        ),
                        if (row.copyable) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await Clipboard.setData(
                                ClipboardData(text: row.value),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.maybeOf(context)
                                ?..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr.btcAccountsCopied),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                            },
                            child: Icon(
                              KeroseneIcons.copy,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
