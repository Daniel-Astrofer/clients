// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'package:flutter/foundation.dart' show listEquals;
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_filter_engine.dart';
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

final filteredHomeTransactionsProvider = Provider<List<Transaction>>((ref) {
  ref.keepAlive();
  final transactionsAsync = ref.watch(transactionHistoryProvider);
  final lastHistory = ref.watch(lastTransactionHistoryProvider);
  final txs = transactionsAsync.asData?.value ??
      (lastHistory.isNotEmpty ? lastHistory : null);

  if (txs == null) return const [];

  final filter = ref.watch(homeActivityFilterProvider);
  final walletState = ref.watch(walletProvider);
  final wallets =
      walletState is WalletLoaded ? walletState.wallets : const <Wallet>[];
  final accounts = ref.watch(bitcoinAccountsProvider).asData?.value ??
      const <BitcoinAccount>[];
  final archivedIds = ref.watch(activityArchiveProvider);

  final filtered = TransactionFilterEngine.apply(
    source: txs,
    activity: _mapHomeActivityFilter(filter),
    wallets: wallets,
    accounts: accounts,
    archivedIds: archivedIds,
  );
  // Safety net: date headers use timestamp; never trust upstream order after
  // WS conf bumps (cold wallets used to float older rows via updatedAt).
  final ordered = List<Transaction>.from(filtered);
  sortTransactionsNewestFirst(ordered);
  return ordered;
});

/// Cancelled txs still in the global feed (not opened → not archived yet).
final homeHasUnseenCancelledProvider = Provider.autoDispose<bool>((ref) {
  final transactionsAsync = ref.watch(transactionHistoryProvider);
  final lastHistory = ref.watch(lastTransactionHistoryProvider);
  final txs = transactionsAsync.asData?.value ??
      (lastHistory.isNotEmpty ? lastHistory : null);
  if (txs == null || txs.isEmpty) return false;
  final archived = ref.watch(activityArchiveProvider);
  for (final tx in txs) {
    if (!tx.isCancelled && !tx.isArchiveEligible) continue;
    if (!archived.contains(tx.id.trim())) return true;
  }
  return false;
});

class HomeTransactionsList extends ConsumerStatefulWidget {
  final VoidCallback onCreateWallet;
  final ValueChanged<Wallet> onDepositWallet;
  final VoidCallback? onOpenStatement;

  /// When true, embeds the grouped activity surface in the home
  /// [CustomScrollView]. When false, embeds it as a [Column] (wide layout).
  final bool asSliver;

  const HomeTransactionsList({
    super.key,
    required this.onCreateWallet,
    required this.onDepositWallet,
    this.onOpenStatement,
    this.asSliver = false,
  });

  @override
  ConsumerState<HomeTransactionsList> createState() =>
      _HomeTransactionsListState();
}

class _HomeTransactionsListState extends ConsumerState<HomeTransactionsList>
    with SingleTickerProviderStateMixin {
  /// Multiple cards may stay open; expansion only grows downward.
  final Set<String> _expandedTransactionIds = <String>{};

  /// Skeleton → data: one shared cascade for the three Home rows.
  bool _armEntranceReveal = true;
  bool _playEntranceReveal = false;

  /// Cached tiles for the entrance pass — avoids rebuilding heavy cards every
  /// animation frame (only opacity/offset wrappers rebuild).
  List<Widget>? _entranceTileCache;
  List<String>? _entranceIdOrder;

  /// Steady-state tile cache — scroll reuses built cards instead of recomputing.
  final Map<String, Widget> _steadyTileCache = <String, Widget>{};

  AnimationController? _entrance;

  static const _itemRevealMs = 220;
  static const _staggerMs = 24;
  static const _maxEntranceMs = 360;

  @override
  void dispose() {
    _entrance?.dispose();
    super.dispose();
  }

  Duration _entranceDurationFor(int count) {
    if (count <= 0) return Duration.zero;
    final raw = _itemRevealMs + _staggerMs * (count - 1);
    return KeroseneMotion.fromMilliseconds(
      raw.clamp(_itemRevealMs, _maxEntranceMs).toInt(),
    );
  }

  /// 0→1 progress for row [index] under shared controller value [t].
  double _rowProgress(int index, double t, int count) {
    if (count <= 0) return 1;
    final totalMs = _entranceDurationFor(count).inMilliseconds.toDouble();
    if (totalMs <= 0) return 1;
    final start = (_staggerMs * index) / totalMs;
    final end = (start + _itemRevealMs / totalMs).clamp(0.0, 1.0);
    final span = (end - start).clamp(0.001, 1.0);
    final local = ((t - start) / span).clamp(0.0, 1.0);
    // Soft settle — less abrupt than easeOutCubic.
    return KeroseneMotion.entrance.transform(local);
  }

  void _scheduleEntranceReveal(int itemCount) {
    if (!_armEntranceReveal || _playEntranceReveal) return;
    if (itemCount <= 0) {
      _armEntranceReveal = false;
      return;
    }
    _armEntranceReveal = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (KeroseneMotion.reduceMotion(context)) {
        setState(() {
          _playEntranceReveal = false;
          _entranceTileCache = null;
          _entranceIdOrder = null;
        });
        return;
      }

      _entrance?.dispose();
      final duration = _entranceDurationFor(itemCount);
      final ctrl = AnimationController(vsync: this, duration: duration);
      _entrance = ctrl;
      ctrl.addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        // Drop wrappers + cache — steady state is plain tiles (zero anim cost).
        setState(() {
          _playEntranceReveal = false;
          _entranceTileCache = null;
          _entranceIdOrder = null;
        });
        ctrl.dispose();
        if (identical(_entrance, ctrl)) _entrance = null;
      });

      setState(() => _playEntranceReveal = true);
      ctrl.forward(from: 0);
    });
  }

  List<Widget> _ensureEntranceCache(List<Transaction> filteredTxs) {
    final ids = [for (final tx in filteredTxs) tx.id];
    final cached = _entranceTileCache;
    final order = _entranceIdOrder;
    if (cached != null &&
        order != null &&
        order.length == ids.length &&
        listEquals(order, ids)) {
      return cached;
    }

    final built = <Widget>[
      for (var i = 0; i < filteredTxs.length; i++)
        _buildTransactionTile(
          filteredTxs[i],
          expanded: _expandedTransactionIds.contains(filteredTxs[i].id),
        ),
    ];
    _entranceTileCache = built;
    _entranceIdOrder = ids;
    return built;
  }

  String _steadyTileCacheKey(Transaction tx) {
    return [
      tx.id,
      tx.status.name,
      tx.displayStatus.name,
      tx.confirmations,
      tx.amountSatoshis,
    ].join('|');
  }

  void _pruneSteadyTileCache(List<Transaction> txs) {
    final live = <String>{for (final tx in txs) _steadyTileCacheKey(tx)};
    _steadyTileCache.removeWhere((key, _) => !live.contains(key));
  }

  Widget _steadyTile(Transaction tx, {required bool expanded}) {
    // Expanded cards must not come from a separate cache entry — that swaps the
    // Element and drops collapse animation state. Same ValueKey → in-place update.
    if (expanded) {
      return _buildTransactionTile(tx, expanded: true);
    }
    return _steadyTileCache.putIfAbsent(
      _steadyTileCacheKey(tx),
      () => _buildTransactionTile(tx, expanded: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFilter = ref.watch(homeActivityFilterProvider);
    final filteredTxs = ref.watch(filteredHomeTransactionsProvider);
    // Load/error phase only — full history list lives in filteredTxs.
    final historyPhase = ref.watch(
      transactionHistoryProvider.select((a) {
        if (a.hasError && a.asData?.value == null) return 2; // error
        if (!a.hasValue && a.asData?.value == null) return 0; // loading
        return 1; // ready
      }),
    );
    final lastHistoryEmpty = ref.watch(
      lastTransactionHistoryProvider.select((h) => h.isEmpty),
    );
    final lastSync = ref.watch(transactionHistoryLastSyncProvider);
    final isOnline = ref.watch(networkStatusProvider);
    final hasWallet = ref.watch(
      walletProvider.select(
        (state) => state is WalletLoaded && state.wallets.isNotEmpty,
      ),
    );
    final hasBalance = ref.watch(
      walletProvider.select((state) {
        if (state is WalletLoaded) {
          final w = state.selectedWallet ??
              (state.wallets.isNotEmpty ? state.wallets.first : null);
          return (w?.balance ?? 0) > 0;
        }
        return false;
      }),
    );

    if (historyPhase == 2 && filteredTxs.isEmpty && lastHistoryEmpty) {
      final err = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: StateFeedbackView.networkError(
          context: context,
          onAction: () => ref.refresh(transactionHistoryProvider),
        ),
      );
      return widget.asSliver ? SliverToBoxAdapter(child: err) : err;
    }

    if (historyPhase == 0 && filteredTxs.isEmpty && lastHistoryEmpty) {
      // Skeleton → data path should re-arm the entrance once.
      _armEntranceReveal = true;
      _entranceTileCache = null;
      _entranceIdOrder = null;
      var skeleton = ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _TransactionsSkeletonLoading(),
      );
      return widget.asSliver ? SliverToBoxAdapter(child: skeleton) : skeleton;
    }

    final filterIsAll = selectedFilter == HomeActivityFilter.all;
    final filterIsCancelled = selectedFilter == HomeActivityFilter.cancelled;

    // Home is a glance surface. Keep the full history in the provider and
    // expose only the latest three rows here; the statement owns the rest.
    final visibleTxs = filteredTxs.take(3).toList(growable: false);

    if (visibleTxs.isNotEmpty) {
      _pruneSteadyTileCache(visibleTxs);
      _scheduleEntranceReveal(visibleTxs.length);
    } else {
      _armEntranceReveal = false;
      _steadyTileCache.clear();
    }

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
                      : context.tr.homeReceiveActionShort,
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
            unawaited(
              refreshFinancialProjectionUi(ref, forceFullHistory: true),
            );
          },
          showAction: showPrimaryAction || showClearOnCancelled,
          subtleAction: showClearOnCancelled,
          blackSurface: true,
          plainCenteredIcon: true,
          serifTitle: true,
        ),
      );
    } else {
      body = _buildTxStack(
        filteredTxs: visibleTxs,
        animate: _playEntranceReveal && _entrance != null,
      );
      body = _buildHomeActivityContainer(context, body);
    }

    if (widget.asSliver) {
      // Three rows plus the action are intentionally one surface, so the
      // activity block reads as a grouped module instead of loose cards.
      return SliverToBoxAdapter(child: body);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isOnline)
          Padding(
            padding: EdgeInsets.only(left: 4, right: 4, bottom: homeSize(10)),
            child: Text(
              lastSync != null
                  ? context.tr.homeOfflineExtractDate(
                      AppDateTime.formatRelative(context, lastSync),
                    )
                  : context.tr.homeOfflineExtract,
              style: HomeTypography.dateHeader(color: homeAmberColor),
            ),
          ),
        body,
      ],
    );
  }

  Widget _buildTxStack({
    required List<Transaction> filteredTxs,
    required bool animate,
  }) {
    final count = filteredTxs.length;
    final tiles = animate ? _ensureEntranceCache(filteredTxs) : null;
    final ctrl = _entrance;

    Widget itemBuilder(BuildContext context, int index) {
      final tx = filteredTxs[index];
      final expanded = _expandedTransactionIds.contains(tx.id);
      final tile = tiles != null && index < tiles.length
          ? tiles[index]
          : animate
              ? _buildTransactionTile(tx, expanded: expanded)
              : _steadyTile(tx, expanded: expanded);

      final cachedTile = RepaintBoundary(child: tile);

      Widget buildContent(double p, Widget child) {
        final revealed = p <= 0
            ? const SizedBox.shrink()
            : Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset((1.0 - p) * -22, (1.0 - p) * 8),
                  child: child,
                ),
              );

        return Padding(
          padding: EdgeInsets.only(top: index > 0 ? homeSize(8) : 0),
          child: KeyedSubtree(key: ValueKey(tx.id), child: revealed),
        );
      }

      if (animate && ctrl != null) {
        return AnimatedBuilder(
          animation: ctrl,
          child: cachedTile,
          builder: (context, child) {
            final p = _rowProgress(index, ctrl.value, count);
            return buildContent(p, child ?? cachedTile);
          },
        );
      }
      return buildContent(1.0, cachedTile);
    }

    return StatementTransactionScrollStack(
      itemCount: count,
      itemGap: homeSize(12),
      itemBuilder: itemBuilder,
    );
  }

  Widget _buildHomeActivityContainer(BuildContext context, Widget child) {
    final openStatement = widget.onOpenStatement;
    final language = Localizations.localeOf(context).languageCode;
    final moreLabel = switch (language) {
      'en' => 'See more',
      'es' => 'Ver más',
      _ => 'Ver mais',
    };

    return HomeGlassPanel(
      padding: EdgeInsets.fromLTRB(
        homeSize(10),
        homeSize(10),
        homeSize(10),
        openStatement == null ? homeSize(10) : homeSize(4),
      ),
      borderRadius: BorderRadius.circular(homeSize(HomeRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (openStatement != null) ...[
            SizedBox(height: homeSize(4)),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: openStatement,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: Size(0, homeSize(40)),
                  padding: EdgeInsets.symmetric(horizontal: homeSize(16)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  moreLabel,
                  style: TextStyle(
                    fontSize: homeSize(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction tx, {required bool expanded}) {
    final amountBtc = (tx.amountSatoshis / 100000000).toStringAsFixed(8);
    final semanticLabel =
        '${tx.type.name}. $amountBtc BTC. ${AppDateTime.formatTime(context, tx.timestamp.toLocal())}. ${tx.status.name}';

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: StatementTransactionCard(
        key: ValueKey('home_tx_${tx.id}'),
        transaction: tx,
        expanded: expanded,
        mode: StatementTransactionCardMode.stacked,
        density: StatementTransactionCardDensity.home,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (_expandedTransactionIds.contains(tx.id)) {
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

/// Skeleton for the home transaction feed.
///
/// Exactly **3** matte rows. Cascade in one-by-one (appear below each other).
/// No metallic shimmer — flat muted fills only (cheap + subtle).
class _TransactionsSkeletonLoading extends StatefulWidget {
  const _TransactionsSkeletonLoading();

  @override
  State<_TransactionsSkeletonLoading> createState() =>
      _TransactionsSkeletonLoadingState();
}

class _TransactionsSkeletonLoadingState
    extends State<_TransactionsSkeletonLoading>
    with SingleTickerProviderStateMixin {
  static const int _rowCount = 3;

  /// 0 → 1 drives sequential row appearance (cascade only — no shine ticker).
  late final AnimationController _cascade;

  @override
  void initState() {
    super.initState();
    _cascade = AnimationController(vsync: this, duration: HomeMotion.long);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (KeroseneMotion.reduceMotion(context)) {
        _cascade.value = 1;
        return;
      }
      _cascade.forward();
    });
  }

  @override
  void dispose() {
    _cascade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = KeroseneMotion.reduceMotion(context);

    return AnimatedBuilder(
      animation: _cascade,
      builder: (context, _) {
        final cascade = reduceMotion ? 1.0 : _cascade.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _rowCount; i++)
              _cascadeItem(
                progress: cascade,
                start: 0.12 + i * 0.22,
                end: 0.42 + i * 0.22,
                child: _buildSkeletonRow(i),
              ),
          ],
        );
      },
    );
  }

  Widget _cascadeItem({
    required double progress,
    required double start,
    required double end,
    required Widget child,
  }) {
    final span = (end - start).clamp(0.001, 1.0);
    final t = ((progress - start) / span).clamp(0.0, 1.0);
    final eased = KeroseneMotion.entrance.transform(t);
    if (eased <= 0) {
      return const SizedBox.shrink();
    }
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1.0 - eased) * homeSize(14)),
        child: child,
      ),
    );
  }

  Widget _buildSkeletonRow(int index) {
    final titleWidths = [136.0, 152.0, 120.0];
    final subtitleWidths = [104.0, 88.0, 116.0];
    final amountWidths = [90.0, 78.0, 96.0];
    final subAmountWidths = [70.0, 62.0, 74.0];
    final i = index % titleWidths.length;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: homeSize(6)),
      child: Container(
        padding: EdgeInsets.all(homeSize(16)),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(homeSize(22)),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            _SkeletonBone(
              width: homeSize(42),
              height: homeSize(42),
              borderRadius: homeSize(999),
            ),
            SizedBox(width: homeSize(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBone(
                    width: homeSize(titleWidths[i]),
                    height: homeSize(14),
                    borderRadius: homeSize(5),
                  ),
                  SizedBox(height: homeSize(AppSpacing.sm)),
                  _SkeletonBone(
                    width: homeSize(subtitleWidths[i]),
                    height: homeSize(11),
                    borderRadius: homeSize(5),
                  ),
                ],
              ),
            ),
            SizedBox(width: homeSize(10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SkeletonBone(
                  width: homeSize(amountWidths[i]),
                  height: homeSize(13),
                  borderRadius: homeSize(5),
                ),
                SizedBox(height: homeSize(AppSpacing.sm)),
                _SkeletonBone(
                  width: homeSize(subAmountWidths[i]),
                  height: homeSize(11),
                  borderRadius: homeSize(5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat matte placeholder — solid fill only, no gradient / shimmer / chrome.
class _SkeletonBone extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBone({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
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
      backgroundColor:
          blackSurface ? Theme.of(context).scaffoldBackgroundColor : null,
      borderRadius: BorderRadius.circular(homeSize(HomeRadius.card)),
      padding: EdgeInsets.all(homeSize(AppSpacing.lg)),
      child: Column(
        crossAxisAlignment: plainCenteredIcon
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: homeSize(56),
            height: homeSize(56),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(homeSize(18)),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurface,
                size: homeSize(plainCenteredIcon ? 28 : 18),
              ),
            ),
          ),
          SizedBox(height: homeSize(AppSpacing.md)),
          Text(
            title,
            textAlign: plainCenteredIcon ? TextAlign.center : TextAlign.start,
            style: HomeTypography.cardHeader(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: homeSize(AppSpacing.sm)),
          Text(
            description,
            textAlign: plainCenteredIcon ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.66),
              fontSize: homeFontSize(12),
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          if (showAction) ...[
            SizedBox(
              height: homeSize(subtleAction ? AppSpacing.md : AppSpacing.lg),
            ),
            if (subtleAction)
              Center(
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
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
                height: homeSize(50),
                child: AppButton(
                  label: actionLabel,
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: homeSize(16)),
                  expand: true,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
