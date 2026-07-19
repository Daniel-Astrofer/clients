// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'package:flutter/foundation.dart' show listEquals;
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

  /// When true, builds a [SliverList] (virtualized) for the home [CustomScrollView].
  /// When false, embeds as a [Column] (wide two-column layout).
  final bool asSliver;

  const HomeTransactionsList({
    super.key,
    required this.onCreateWallet,
    required this.onDepositWallet,
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

  /// Skeleton → data: one shared cascade for **all** rows (not only first 3).
  bool _armEntranceReveal = true;
  bool _playEntranceReveal = false;

  /// Cached tiles for the entrance pass — avoids rebuilding heavy cards every
  /// animation frame (only opacity/offset wrappers rebuild).
  List<Widget>? _entranceTileCache;
  List<String>? _entranceIdOrder;

  AnimationController? _entrance;

  static const _itemRevealMs = 520;
  static const _staggerMs = 48;
  static const _maxEntranceMs = 1800;

  @override
  void dispose() {
    _entrance?.dispose();
    super.dispose();
  }

  Duration _entranceDurationFor(int count) {
    if (count <= 0) return Duration.zero;
    final raw = _itemRevealMs + _staggerMs * (count - 1);
    return Duration(milliseconds: raw.clamp(_itemRevealMs, _maxEntranceMs));
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
    return Curves.easeOutQuart.transform(local);
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

  List<Widget> _ensureEntranceCache(
    List<Transaction> filteredTxs,
  ) {
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
      const skeleton = ColoredBox(
        color: homeBackgroundColor,
        child: _TransactionsSkeletonLoading(),
      );
      return widget.asSliver
          ? const SliverToBoxAdapter(child: skeleton)
          : skeleton;
    }

    final filterIsAll = selectedFilter == HomeActivityFilter.all;
    final filterIsCancelled =
        selectedFilter == HomeActivityFilter.cancelled;

    if (filteredTxs.isNotEmpty) {
      _scheduleEntranceReveal(filteredTxs.length);
    } else {
      _armEntranceReveal = false;
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
      body = _buildTxStack(
        filteredTxs: filteredTxs,
        animate: _playEntranceReveal && _entrance != null,
      );
    }

    if (widget.asSliver) {
      // Virtualized path for home CustomScrollView — only visible cards paint.
      if (filteredTxs.isEmpty) {
        return SliverToBoxAdapter(child: body);
      }
      final tiles = _playEntranceReveal
          ? _ensureEntranceCache(filteredTxs)
          : null;
      final count = filteredTxs.length;
      final AnimationController? entranceCtrl = _entrance;
      final bool animate = _playEntranceReveal && entranceCtrl != null;
      final AnimationController? liveCtrl = animate ? entranceCtrl : null;

      Widget itemBuilder(BuildContext context, int index) {
        final tx = filteredTxs[index];
        
        final tile = tiles != null && index < tiles.length
            ? tiles[index]
            : _buildTransactionTile(
                tx,
                expanded: _expandedTransactionIds.contains(tx.id),
              );

        // Envolve o tile num RepaintBoundary isolado para que a animação de opacidade 
        // e translação não invalide a renderização pesada do card.
        final cachedTile = RepaintBoundary(child: tile);

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

        Widget buildContent(double p) {
          final revealed = p <= 0
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: p,
                  child: Transform.translate(
                    offset: Offset((1.0 - p) * -22, (1.0 - p) * 8),
                    child: cachedTile,
                  ),
                );

          final gap = index > 0 ? homeSize(12) : 0.0;
          Widget content;
          if (dateHeader != null) {
            content = Padding(
              padding: EdgeInsets.only(top: gap),
              child: Column(
                key: ValueKey('col_${tx.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0) SizedBox(height: homeSize(AppSpacing.base) - gap),
                  Opacity(opacity: p.clamp(0.0, 1.0), child: dateHeader),
                  SizedBox(height: homeSize(AppSpacing.sm)),
                  revealed,
                ],
              ),
            );
          } else {
            content = Padding(
              padding: EdgeInsets.only(top: gap),
              child: KeyedSubtree(key: ValueKey(tx.id), child: revealed),
            );
          }

          return ColoredBox(
            color: homeBackgroundColor,
            child: content,
          );
        }

        if (liveCtrl != null) {
          return AnimatedBuilder(
            animation: liveCtrl,
            builder: (context, _) {
              final p = _rowProgress(index, liveCtrl.value, count);
              return buildContent(p);
            },
          );
        }

        return buildContent(1.0);
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          itemBuilder,
          childCount: count,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      );
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
              style: AppTypography.label.copyWith(
                color: homeAmberColor,
                fontSize: homeFontSize(11),
                fontWeight: FontWeight.w500,
              ),
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
      final tile = tiles != null && index < tiles.length
          ? tiles[index]
          : _buildTransactionTile(
              tx,
              expanded: _expandedTransactionIds.contains(tx.id),
            );
      
      final cachedTile = RepaintBoundary(child: tile);

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

      Widget buildContent(double p) {
        final revealed = p <= 0
            ? const SizedBox.shrink()
            : Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset((1.0 - p) * -22, (1.0 - p) * 8),
                  child: cachedTile,
                ),
              );

        if (dateHeader != null) {
          return Column(
            key: ValueKey('col_${tx.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0) SizedBox(height: homeSize(AppSpacing.base)),
              Opacity(opacity: p.clamp(0.0, 1.0), child: dateHeader),
              SizedBox(height: homeSize(AppSpacing.sm)),
              revealed,
            ],
          );
        }
        return KeyedSubtree(
          key: ValueKey(tx.id),
          child: revealed,
        );
      }

      if (animate && ctrl != null) {
        return AnimatedBuilder(
          animation: ctrl,
          builder: (context, _) {
            final p = _rowProgress(index, ctrl.value, count);
            return buildContent(p);
          },
        );
      }
      return buildContent(1.0);
    }

    return StatementTransactionScrollStack(
      itemCount: count,
      itemGap: homeSize(12),
      itemBuilder: itemBuilder,
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
        density: StatementTransactionCardDensity.home,
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
    _cascade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
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
            _cascadeItem(
              progress: cascade,
              start: 0.0,
              end: 0.28,
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 4.0, top: 12.0, bottom: 12.0),
                child: _SkeletonBone(
                  width: homeSize(140),
                  height: homeSize(22),
                  borderRadius: homeSize(7),
                ),
              ),
            ),
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
    final eased = Curves.easeOutQuart.transform(t);
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
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(homeSize(22)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
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
        color: Colors.white.withValues(alpha: 0.06),
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
