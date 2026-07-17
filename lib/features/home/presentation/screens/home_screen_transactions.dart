// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/movement/domain/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/transaction_filter_engine.dart';

import 'home_screen_dependencies.dart';
import 'home_screen.dart';
import 'home_screen_surface.dart';

ActivityFilter _mapHomeActivityFilter(HomeActivityFilter filter) {
  return switch (filter) {
    HomeActivityFilter.all => ActivityFilter.all,
    HomeActivityFilter.incoming => ActivityFilter.incoming,
    HomeActivityFilter.outgoing => ActivityFilter.outgoing,
    HomeActivityFilter.internal => ActivityFilter.instant,
    HomeActivityFilter.onchain => ActivityFilter.onchain,
    HomeActivityFilter.lightning => ActivityFilter.lightning,
    HomeActivityFilter.cold => ActivityFilter.cold,
    HomeActivityFilter.pending => ActivityFilter.inProgress,
    HomeActivityFilter.failed => ActivityFilter.problems,
    HomeActivityFilter.cancelled => ActivityFilter.cancelled,
    HomeActivityFilter.archived => ActivityFilter.archived,
  };
}

final filteredHomeTransactionsProvider =
    Provider.autoDispose<List<Transaction>>((ref) {
  final transactionsAsync = ref.watch(transactionHistoryProvider);
  final lastHistory = ref.watch(lastTransactionHistoryProvider);
  final txs = transactionsAsync.asData?.value ??
      (lastHistory.isNotEmpty ? lastHistory : null);

  if (txs == null) return const [];

  final filter = ref.watch(homeActivityFilterProvider);
  final walletState = ref.watch(walletProvider);
  final wallets = walletState is WalletLoaded
      ? walletState.wallets
      : const <Wallet>[];
  final accounts = ref.watch(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];
  final archivedIds = ref.watch(activityArchiveProvider);

  return TransactionFilterEngine.apply(
    source: txs,
    activity: _mapHomeActivityFilter(filter),
    wallets: wallets,
    accounts: accounts,
    archivedIds: archivedIds,
  );
});

class HomeTransactionsList extends ConsumerStatefulWidget {
  final VoidCallback onCreateWallet;
  final ValueChanged<Wallet> onDepositWallet;

  const HomeTransactionsList({
    super.key,
    required this.onCreateWallet,
    required this.onDepositWallet,
  });

  @override
  ConsumerState<HomeTransactionsList> createState() =>
      _HomeTransactionsListState();
}

class _HomeTransactionsListState extends ConsumerState<HomeTransactionsList> {
  /// Multiple cards may stay open; expansion only grows downward.
  final Set<String> _expandedTransactionIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final selectedFilter = ref.watch(homeActivityFilterProvider);
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    final lastHistory = ref.watch(lastTransactionHistoryProvider);
    final lastSync = ref.watch(transactionHistoryLastSyncProvider);
    final isOnline = ref.watch(networkStatusProvider);
    final hasWallet = ref.watch(walletProvider.select(
        (state) => state is WalletLoaded && state.wallets.isNotEmpty));
    final hasBalance = ref.watch(walletProvider.select((state) {
      if (state is WalletLoaded) {
        final w = state.selectedWallet ??
            (state.wallets.isNotEmpty ? state.wallets.first : null);
        return (w?.balance ?? 0) > 0;
      }
      return false;
    }));

    // Keep previous projection while reloading so the feed does not flash empty.
    final txs = transactionsAsync.asData?.value ??
        (lastHistory.isNotEmpty ? lastHistory : null);
    final isReloading = transactionsAsync.isLoading && txs != null;
    final hasError = transactionsAsync.hasError && txs == null;

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: StateFeedbackView.networkError(
          context: context,
          onAction: () => ref.refresh(transactionHistoryProvider),
        ),
      );
    }

    if (txs == null) {
      return const _TransactionsSkeletonLoading();
    }

    final filteredTxs = ref.watch(filteredHomeTransactionsProvider);
    final filterIsAll = selectedFilter == HomeActivityFilter.all;
    final filterIsCancelled =
        selectedFilter == HomeActivityFilter.cancelled;

    Widget body;
    if (filteredTxs.isEmpty) {
      // Clear-filter only on Cancelled (subtle). Other filters: empty copy only.
      final showClearOnCancelled = !filterIsAll && filterIsCancelled;
      final showPrimaryAction = filterIsAll;
      body = Padding(
        padding: EdgeInsets.zero,
        child: HomeEmptyTransactionsPanel(
          icon: !filterIsAll
              ? KeroseneIcons.history
              : !hasWallet
                  ? KeroseneIcons.wallet
                  : !hasBalance
                      ? KeroseneIcons.institution
                      : KeroseneIcons.history,
          title: !filterIsAll
              ? context.tr.homeFilterEmptyTitle
              : !hasWallet
                  ? context.tr.homeEmptyNoWalletTitle
                  : hasBalance
                      ? context.tr.homeHistoryEmptyTitle
                      : context.tr.homeEmptyNoBalanceTitle,
          description: !filterIsAll
              ? context.tr.homeFilterEmptyDesc
              : !hasWallet
                  ? context.tr.homeEmptyNoWalletDescription
                  : hasBalance
                      ? context.tr.homeHistoryEmptyDesc
                      : context.tr.homeEmptyNoBalanceDescription,
          actionLabel: showClearOnCancelled
              ? context.tr.homeClearFilter
              : !hasWallet
                  ? context.tr.homeCreateWalletAction
                  : hasBalance
                      ? context.tr.homeRefreshAction
                      : context.tr.homeDepositAction,
          actionIcon: showClearOnCancelled
              ? KeroseneIcons.close
              : !hasWallet
                  ? KeroseneIcons.next
                  : hasBalance
                      ? KeroseneIcons.refresh
                      : KeroseneIcons.download,
          onAction: () {
            if (showClearOnCancelled) {
              ref.read(homeActivityFilterProvider.notifier).state =
                  HomeActivityFilter.all;
              return;
            }
            if (!hasWallet) {
              widget.onCreateWallet();
              return;
            }
            if (!hasBalance) {
              final state = ref.read(walletProvider);
              if (state is WalletLoaded) {
                final w = state.selectedWallet ??
                    (state.wallets.isNotEmpty ? state.wallets.first : null);
                if (w != null) widget.onDepositWallet(w);
              }
              return;
            }
            unawaited(refreshFinancialProjectionUi(ref, forceFullHistory: true));
          },
          showAction: showPrimaryAction || showClearOnCancelled,
          subtleAction: showClearOnCancelled,
          blackSurface: true,
          plainCenteredIcon: true,
          serifTitle: true,
        ),
      );
    } else {
      body = StatementTransactionScrollStack(
        itemCount: filteredTxs.length,
        itemGap: homeSize(12),
        itemBuilder: (context, index) {
          final tx = filteredTxs[index];

          Widget? dateHeader;
          if (index == 0) {
            dateHeader = _buildDateHeader(tx.timestamp.toLocal());
          } else {
            final previousTx = filteredTxs[index - 1];
            if (!_isSameDay(
              tx.timestamp.toLocal(),
              previousTx.timestamp.toLocal(),
            )) {
              dateHeader = _buildDateHeader(tx.timestamp.toLocal());
            }
          }

          final tile = _buildTransactionTile(
            tx,
            expanded: _expandedTransactionIds.contains(tx.id),
          );

          if (dateHeader != null) {
            return Column(
              key: ValueKey('col_${tx.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0) SizedBox(height: homeSize(AppSpacing.base)),
                dateHeader,
                SizedBox(height: homeSize(AppSpacing.sm)),
                tile,
              ],
            );
          }
          return KeyedSubtree(
            key: ValueKey(tx.id),
            child: tile,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isOnline || isReloading || lastSync != null)
          _HomeHistoryStatusBar(
            isOnline: isOnline,
            isReloading: isReloading,
            lastSync: lastSync,
            count: filteredTxs.length,
          ),
        body,
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final label = AppDateTime.formatDate(context, date);

    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 12.0),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          color: HomeColors.textMuted,
          fontSize: homeFontSize(12),
          letterSpacing: 1.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


  Widget _buildTransactionTile(
    Transaction tx, {
    required bool expanded,
  }) {
    final amountBtc = (tx.amountSatoshis / 100000000).toStringAsFixed(8);
    final semanticLabel =
        '${tx.type.name}. $amountBtc BTC. ${AppDateTime.formatTime(context, tx.timestamp.toLocal())}. ${tx.status.name}';

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: StatementTransactionCard(
        transaction: tx,
        expanded: expanded,
        mode: StatementTransactionCardMode.stacked,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (expanded) {
              _expandedTransactionIds.remove(tx.id);
            } else {
              _expandedTransactionIds.add(tx.id);
            }
          });
        },
      ),
    );
  }
}



class _HomeHistoryStatusBar extends StatelessWidget {
  final bool isOnline;
  final bool isReloading;
  final DateTime? lastSync;
  final int count;

  const _HomeHistoryStatusBar({
    required this.isOnline,
    required this.isReloading,
    required this.lastSync,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final label = !isOnline
        ? (lastSync != null
            ? context.tr.homeOfflineExtractDate(AppDateTime.formatRelative(context, lastSync!))
            : context.tr.homeOfflineExtract)
        : isReloading
            ? context.tr.homeSyncing
            : lastSync != null
                ? context.tr.homeUpdatedDate(count, AppDateTime.formatRelative(context, lastSync!))
                : null;
    if (label == null) return const SizedBox.shrink();

    final tone = !isOnline ? homeAmberColor : homeMutedTextColor;
    return Padding(
      padding: EdgeInsets.only(left: 4, right: 4, bottom: homeSize(10)),
      child: Row(
        children: [
          Icon(
            !isOnline
                ? KeroseneIcons.cloudOff
                : isReloading
                    ? KeroseneIcons.refresh
                    : KeroseneIcons.history,
            size: homeSize(14),
            color: tone,
          ).animate(
            target: isReloading ? 1 : 0,
            onPlay: (c) => isReloading ? c.repeat() : c.stop(),
          ).rotate(duration: 1200.ms),
          SizedBox(width: homeSize(6)),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: tone,
                fontSize: homeFontSize(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton shimmer loading that mimics the real transaction feed layout.
/// Uses [HomeSkeletonBox] with staggered fade-slide entrance for each row.
class _TransactionsSkeletonLoading extends StatelessWidget {
  const _TransactionsSkeletonLoading();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = KeroseneMotion.reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date header skeleton
        Padding(
          padding: const EdgeInsets.only(left: 4.0, top: 12.0, bottom: 12.0),
          child: HomeSkeletonBox(
            width: homeSize(140),
            height: homeSize(24),
            borderRadius: BorderRadius.circular(homeSize(7)),
          ),
        ),
        // ── Transaction row skeletons (staggered entrance)
        for (var i = 0; i < 4; i++)
          _buildSkeletonRow(i, reduceMotion),
        // ── Second date header
        Padding(
          padding: EdgeInsets.only(
            left: 4.0,
            top: homeSize(20),
            bottom: 12.0,
          ),
          child: HomeSkeletonBox(
            width: homeSize(110),
            height: homeSize(24),
            borderRadius: BorderRadius.circular(homeSize(7)),
          ),
        ),
        // ── More rows under second date
        for (var i = 4; i < 6; i++)
          _buildSkeletonRow(i, reduceMotion),
      ],
    );
  }

  Widget _buildSkeletonRow(int index, bool reduceMotion) {
    // Vary widths slightly for organic feel.
    final titleWidths = [136.0, 152.0, 120.0, 144.0, 128.0, 160.0];
    final subtitleWidths = [104.0, 88.0, 116.0, 96.0, 108.0, 92.0];
    final amountWidths = [90.0, 78.0, 96.0, 84.0, 72.0, 88.0];
    final subAmountWidths = [70.0, 62.0, 74.0, 66.0, 58.0, 68.0];
    final i = index % titleWidths.length;

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: homeSize(8)),
      child: Container(
        padding: EdgeInsets.all(homeSize(16)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(homeSize(22)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            // Icon circle placeholder
            HomeSkeletonBox(
              width: homeSize(42),
              height: homeSize(42),
              borderRadius: BorderRadius.circular(homeSize(999)),
            ),
            SizedBox(width: homeSize(12)),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeSkeletonBox(
                    width: homeSize(titleWidths[i]),
                    height: homeSize(14),
                    borderRadius: BorderRadius.circular(homeSize(5)),
                  ),
                  SizedBox(height: homeSize(AppSpacing.sm)),
                  HomeSkeletonBox(
                    width: homeSize(subtitleWidths[i]),
                    height: homeSize(11),
                    borderRadius: BorderRadius.circular(homeSize(5)),
                  ),
                ],
              ),
            ),
            SizedBox(width: homeSize(10)),
            // Amount + sub-amount (right-aligned)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                HomeSkeletonBox(
                  width: homeSize(amountWidths[i]),
                  height: homeSize(13),
                  borderRadius: BorderRadius.circular(homeSize(5)),
                ),
                SizedBox(height: homeSize(AppSpacing.sm)),
                HomeSkeletonBox(
                  width: homeSize(subAmountWidths[i]),
                  height: homeSize(11),
                  borderRadius: BorderRadius.circular(homeSize(5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return row;

    return row
        .animate()
        .fade(
          begin: 0,
          end: 1,
          duration: KeroseneMotion.medium,
          delay: Duration(milliseconds: index * 60),
          curve: KeroseneMotion.standard,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: KeroseneMotion.medium,
          delay: Duration(milliseconds: index * 60),
          curve: KeroseneMotion.standard,
        );
  }
}

class HomeEmptyTransactionsPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final bool showAction;
  /// Quiet text control (e.g. clear cancelled filter) instead of filled CTA.
  final bool subtleAction;
  final bool blackSurface;
  final bool plainCenteredIcon;
  final bool serifTitle;

  const HomeEmptyTransactionsPanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.showAction = true,
    this.subtleAction = false,
    this.blackSurface = false,
    this.plainCenteredIcon = false,
    this.serifTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HomeGlassPanel(
      backgroundColor: blackSurface ? homeBackgroundColor : null,
      borderRadius: BorderRadius.circular(homeSize(18)),
      padding: EdgeInsets.all(homeSize(AppSpacing.lg)),
      child: Column(
        crossAxisAlignment: plainCenteredIcon
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: homeSize(48),
            height: homeSize(48),
            child: Center(
              child: Icon(icon,
                  color: Colors.white,
                  size: homeSize(plainCenteredIcon ? 28 : 18)),
            ),
          ),
          SizedBox(height: homeSize(AppSpacing.lg)),
          Text(
            title,
            textAlign: plainCenteredIcon ? TextAlign.center : TextAlign.start,
            style: AppTypography.h3.copyWith(
              color: HomeColors.textPrimary,
              fontSize: homeFontSize(16),
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: homeSize(AppSpacing.sm)),
          Text(
            description,
            textAlign: plainCenteredIcon ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: homeFontSize(12),
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          if (showAction) ...[
            SizedBox(height: homeSize(subtleAction ? AppSpacing.md : AppSpacing.lg)),
            if (subtleAction)
              Center(
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.48),
                    padding: EdgeInsets.symmetric(
                      horizontal: homeSize(12),
                      vertical: homeSize(6),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontSize: homeFontSize(12),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(homeSize(50)),
                    backgroundColor: Colors.white,
                    foregroundColor: homeBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(homeSize(14)),
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: homeFontSize(14),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                  icon: Icon(actionIcon, size: homeSize(16)),
                  label: Text(actionLabel.toUpperCase()),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
