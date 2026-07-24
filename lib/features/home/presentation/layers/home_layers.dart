import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_overscroll_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_scroll_busy_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_shell_flags_provider.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show homeSize;
import 'package:kerosene/features/home/presentation/screens/home_screen_balance.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_education.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_surface.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_transactions.dart';
import 'package:kerosene/features/home/presentation/design/home_design_tokens.dart';
import 'package:kerosene/features/home/presentation/widgets/home_aurora_background.dart';
import 'package:kerosene/features/home/presentation/widgets/home_bitcoin_market_chart_card.dart';
import 'package:kerosene/features/home/presentation/widgets/home_onboarding_progress_card.dart';
import 'package:kerosene/shared/widgets/bitcoin_refresh_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home layer architecture
//
// Each layer is an independent Consumer + RepaintBoundary. Provider updates in
// one layer must NOT rebuild siblings. HomeScreen itself watches almost nothing.
// ─────────────────────────────────────────────────────────────────────────────

String _resolveUserNameFromFlags(BuildContext context, HomeShellFlags flags) {
  var userName = '';
  if (flags.userNameRaw.isNotEmpty) {
    userName = flags.userNameRaw.split(' ').first;
  } else if (flags.authIsLoading) {
    userName = '...';
  }
  if (userName.isEmpty || userName == 'Not Found') {
    userName = context.tr.homeFallbackUser;
  }
  return userName;
}

/// Viewport-pinned aurora behind the scroll body + debug A/B chip.
///
/// Lives outside the [CustomScrollView] so pull-to-refresh never exposes the
/// black scaffold above the header. The aurora band fades into the scaffold
/// via a fixed-position veil so the top glow never follows the scroll.
class HomeAuroraLayer extends StatelessWidget {
  const HomeAuroraLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    // Covers status bar + balance theater.
    final bandHeight =
        (screenH * HomeMotion.auroraBandFraction).clamp(280.0, 720.0);
    final veilHeight =
        (screenH * HomeMotion.veilHeightFraction).clamp(72.0, 180.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Aurora glow band — viewport-pinned, never scrolls.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: bandHeight,
          child: IgnorePointer(
            child: ClipRect(
              child: RepaintBoundary(
                child: HomeAuroraBackground(),
              ),
            ),
          ),
        ),
        // Fixed-position veil — fades aurora into OLED black at a
        // constant position regardless of scroll offset.  When the
        // user scrolls down, content enters this fade zone instead
        // of the veil scrolling with the content.
        Positioned(
          top: bandHeight,
          left: 0,
          right: 0,
          height: veilHeight,
          child: IgnorePointer(
            child: const HomeFeedTopVeil(),
          ),
        ),
        const HomeAuroraRendererDebugToggle(),
      ],
    );
  }
}

/// Scroll body: structure only. Data lives inside child layers.
class HomeScrollLayer extends ConsumerStatefulWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onOpenStatement;
  final VoidCallback onOpenWallets;
  final VoidCallback onCreateWallet;
  final ValueChanged<Wallet> onDepositWallet;
  final VoidCallback onOpenDeposit;
  final VoidCallback onOpenSendFromFeed;

  const HomeScrollLayer({
    super.key,
    required this.onRefresh,
    required this.onReceive,
    required this.onSend,
    required this.onOpenStatement,
    required this.onOpenWallets,
    required this.onCreateWallet,
    required this.onDepositWallet,
    required this.onOpenDeposit,
    required this.onOpenSendFromFeed,
  });

  @override
  ConsumerState<HomeScrollLayer> createState() => _HomeScrollLayerState();
}

class _HomeScrollLayerState extends ConsumerState<HomeScrollLayer> {
  String? _firstUseActionPanelUserId;
  int _lastOverscrollPublishMs = 0;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final contentMaxWidth = responsive.appColumnMaxWidth;
    final pageHorizontalPadding = responsive.isTinyPhone
        ? homeSize(18)
        : responsive.isCompact
            ? homeSize(24)
            : responsive.isWide
                ? AppSpacing.xxxl
                : responsive.horizontalPadding;
    final useWide = responsive.useWideHomeLayout;
    final navigationClearance =
        MediaQuery.viewPaddingOf(context).bottom + homeSize(32);
    final pageTopPad = responsive.isTinyPhone ? homeSize(8) : homeSize(16);

    // Single coarse flag provider — shell structure only.
    final flags = ref.watch(homeShellFlagsProvider);
    final gapAfterHeader = homeSize(flags.sectionGapAfterHeader);
    final gapBeforeFeed = homeSize(flags.sectionGapBeforeFeed);

    final userId = flags.authenticatedUserId;
    if (userId == null) {
      _firstUseActionPanelUserId = null;
    } else if (flags.isReadyActionsVariant &&
        flags.hasLoadedHistory &&
        !flags.hasTransactions &&
        _firstUseActionPanelUserId != userId) {
      // Arm once without setState storm — field is read below after assign.
      _firstUseActionPanelUserId = userId;
    }

    final showFirstUseReadyPanel = userId != null &&
        flags.isReadyActionsVariant &&
        !flags.hasTransactions &&
        _firstUseActionPanelUserId == userId;
    final showPrimaryActionPanel =
        !flags.isReadyActionsVariant || showFirstUseReadyPanel;
    final userName = _resolveUserNameFromFlags(context, flags);

    return RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final busy = ref.read(homeScrollBusyProvider.notifier);
          if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
            busy.setBusy(true);
          } else if (n is ScrollEndNotification) {
            busy.setBusy(false);
          }

          if (n.metrics.axis == Axis.vertical) {
            final pixels = n.metrics.pixels;
            final overscroll = pixels < 0 ? pixels.abs() : 0.0;
            final currentOverscroll = ref.read(homeOverscrollProvider);
            final now = DateTime.now().millisecondsSinceEpoch;
            final delta = (currentOverscroll - overscroll).abs();
            // Responsive enough for shader pull bloom; coarse enough to avoid
            // provider thrash (aurora layout is viewport-pinned, not rebuilt here).
            final shouldPublish = n is ScrollEndNotification ||
                delta > 4.0 ||
                (now - _lastOverscrollPublishMs) > 32;
            if (shouldPublish &&
                (delta > 2.0 || (overscroll == 0 && currentOverscroll != 0))) {
              _lastOverscrollPublishMs = now;
              final quantized = overscroll <= 1
                  ? 0.0
                  : (overscroll / 3.0).round() * 3.0;
              Future.microtask(() {
                if (mounted) {
                  ref.read(homeOverscrollProvider.notifier).state = quantized;
                }
              });
            }
          }

          return false;
        },
        child: CustomScrollView(
          clipBehavior: Clip.none,
          scrollCacheExtent: const ScrollCacheExtent.pixels(720),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            BitcoinRefreshIndicator(onRefresh: widget.onRefresh),
            // ── HEADER layer (balance + theater) ─────────────────────────
            SliverToBoxAdapter(
              child: KeroseneAppColumn(
                maxWidth: contentMaxWidth,
                child: flags.showLoading
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          pageHorizontalPadding,
                          pageTopPad + MediaQuery.paddingOf(context).top,
                          pageHorizontalPadding,
                          homeSize(8),
                        ),
                        child: const HomeLoadingContent()
                            .animate()
                            .fade(duration: 220.ms),
                      )
                    : HomeEntryTransition(
                        child: HomeHeaderLayer(
                          userName: userName,
                          pageHorizontalPadding: pageHorizontalPadding,
                          pageTopPad: pageTopPad,
                          onReceive: widget.onReceive,
                          onSend: widget.onSend,
                          onViewStatement: widget.onOpenStatement,
                          onOpenWallets: widget.onOpenWallets,
                        ),
                      ),
              ),
            ),
            if (!flags.showLoading) ...[
              ..._feedSlivers(
                context: context,
                useWide: useWide,
                contentMaxWidth: contentMaxWidth,
                pageHorizontalPadding: pageHorizontalPadding,
                navigationClearance: navigationClearance,
                gapAfterHeader: gapAfterHeader,
                gapBeforeFeed: gapBeforeFeed,
                showPrimaryActionPanel: showPrimaryActionPanel,
                hasWallet: flags.hasWallet,
                hasBalance: flags.hasBalance,
                hasTransactions: flags.hasTransactions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _feedSlivers({
    required BuildContext context,
    required bool useWide,
    required double contentMaxWidth,
    required double pageHorizontalPadding,
    required double navigationClearance,
    required double gapAfterHeader,
    required double gapBeforeFeed,
    required bool showPrimaryActionPanel,
    required bool hasWallet,
    required bool hasBalance,
    required bool hasTransactions,
  }) {
    Widget pad(Widget child) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: KeroseneAppColumn(
          maxWidth: contentMaxWidth,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pageHorizontalPadding,
              0,
              pageHorizontalPadding,
              0,
            ),
            child: child,
          ),
        ),
      );
    }

    if (useWide) {
      return [
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(
              height: gapAfterHeader > 0 ? gapAfterHeader : homeSize(8),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: pad(
              HomeWideFeedBody(
                gapAfterHeader: gapAfterHeader,
                gapBeforeFeed: gapBeforeFeed,
                showPrimaryActionPanel: showPrimaryActionPanel,
                hasWallet: hasWallet,
                hasBalance: hasBalance,
                hasTransactions: hasTransactions,
                onOpenCreateWallet: widget.onCreateWallet,
                onOpenDeposit: widget.onOpenDeposit,
                onOpenSend: widget.onOpenSendFromFeed,
                onOpenStatement: widget.onOpenStatement,
                onDepositWallet: widget.onDepositWallet,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(height: navigationClearance),
          ),
        ),
      ];
    }

    final setupNotice = showPrimaryActionPanel
        ? HomeSetupNotice(
            icon: !hasWallet
                ? KeroseneIcons.wallet
                : !hasBalance
                    ? KeroseneIcons.download
                    : KeroseneIcons.send,
            title: !hasWallet
                ? context.l10n.homePrimaryNoWalletTitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceTitle
                    : context.tr.homePrimaryReadyTitle,
            subtitle: !hasWallet
                ? context.tr.homePrimaryNoWalletSubtitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceSubtitle
                    : context.tr.homePrimaryReadySubtitle,
            actionLabel: !hasWallet
                ? context.l10n.homeCreateWalletAction
                : !hasBalance
                    ? context.tr.homeReceiveBtcAction
                    : context.l10n.homeSendBtcAction,
            onAction: !hasWallet
                ? widget.onCreateWallet
                : !hasBalance
                    ? widget.onOpenDeposit
                    : widget.onOpenSendFromFeed,
          )
        : null;

    return [
      SliverToBoxAdapter(
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(
            height: gapAfterHeader > 0 ? gapAfterHeader : homeSize(8),
          ),
        ),
      ),
      // ── FEED layers (each section owns its providers) ───────────────────
      SliverToBoxAdapter(
        child: pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(child: HomeOnboardingProgressCard()),
              SizedBox(height: gapAfterHeader),
              const HomeMarketLayer(),
              if (setupNotice != null) ...[
                SizedBox(height: gapAfterHeader),
                setupNotice,
              ],
              SizedBox(height: gapBeforeFeed),
              const HomeEducationLayer(),
              SizedBox(height: homeSize(AppSpacing.md)),
              SizedBox(height: homeSize(AppSpacing.xl)),
              HomeFundsLayer(onViewStatement: widget.onOpenStatement),
              SizedBox(height: homeSize(AppSpacing.xl)),
              HomeSectionHeader(
                title: homeRecentActivitiesTitle(context),
                onAction: widget.onOpenStatement,
                actionLabel: homeSeeYourStatementLabel(context),
                actionTrailingChevron: true,
                actionTooltip: context.tr.statementScreenTitle,
              ),
              SizedBox(height: homeSize(AppSpacing.md)),
              if (hasTransactions) ...[
                RepaintBoundary(child: HomeActivityFilterChips()),
                SizedBox(height: homeSize(AppSpacing.md)),
              ],
            ],
          ),
        ),
      ),
      // ── TRANSACTIONS layer (virtualized, own watches) ──────────────────
      HomeTransactionsLayer(
        onCreateWallet: widget.onCreateWallet,
        onDepositWallet: widget.onDepositWallet,
      ),
      SliverFillRemaining(
        hasScrollBody: false,
        fillOverscroll: true,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(height: navigationClearance),
        ),
      ),
    ];
  }
}

// ── Isolated layers ──────────────────────────────────────────────────────────

/// Header: theater + balance. Watches only wallet/price inside [HomeBalanceSection].
class HomeHeaderLayer extends ConsumerWidget {
  final String userName;
  final double pageHorizontalPadding;
  final double pageTopPad;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onViewStatement;
  final VoidCallback onOpenWallets;

  const HomeHeaderLayer({
    super.key,
    required this.userName,
    required this.pageHorizontalPadding,
    required this.pageTopPad,
    required this.onReceive,
    required this.onSend,
    required this.onViewStatement,
    required this.onOpenWallets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coarse wallet fingerprint — ignore sub-satoshi noise so websocket
    // balance ticks don't rebuild the entire header+theater.
    ref.watch(walletProvider.select(_walletHeaderFingerprint));
    final walletState = ref.read(walletProvider);
    final activeWallet = walletState is WalletLoaded
        ? (walletState.selectedWallet ??
            (walletState.wallets.isNotEmpty ? walletState.wallets.first : null))
        : null;

    return RepaintBoundary(
      child: HomeBalanceSection(
        userName: userName,
        walletState: walletState,
        activeWallet: activeWallet,
        pageHorizontalPadding: pageHorizontalPadding,
        pageTopPad: pageTopPad,
        onReceive: onReceive,
        onSend: onSend,
        onViewStatement: onViewStatement,
        onOpenWallets: onOpenWallets,
      ),
    );
  }
}

String _walletHeaderFingerprint(WalletState w) {
  if (w is! WalletLoaded) return w.runtimeType.toString();
  final sel = w.selectedWallet?.id ?? '';
  final parts =
      w.wallets.map((x) => '${x.id}:${(x.balance * 1e5).round()}').join('|');
  return '$sel|$parts';
}

/// Market chart — own providers only (via card).
class HomeMarketLayer extends StatelessWidget {
  const HomeMarketLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: HomeBitcoinMarketChartCard());
  }
}

/// Education carousel — own feed providers only.
class HomeEducationLayer extends StatelessWidget {
  const HomeEducationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: HomeEducationCarousel());
  }
}

/// Funds distribution — wallet only.
class HomeFundsLayer extends ConsumerWidget {
  final VoidCallback onViewStatement;

  const HomeFundsLayer({super.key, required this.onViewStatement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(walletProvider.select(_walletHeaderFingerprint));
    final walletState = ref.read(walletProvider);
    return RepaintBoundary(
      child: HomeFundsDistributionSection(
        walletState: walletState,
        onViewStatement: onViewStatement,
      ),
    );
  }
}

/// Virtualized activity list — own filtered-tx provider.
class HomeTransactionsLayer extends StatelessWidget {
  final VoidCallback onCreateWallet;
  final ValueChanged<Wallet> onDepositWallet;

  const HomeTransactionsLayer({
    super.key,
    required this.onCreateWallet,
    required this.onDepositWallet,
  });

  @override
  Widget build(BuildContext context) {
    return HomeTransactionsList(
      asSliver: true,
      onCreateWallet: onCreateWallet,
      onDepositWallet: onDepositWallet,
    );
  }
}

/// Soft veil under balance / over feed — fades theater glow into the scaffold.
class HomeFeedTopVeil extends StatelessWidget {
  const HomeFeedTopVeil({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height:
          (MediaQuery.sizeOf(context).height * HomeMotion.veilHeightFraction)
              .clamp(72.0, 180.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base.withValues(alpha: 0.0),
              base.withValues(alpha: 0.18),
              base.withValues(alpha: 0.44),
              base.withValues(alpha: 0.72),
              base,
            ],
            stops: HomeMotion.veilStops,
          ),
        ),
      ),
    );
  }
}

/// Desktop two-column feed body (rare path).
class HomeWideFeedBody extends ConsumerWidget {
  final double gapAfterHeader;
  final double gapBeforeFeed;
  final bool showPrimaryActionPanel;
  final bool hasWallet;
  final bool hasBalance;
  final bool hasTransactions;
  final VoidCallback onOpenCreateWallet;
  final VoidCallback onOpenDeposit;
  final VoidCallback onOpenSend;
  final VoidCallback onOpenStatement;
  final ValueChanged<Wallet> onDepositWallet;

  const HomeWideFeedBody({
    super.key,
    required this.gapAfterHeader,
    required this.gapBeforeFeed,
    required this.showPrimaryActionPanel,
    required this.hasWallet,
    required this.hasBalance,
    required this.hasTransactions,
    required this.onOpenCreateWallet,
    required this.onOpenDeposit,
    required this.onOpenSend,
    required this.onOpenStatement,
    required this.onDepositWallet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = showPrimaryActionPanel
        ? HomeSetupNotice(
            icon: !hasWallet
                ? KeroseneIcons.wallet
                : !hasBalance
                    ? KeroseneIcons.download
                    : KeroseneIcons.send,
            title: !hasWallet
                ? context.l10n.homePrimaryNoWalletTitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceTitle
                    : context.tr.homePrimaryReadyTitle,
            subtitle: !hasWallet
                ? context.tr.homePrimaryNoWalletSubtitle
                : !hasBalance
                    ? context.tr.homePrimaryReadyNoBalanceSubtitle
                    : context.tr.homePrimaryReadySubtitle,
            actionLabel: !hasWallet
                ? context.l10n.homeCreateWalletAction
                : !hasBalance
                    ? context.tr.homeReceiveBtcAction
                    : context.l10n.homeSendBtcAction,
            onAction: !hasWallet
                ? onOpenCreateWallet
                : !hasBalance
                    ? onOpenDeposit
                    : onOpenSend,
          )
        : null;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(child: HomeOnboardingProgressCard()),
        SizedBox(height: gapAfterHeader),
        const HomeMarketLayer(),
        if (setup != null) ...[
          SizedBox(height: gapAfterHeader),
          setup,
        ],
        SizedBox(height: gapBeforeFeed),
        const HomeEducationLayer(),
        SizedBox(height: homeSize(AppSpacing.xl)),
        HomeFundsLayer(onViewStatement: onOpenStatement),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: homeRecentActivitiesTitle(context),
          onAction: onOpenStatement,
          actionLabel: homeSeeYourStatementLabel(context),
          actionTrailingChevron: true,
          actionTooltip: context.tr.statementScreenTitle,
        ),
        SizedBox(height: homeSize(AppSpacing.md)),
        if (hasTransactions) ...[
          RepaintBoundary(child: HomeActivityFilterChips()),
          SizedBox(height: homeSize(AppSpacing.md)),
        ],
        HomeTransactionsList(
          asSliver: false,
          onCreateWallet: onOpenCreateWallet,
          onDepositWallet: onDepositWallet,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: left),
        SizedBox(width: homeSize(AppSpacing.xl)),
        Expanded(flex: 4, child: right),
      ],
    );
  }
}
