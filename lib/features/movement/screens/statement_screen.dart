import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_primary_navigation.dart';
import 'package:kerosene/core/presentation/widgets/tor_loading_dots.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_filter_engine.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/providers/statement_insights_provider.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/features/movement/utils/statement_csv_export.dart';
import 'package:kerosene/features/movement/utils/statement_pdf_export.dart';
import 'package:kerosene/features/movement/utils/transaction_address_display.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';
import 'package:kerosene/features/movement/widgets/statement_transaction_card.dart';
import 'package:kerosene/features/movement/widgets/transaction_statement_insights.dart';
import 'package:kerosene/shared/widgets/bitcoin_refresh_indicator.dart';

enum _StatementTab { statement, insights }

/// Same activity set as Home — maps 1:1 to [ActivityFilter].
enum _StatementFilter {
  all,
  incoming,
  outgoing,
  internal,
  onchain,
  lightning,
  cold,
  pending,
  failed,
  cancelled,
  archived,
}

ActivityFilter _mapStatementFilter(_StatementFilter filter) {
  return switch (filter) {
    _StatementFilter.all => ActivityFilter.all,
    _StatementFilter.incoming => ActivityFilter.incoming,
    _StatementFilter.outgoing => ActivityFilter.outgoing,
    _StatementFilter.internal => ActivityFilter.instant,
    _StatementFilter.onchain => ActivityFilter.onchain,
    _StatementFilter.lightning => ActivityFilter.lightning,
    _StatementFilter.cold => ActivityFilter.cold,
    _StatementFilter.pending => ActivityFilter.inProgress,
    _StatementFilter.failed => ActivityFilter.problems,
    _StatementFilter.cancelled => ActivityFilter.cancelled,
    _StatementFilter.archived => ActivityFilter.archived,
  };
}

class TransactionStatementScreen extends ConsumerStatefulWidget {
  final String? initialTransactionId;

  const TransactionStatementScreen({
    super.key,
    this.initialTransactionId,
  });

  @override
  ConsumerState<TransactionStatementScreen> createState() =>
      _TransactionStatementScreenState();
}

class _TransactionStatementScreenState
    extends ConsumerState<TransactionStatementScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  _StatementTab _selectedTab = _StatementTab.statement;
  _StatementFilter _selectedFilter = _StatementFilter.all;
  String? _expandedTransactionId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _expandedTransactionId = widget.initialTransactionId;
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(walletProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  Future<void> _refreshData() async {
    await HapticFeedback.lightImpact();
    ref.invalidate(statementInsightsReportProvider);
    await refreshFinancialProjectionUi(ref, forceFullHistory: true);
  }

  void _handleBack() {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed('/home');
  }

  void _selectTab(_StatementTab tab) {
    if (_selectedTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = tab);
  }

  void _selectFilter(_StatementFilter filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedFilter = filter);
  }

  void _toggleTransaction(Transaction transaction) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedTransactionId =
          _expandedTransactionId == transaction.id ? null : transaction.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(transactionHistoryProvider);
    final lastHistory = ref.watch(lastTransactionHistoryProvider);
    final historyValue = historyAsync.asData?.value ??
        (lastHistory.isNotEmpty ? lastHistory : null);
    final bottomPadding =
        AppPrimaryNavigationBar.scaffoldBottomClearance(context);
    final maxWidth = context.responsive.appColumnMaxWidth;

    if (historyValue == null && historyAsync.isLoading) {
      return const Center(child: TorLoadingDots());
    }

    return FinancialSecureScope(
      child: Scaffold(
      backgroundColor: _StatementColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: KeroseneAppColumn(
              maxWidth: maxWidth,
              child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    BitcoinRefreshIndicator(onRefresh: _refreshData),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl2,
                          AppSpacing.xl,
                          AppSpacing.xl2,
                          0,
                        ),
                        child: _StatementTopBar(
                          onBack: _handleBack,
                          onExport: () => _exportCsv(historyValue ?? const []),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl2,
                          18,
                          AppSpacing.xl2,
                          0,
                        ),
                        child: _StatementHeader(
                          selectedTab: _selectedTab,
                          onTabSelected: _selectTab,
                        ),
                      ),
                    ),
                    historyAsync.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox.shrink(),
                      ),
                      error: (error, _) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatementMessage(
                          icon: KeroseneIcons.warning,
                          title: context.tr.financialStatementLoadErrorTitle,
                          message: ErrorTranslator.translate(
                            context.tr,
                            error.toString(),
                          ),
                        ),
                      ),
                      data: (transactions) {
                        if (_selectedTab == _StatementTab.insights) {
                          return SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.xl2,
                              AppSpacing.xl2,
                              AppSpacing.xl2,
                              bottomPadding,
                            ),
                            sliver: const SliverToBoxAdapter(
                              child: TransactionStatementInsights(),
                            ),
                          );
                        }

                        final filtered = _filteredTransactions(transactions);
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.xl2,
                            AppSpacing.xl2,
                            AppSpacing.xl2,
                            bottomPadding,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _StatementListSurface(
                              queryController: _searchController,
                              selectedFilter: _selectedFilter,
                              onFilterSelected: _selectFilter,
                              allTransactions: transactions,
                              transactions: filtered,
                              expandedTransactionId: _expandedTransactionId,
                              onTransactionTap: _toggleTransaction,
                              onClearFilters: _clearFilters,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ),
          ),
          AppPrimaryNavigationBar.overlay(
            currentDestination: AppPrimaryDestination.history,
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _exportCsv(List<Transaction> transactions) async {
    HapticFeedback.selectionClick();
    if (transactions.isEmpty) {
      if (!mounted) return;
      AppNotice.showInfo(
        context,
        title: context.tr.statementExportNothingTitle,
        message: context.tr.statementEmptyOnDevice,
      );
      return;
    }

    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _StatementColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final tr = ctx.tr;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr.statementExportTitle,
                  style: AppTypography.newsreader(
                    color: _StatementColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr.statementExportLongAddressesNote,
                  style: AppTypography.inter(
                    color: _StatementColors.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(KeroseneIcons.download,
                      color: _StatementColors.textPrimary),
                  title: Text(
                    'CSV',
                    style: TextStyle(color: _StatementColors.textPrimary),
                  ),
                  subtitle: Text(
                    tr.statementExportCsvSubtitle,
                    style: TextStyle(color: _StatementColors.textMuted),
                  ),
                  onTap: () => Navigator.of(ctx).pop('csv'),
                ),
                ListTile(
                  leading: Icon(KeroseneIcons.receipt,
                      color: _StatementColors.textPrimary),
                  title: Text(
                    'PDF',
                    style: TextStyle(color: _StatementColors.textPrimary),
                  ),
                  subtitle: Text(
                    tr.statementExportShareLimit,
                    style: TextStyle(color: _StatementColors.textMuted),
                  ),
                  onTap: () => Navigator.of(ctx).pop('pdf'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (format == null || !mounted) return;

    final result = format == 'pdf'
        ? await exportStatementPdf(transactions)
        : await exportStatementCsv(transactions);
    if (!mounted) return;
    final tr = context.tr;
    AppNotice.showInfo(
      context,
      title: result.shared
          ? tr.statementExportSharedTitle
          : (format == 'csv'
              ? tr.statementExportCsvCopiedTitle
              : tr.statementExportGenericTitle),
      message: result.shared
          ? tr.statementExportSharedMessage(
              result.rowCount,
              format.toUpperCase(),
            )
          : format == 'csv'
              ? tr.statementExportCsvCopiedMessage(result.rowCount)
              : tr.statementExportPdfFailed,
    );
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFilter = _StatementFilter.all;
      _searchController.clear();
      _query = '';
    });
  }

  List<Transaction> _filteredTransactions(List<Transaction> transactions) {
    final wallets = ref.read(walletProvider);
    final walletList =
        wallets is WalletLoaded ? wallets.wallets : const <Wallet>[];
    final accounts =
        ref.read(bitcoinAccountsProvider).asData?.value ??
            const <BitcoinAccount>[];
    final archivedIds = ref.watch(activityArchiveProvider);
    final byActivity = TransactionFilterEngine.apply(
      source: transactions,
      activity: _mapStatementFilter(_selectedFilter),
      wallets: walletList,
      accounts: accounts,
      archivedIds: archivedIds,
    );
    final normalizedQuery = _query.toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? byActivity
        : byActivity
            .where((tx) => _searchText(tx).contains(normalizedQuery))
            .toList(growable: false);
    final sorted = [...filtered]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  String _searchText(Transaction transaction) {
    final axes = TransactionAxes.classify(transaction);
    final rail = switch (axes.rail) {
      TxRail.internal => 'instant interno internal',
      TxRail.onchain => 'onchain on-chain bitcoin',
      TxRail.lightning => 'lightning ln',
      TxRail.cold => 'cold fria watch',
    };
    final direction = switch (axes.direction) {
      TxDirection.incoming => 'in received recebida entrada',
      TxDirection.outgoing => 'out sent enviada saida',
      TxDirection.neutral => 'neutral',
    };
    final product = axes.product.name;
    final lifecycle = axes.lifecycle.name;
    final partyFrom = resolveTransactionFromParty(transaction);
    final partyTo = resolveTransactionToParty(
      transaction,
      compactHash: false,
    );
    return [
      transaction.id,
      transaction.fromAddress,
      transaction.toAddress,
      transaction.walletId,
      transaction.sourceWalletId,
      transaction.destinationWalletId,
      transaction.senderDisplayName,
      transaction.receiverDisplayName,
      transaction.walletLabel,
      transaction.sourceWalletLabel,
      transaction.destinationWalletLabel,
      transaction.counterpartyLabel,
      transaction.description,
      transaction.blockchainTxid,
      transaction.paymentHash,
      transaction.externalReference,
      transaction.provider,
      transaction.failureCode,
      transaction.type.name,
      transaction.rail,
      transaction.status.name,
      resolvePrimaryTransactionAddress(transaction),
      rail,
      direction,
      product,
      lifecycle,
      partyFrom,
      partyTo,
    ].whereType<String>().join(' ').toLowerCase();
  }
}

class _StatementHeader extends StatelessWidget {
  final _StatementTab selectedTab;
  final ValueChanged<_StatementTab> onTabSelected;

  const _StatementHeader({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr.statementScreenTitle,
          style: AppTypography.newsreader(
            color: _StatementColors.textPrimary,
            fontSize: MediaQuery.sizeOf(context).width >= 720 ? 36 : 32,
            fontWeight: FontWeight.w500,
            height: 1.12,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        _StatementTabSwitcher(
          selected: selectedTab,
          onSelected: onTabSelected,
        ),
      ],
    );
  }
}

class _StatementTabSwitcher extends StatelessWidget {
  final _StatementTab selected;
  final ValueChanged<_StatementTab> onSelected;

  const _StatementTabSwitcher({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _StatementColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatementTabButton(
              label: context.tr.statementScreenTitle,
              selected: selected == _StatementTab.statement,
              onTap: () => onSelected(_StatementTab.statement),
            ),
          ),
          Expanded(
            child: _StatementTabButton(
              label: context.tr.statementTabInsights,
              selected: selected == _StatementTab.insights,
              onTap: () => onSelected(_StatementTab.insights),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatementTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _StatementColors.surfaceHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Center(
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected
                  ? _StatementColors.textPrimary
                  : _StatementColors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatementListSurface extends StatelessWidget {
  final TextEditingController queryController;
  final _StatementFilter selectedFilter;
  final ValueChanged<_StatementFilter> onFilterSelected;
  final List<Transaction> allTransactions;
  final List<Transaction> transactions;
  final String? expandedTransactionId;
  final ValueChanged<Transaction> onTransactionTap;
  final VoidCallback onClearFilters;

  const _StatementListSurface({
    required this.queryController,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.allTransactions,
    required this.transactions,
    required this.expandedTransactionId,
    required this.onTransactionTap,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatementSearchField(controller: queryController),
        const SizedBox(height: AppSpacing.base),
        _StatementFilterBar(
          selected: selectedFilter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: AppSpacing.xl2),
        if (allTransactions.isEmpty)
          _StatementMessage(
            icon: KeroseneIcons.document,
            title: context.tr.financialStatementEmptyTitle,
            message: context.tr.financialStatementEmptyMessage,
          )
        else if (transactions.isEmpty)
          _StatementNoResults(onClearFilters: onClearFilters)
        else
          _GroupedTransactionList(
            transactions: transactions,
            expandedTransactionId: expandedTransactionId,
            onTransactionTap: onTransactionTap,
          ),
      ],
    );
  }
}

class _StatementSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _StatementSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyMedium.copyWith(
          color: _StatementColors.textPrimary,
        ),
        cursorColor: _StatementColors.textPrimary,
        decoration: InputDecoration(
          hintText: context.tr.financialStatementSearchHint,
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: _StatementColors.textMuted,
          ),
          prefixIcon: const Icon(
            KeroseneIcons.search,
            color: _StatementColors.textMuted,
            size: 20,
          ),
          filled: true,
          fillColor: _StatementColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.base,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _StatementColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _StatementColors.borderHigh),
          ),
        ),
      ),
    );
  }
}

class _StatementFilterBar extends StatelessWidget {
  final _StatementFilter selected;
  final ValueChanged<_StatementFilter> onSelected;

  const _StatementFilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in _StatementFilter.values) ...[
            _StatementFilterChip(
              label: _filterLabel(context, filter),
              selected: selected == filter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _StatementFilter.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StatementFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatementFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _StatementColors.surfaceHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _StatementColors.borderHigh
                  : _StatementColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: selected
                  ? _StatementColors.textPrimary
                  : _StatementColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedTransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final String? expandedTransactionId;
  final ValueChanged<Transaction> onTransactionTap;

  const _GroupedTransactionList({
    required this.transactions,
    required this.expandedTransactionId,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    DateTime? currentDay;

    for (final transaction in transactions) {
      final local = transaction.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (currentDay != day) {
        currentDay = day;
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: AppSpacing.xl2));
        }
        children.add(
          _StatementDateHeader(label: _dateGroupLabel(context, day)),
        );
        children.add(const SizedBox(height: AppSpacing.sm));
      } else {
        children.add(const SizedBox(height: AppSpacing.xs));
      }

      children.add(
        StatementTransactionCard(
          transaction: transaction,
          expanded: expandedTransactionId == transaction.id,
          mode: StatementTransactionCardMode.separated,
          onTap: () => onTransactionTap(transaction),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _StatementDateHeader extends StatelessWidget {
  final String label;

  const _StatementDateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: _StatementColors.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _StatementNoResults extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _StatementNoResults({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return _StatementMessage(
      icon: KeroseneIcons.searchUnavailable,
      title: context.tr.financialStatementNoResultsTitle,
      message: context.tr.financialStatementNoResultsMessage,
      action: OutlinedButton(
        onPressed: onClearFilters,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: _StatementColors.textPrimary,
          side: const BorderSide(color: _StatementColors.borderHigh),
        ),
        child: Text(context.tr.financialStatementClearFilters),
      ),
    );
  }
}

class _StatementTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onExport;

  const _StatementTopBar({required this.onBack, this.onExport});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: KeroseneIcons.back, onPressed: onBack),
        const Spacer(),
        if (onExport != null)
          _RoundIconButton(
            icon: KeroseneIcons.download,
            onPressed: onExport!,
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: _StatementColors.textPrimary, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: _StatementColors.surface,
          shape: const CircleBorder(),
          minimumSize: const Size.square(48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

class _StatementMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StatementMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _StatementColors.textMuted, size: 30),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h3Small.copyWith(
                color: _StatementColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: _StatementColors.textMuted,
                height: 1.35,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.base),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StatementColors {
  static const background = AppColors.hexFF050505;
  static const surface = AppColors.hexFF0D0D0D;
  static const surfaceHigh = AppColors.hexFF161616;
  static const border = AppColors.hexFF222222;
  static const borderHigh = AppColors.hexFF525252;
  static const textPrimary = AppColors.hexFFFFFFFF;
  static const textSecondary = AppColors.hexFFB8BCC2;
  static const textMuted = AppColors.hexFF8A8A8E;
}

String _filterLabel(BuildContext context, _StatementFilter filter) {
  return switch (filter) {
    _StatementFilter.all => context.tr.financialStatementFilterAll,
    _StatementFilter.incoming => context.tr.financialStatementFilterIncoming,
    _StatementFilter.outgoing => context.tr.financialStatementFilterOutgoing,
    _StatementFilter.internal => context.tr.activityFilterInstant,
    _StatementFilter.onchain => context.tr.activityFilterOnchain,
    _StatementFilter.lightning => context.tr.activityFilterLightning,
    _StatementFilter.cold => context.tr.activityFilterCold,
    _StatementFilter.pending => context.tr.activityFilterInProgress,
    _StatementFilter.failed => context.tr.activityFilterProblems,
    _StatementFilter.cancelled => context.tr.financialStatementFilterCancelled,
    _StatementFilter.archived => context.tr.financialStatementFilterArchived,
  };
}

String _dateGroupLabel(BuildContext context, DateTime day) {
  // Locale-aware date header (replaces hardcoded PT months).
  return AppDateTime.formatDate(context, day);
}


