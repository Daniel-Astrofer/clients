// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';

import 'home_screen_dependencies.dart';
import 'home_screen.dart';
import 'home_screen_surface.dart';

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

  final walletScope = ref.watch(homeExtratoWalletScopeProvider);
  final selected = walletState is WalletLoaded
      ? walletState.selectedWallet ??
          (walletState.wallets.isNotEmpty ? walletState.wallets.first : null)
      : null;

  var scoped = txs;
  if (walletScope == HomeExtratoWalletScope.selected && selected != null) {
    final ids = <String>{
      selected.id.trim(),
      if (selected.name.trim().isNotEmpty) selected.name.trim(),
    };
    // Also match cold wallet id via bitcoin accounts.
    for (final account in accounts) {
      if (account.id == selected.id ||
          account.label == selected.name ||
          (account.coldWalletId ?? '') == selected.id) {
        ids.add(account.id);
        if ((account.coldWalletId ?? '').isNotEmpty) {
          ids.add(account.coldWalletId!.trim());
        }
      }
    }
    scoped = txs.where((tx) {
      final candidates = <String?>[
        tx.walletId,
        tx.sourceWalletId,
        tx.destinationWalletId,
        tx.fromAddress,
        tx.toAddress,
      ];
      for (final c in candidates) {
        final v = (c ?? '').trim();
        if (v.isNotEmpty && ids.contains(v)) return true;
      }
      return false;
    }).toList(growable: false);
  }

  // Cancelled/expired activity stays off the principal feed and other
  // operational filters; it only appears under [HomeActivityFilter.cancelled].
  return switch (filter) {
    HomeActivityFilter.all =>
      scoped.where((tx) => !tx.isCancelled).toList(growable: false),
    HomeActivityFilter.incoming =>
      scoped.where((tx) => tx.isCredit && !tx.isCancelled).toList(growable: false),
    HomeActivityFilter.outgoing =>
      scoped.where((tx) => tx.isDebit && !tx.isCancelled).toList(growable: false),
    HomeActivityFilter.internal => scoped.where((tx) {
        if (tx.isCancelled) return false;
        final network = resolveTransactionNetwork(
          tx,
          wallets: wallets,
          accounts: accounts,
        );
        return network == TransactionNetwork.internal ||
            network == TransactionNetwork.paymentLinkInternal;
      }).toList(growable: false),
    HomeActivityFilter.onchain => scoped.where((tx) {
        if (tx.isCancelled) return false;
        final network = resolveTransactionNetwork(
          tx,
          wallets: wallets,
          accounts: accounts,
        );
        return network == TransactionNetwork.onchain ||
            network == TransactionNetwork.paymentLinkOnchain;
      }).toList(growable: false),
    HomeActivityFilter.cold => scoped.where((tx) {
        if (tx.isCancelled) return false;
        return resolveTransactionNetwork(
              tx,
              wallets: wallets,
              accounts: accounts,
            ) ==
            TransactionNetwork.cold;
      }).toList(growable: false),
    HomeActivityFilter.pending => scoped
        .where(
          (tx) =>
              !tx.isUnconfirmedExpired &&
              (tx.status == TransactionStatus.pending ||
                  tx.status == TransactionStatus.confirming),
        )
        .toList(growable: false),
    HomeActivityFilter.failed => scoped
        .where(
          (tx) =>
              tx.status == TransactionStatus.failed ||
              tx.isUnconfirmedExpired,
        )
        .toList(growable: false),
    HomeActivityFilter.cancelled =>
      scoped.where((tx) => tx.isCancelled).toList(growable: false),
  };
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

    Widget body;
    if (filteredTxs.isEmpty) {
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
              ? 'Nada neste filtro'
              : !hasWallet
                  ? context.tr.homeEmptyNoWalletTitle
                  : hasBalance
                      ? 'Histórico ainda vazio'
                      : context.tr.homeEmptyNoBalanceTitle,
          description: !filterIsAll
              ? 'Não há lançamentos para este filtro. Tente “Tudo” ou puxe para atualizar.'
              : !hasWallet
                  ? context.tr.homeEmptyNoWalletDescription
                  : hasBalance
                      ? 'Há saldo, mas nenhum lançamento na projeção local. Puxe para sincronizar com o servidor.'
                      : context.tr.homeEmptyNoBalanceDescription,
          actionLabel: !filterIsAll
              ? 'Limpar filtro'
              : !hasWallet
                  ? context.tr.homeCreateWalletAction
                  : hasBalance
                      ? context.tr.homeRefreshAction
                      : context.tr.homeDepositAction,
          actionIcon: !filterIsAll
              ? KeroseneIcons.close
              : !hasWallet
                  ? KeroseneIcons.next
                  : hasBalance
                      ? KeroseneIcons.refresh
                      : KeroseneIcons.download,
          onAction: () {
            if (!filterIsAll) {
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
          showAction: true,
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
          return tile;
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
    final isIncoming = tx.type == TransactionType.receive;
    final amountBtc = (tx.amountSatoshis / 100000000).toStringAsFixed(8);
    final semanticLabel = '${isIncoming ? "Recebido de" : "Enviado para"} ${tx.counterpartyLabel ?? "Desconhecido"}. Valor: $amountBtc BTC. Data: ${AppDateTime.formatTime(context, tx.timestamp.toLocal())}. Status: ${tx.status.name}';

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
            ? 'Offline · extrato local · ${AppDateTime.formatRelative(context, lastSync!)}'
            : 'Offline · extrato local')
        : isReloading
            ? 'Sincronizando extrato…'
            : lastSync != null
                ? '$count lançamentos · atualizado ${AppDateTime.formatRelative(context, lastSync!)}'
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
          ),
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
            SizedBox(height: homeSize(AppSpacing.lg)),
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
