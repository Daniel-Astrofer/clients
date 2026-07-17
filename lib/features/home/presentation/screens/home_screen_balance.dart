// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'dart:math' as math;

import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_balance_ceremony_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_stage_playback_provider.dart';
import 'package:kerosene/features/home/presentation/widgets/home_communication_stage.dart';
import 'package:kerosene/features/home/presentation/widgets/home_stage_atmosphere.dart';

import 'home_screen_dependencies.dart';
import 'home_screen.dart';
import 'home_screen_surface.dart';

/// Coarse quote so tiny websocket ticks don't rebuild the balance header.
double? _coarseUsdQuote(double? price) {
  if (price == null || price <= 0) return price;
  return (price / 25).round() * 25.0;
}

/// Coarse daily-change percent (0.05 steps).
double? _coarseChangePct(double? pct) {
  if (pct == null) return null;
  return (pct * 20).round() / 20.0;
}

class HomeBalanceSection extends ConsumerStatefulWidget {
  final String userName;
  final WalletState walletState;
  final Wallet? activeWallet;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onViewStatement;
  final VoidCallback onOpenWallets;
  /// Horizontal inset for full-bleed wash vs padded content.
  final double pageHorizontalPadding;
  final double pageTopPad;

  const HomeBalanceSection({
    required this.userName,
    required this.walletState,
    required this.activeWallet,
    required this.onReceive,
    required this.onSend,
    required this.onViewStatement,
    required this.onOpenWallets,
    this.pageHorizontalPadding = 24,
    this.pageTopPad = 16,
  });

  @override
  ConsumerState<HomeBalanceSection> createState() => HomeBalanceSectionState();
}

class HomeBalanceSectionState extends ConsumerState<HomeBalanceSection> {
  final GlobalKey _notificationButtonKey = GlobalKey();
  late final PageController _pageController;
  int _lastSyncedIndex = 0;
  HomeLedgerBalanceView? _amountView;
  bool _suppressRollForViewChange = false;
  bool _playSessionCeremony = false;

  @override
  void initState() {
    super.initState();
    final initialPage = ref.read(homeLedgerBalancePageProvider);
    _lastSyncedIndex = initialPage;
    _pageController = PageController(initialPage: initialPage);
    // Claim before first paint so digit ceremony can run once per session.
    _playSessionCeremony =
        ref.read(homeBalanceCeremonyPlayedProvider.notifier).claim();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToIndexIfNeeded(int index) {
    if (index == _lastSyncedIndex) return;
    _lastSyncedIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final current =
          _pageController.page?.round() ?? _pageController.initialPage;
      if (current != index) {
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final selectedCurrency = ref.watch(currencyProvider);
    final money = ref.watch(moneyFormatConfigProvider);
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final priceFeedActive = ref.watch(homeRouteActiveProvider);
    // Round quotes so minor tick churn doesn't rebuild the whole header
    // (header rebuild mid-scroll is a common FPS cliff).
    final btcUsd = priceFeedActive
        ? ref.watch(latestBtcPriceProvider.select(_coarseUsdQuote))
        : null;
    final btcEur = priceFeedActive
        ? ref.watch(btcEurPriceProvider.select(_coarseUsdQuote))
        : null;
    final btcBrl = priceFeedActive
        ? ref.watch(btcBrlPriceProvider.select(_coarseUsdQuote))
        : null;
    final btcDailyChangePercent = priceFeedActive
        ? ref.watch(btcDailyChangePercentProvider.select(_coarseChangePct))
        : null;
    final selectedView = ref.watch(homeLedgerBalanceViewProvider);
    final wallets = widget.walletState is WalletLoaded
        ? (widget.walletState as WalletLoaded).wallets
        : const <Wallet>[];
    final quoteCurrency =
        selectedCurrency == Currency.btc ? Currency.brl : selectedCurrency;
    final hasSelectedQuote = switch (quoteCurrency) {
      Currency.btc => true,
      Currency.usd => btcUsd != null && btcUsd > 0,
      Currency.eur => btcEur != null && btcEur > 0,
      Currency.brl => btcBrl != null && btcBrl > 0,
    };

    final hasInternal = wallets
        .any((wallet) => wallet.isInternalCustody && !wallet.isColdWallet);
    final hasOnchain = wallets.any((wallet) => wallet.isCustodialOnchain);
    final hasCold = wallets.any((wallet) => wallet.isColdWallet);

    final tabs = <_HomeBalanceTab>[
      _HomeBalanceTab(
        view: HomeLedgerBalanceView.total,
        label: homeTotalTabLabel(context),
        accent: homeBalanceAccentFor(HomeLedgerBalanceView.total),
      ),
      if (hasInternal)
        _HomeBalanceTab(
          view: HomeLedgerBalanceView.platform,
          label: homePlatformTabLabel(context),
          accent: homeBalanceAccentFor(HomeLedgerBalanceView.platform),
        ),
      if (hasOnchain)
        _HomeBalanceTab(
          view: HomeLedgerBalanceView.onChain,
          label: homeOnchainTabLabel(context),
          accent: homeBalanceAccentFor(HomeLedgerBalanceView.onChain),
        ),
      if (hasCold)
        _HomeBalanceTab(
          view: HomeLedgerBalanceView.cold,
          label: homeColdTabLabel(context),
          accent: homeBalanceAccentFor(HomeLedgerBalanceView.cold),
        ),
    ];

    // Keep selection valid if a category disappears.
    final selectedTab = tabs.any((tab) => tab.view == selectedView)
        ? selectedView
        : HomeLedgerBalanceView.total;
    final selectedIndex = tabs
        .indexWhere((tab) => tab.view == selectedTab)
        .clamp(0, math.max(0, tabs.length - 1))
        .toInt();

    if (selectedTab != selectedView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(homeLedgerBalanceViewProvider.notifier).state = selectedTab;
        ref.read(homeLedgerBalancePageProvider.notifier).state = selectedIndex;
      });
    }
    _jumpToIndexIfNeeded(selectedIndex);

    HomeBalanceCardData cardDataFor(HomeLedgerBalanceView view) {
      final scopedWallets = _walletsForView(wallets, view);
      final primaryWallet = _primaryWalletForView(
        activeWallet: widget.activeWallet,
        scopedWallets: scopedWallets,
        view: view,
      );
      // Total tab = spendable now (internal + custodial available). Cold is
      // observed-only and must not inflate "can send" mental model.
      final balanceBtc = view == HomeLedgerBalanceView.total
          ? _sumSpendableWallets(scopedWallets)
          : _sumWallets(scopedWallets);
      final convertedBalanceValue = MoneyDisplay.convertFromBtcAmount(
        btcAmount: balanceBtc,
        currency: quoteCurrency,
        btcUsd: btcUsd,
        btcEur: btcEur,
        btcBrl: btcBrl,
      );
      final convertedBalanceLabel = balanceSettings.isHidden
          ? '${MoneyDisplay.tickerSymbolFor(quoteCurrency)} ••••••••'
          : hasSelectedQuote
              ? money.format(
                  amount: convertedBalanceValue,
                  currency: quoteCurrency,
                )
              : homeQuoteUnavailableLabel(context, quoteCurrency);
      final dailyChangeValue = hasSelectedQuote && btcDailyChangePercent != null
          ? convertedBalanceValue * (btcDailyChangePercent / 100)
          : null;
      final isDailyChangePositive = (dailyChangeValue ?? 0) >= 0;
      final dailyChangeColor =
          isDailyChangePositive ? homePositiveColor : AppColors.hexFFFF5A67;
      final dailyChangeSign = isDailyChangePositive ? '+' : '-';
      // Follow app language (not currency-native locale) for market % text.
      final percentSeparator =
          MoneyDisplay.numberLocaleTag(money.locale).startsWith('en')
              ? '.'
              : ',';
      final dailyChangePercentLabel = btcDailyChangePercent
          ?.abs()
          .toStringAsFixed(2)
          .replaceAll('.', percentSeparator);
      // Market BTC 24h move — not personal portfolio P&L.
      final dailyChangeLabel = dailyChangePercentLabel != null
          ? homeBtcMarketChangeLabel(
              context,
              sign: dailyChangeSign,
              percent: dailyChangePercentLabel,
            )
          : homeQuoteUnavailableLabel(context, quoteCurrency);

      return HomeBalanceCardData(
        view: view,
        wallet: view == HomeLedgerBalanceView.total ? null : primaryWallet,
        balanceBtc: balanceBtc,
        convertedBalanceLabel: convertedBalanceLabel,
        dailyChangeLabel: dailyChangeLabel,
        dailyChangeColor: dailyChangeColor,
        decimalPlaces: balanceSettings.decimalPlaces,
        balanceHidden: balanceSettings.isHidden,
        accent: homeBalanceAccentFor(view),
      );
    }

    void onPageChanged(int index) {
      if (index < 0 || index >= tabs.length) return;
      final view = tabs[index].view;
      _lastSyncedIndex = index;
      HapticFeedback.selectionClick();
      // Never digit-roll when switching ledger context.
      _suppressRollForViewChange = true;
      ref.read(homeLedgerBalanceViewProvider.notifier).state = view;
      ref.read(homeLedgerBalancePageProvider.notifier).state = index;
    }

    final heroHeight = responsive.isTinyPhone ? homeSize(220) : homeSize(236);
    final playback = ref.watch(homeStagePlaybackProvider);
    // Match theater open curve (720ms easeOutCubic from HomeSceneHost).
    final bodyOffset = playback.bodyOffsetPx;
    final bodyDuration = Duration(
      milliseconds: playback.bodyShiftDurationMs.clamp(480, 1200),
    );
    final bodyCurve = resolveStageCurve(playback.bodyShiftCurve);

    // Single amount display — not inside PageView (avoids remount/odometer on swipe).
    final activeData = cardDataFor(selectedTab);
    if (_amountView != selectedTab) {
      if (_amountView != null) {
        _suppressRollForViewChange = true;
      }
      _amountView = selectedTab;
    }
    // After this frame's build committed a view change, clear suppress on next data tick.
    final suppressRoll = _suppressRollForViewChange;
    if (_suppressRollForViewChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _suppressRollForViewChange) {
          setState(() => _suppressRollForViewChange = false);
        }
      });
    }

    // Session ceremony only once; never while suppressing (shouldn't coincide).
    final animateCeremony =
        _playSessionCeremony && !suppressRoll && !activeData.balanceHidden;
    if (_playSessionCeremony) {
      // Consume so rebuilds don't re-trigger ceremony path forever.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playSessionCeremony) {
          setState(() => _playSessionCeremony = false);
        }
      });
    }

    final hPad = widget.pageHorizontalPadding;
    final topPad = widget.pageTopPad;

    // Fully transparent header+balance over the fixed aurora — no gradient
    // slabs (they always left a faint horizontal seam when scrolling).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeTheaterHeaderWash(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, homeSize(10)),
            child: HomeCommunicationStage(
              userName: widget.userName,
              notificationButtonKey: _notificationButtonKey,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, homeSize(8), hPad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: bodyDuration,
                curve: bodyCurve,
                height: bodyOffset,
              ),
              SizedBox(
                height: heroHeight,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: tabs.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    return HomeBalanceHero(
                      key: ValueKey('home-balance-hero-${tab.view.name}'),
                      data: cardDataFor(tab.view),
                      onOpenWallets: widget.onOpenWallets,
                      suppressDigitRoll: suppressRoll,
                      animateInitialValue: animateCeremony,
                    );
                  },
                ),
              ),
              if (tabs.length > 1) ...[
                SizedBox(height: homeSize(10)),
                _HomeBalancePageDots(
                  count: tabs.length,
                  activeIndex: selectedIndex,
                  accents: [for (final tab in tabs) tab.accent],
                  onDotTap: (index) {
                    if (!_pageController.hasClients) return;
                    _lastSyncedIndex = index;
                    HapticFeedback.selectionClick();
                    _suppressRollForViewChange = true;
                    _pageController.animateToPage(
                      index,
                      duration: KeroseneMotion.medium,
                      curve: KeroseneMotion.standard,
                    );
                  },
                ),
              ],
              SizedBox(height: homeSize(20)),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsive.useWideHomeLayout
                        ? homeSize(560)
                        : double.infinity,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: HomeBalanceActionButton(
                          icon: KeroseneIcons.down,
                          label: context.tr.homeReceiveActionShort,
                          onTap: widget.onReceive,
                          primary: true,
                        ),
                      ),
                      SizedBox(width: homeSize(12)),
                      Expanded(
                        child: HomeBalanceActionButton(
                          icon: KeroseneIcons.up,
                          label: context.tr.homeSendTitle,
                          onTap: widget.onSend,
                          primary: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<Wallet> _walletsForView(
    List<Wallet> wallets,
    HomeLedgerBalanceView view,
  ) {
    return switch (view) {
      HomeLedgerBalanceView.total => wallets,
      HomeLedgerBalanceView.onChain => wallets
          .where((wallet) => wallet.isCustodialOnchain)
          .toList(growable: false),
      HomeLedgerBalanceView.cold =>
        wallets.where((wallet) => wallet.isColdWallet).toList(growable: false),
      HomeLedgerBalanceView.platform => wallets
          .where((wallet) => wallet.isInternalCustody && !wallet.isColdWallet)
          .toList(growable: false),
    };
  }

  static Wallet? _primaryWalletForView({
    required Wallet? activeWallet,
    required List<Wallet> scopedWallets,
    required HomeLedgerBalanceView view,
  }) {
    if (view == HomeLedgerBalanceView.total) {
      return activeWallet ??
          (scopedWallets.isNotEmpty ? scopedWallets.first : null);
    }

    bool matches(Wallet wallet) => switch (view) {
          HomeLedgerBalanceView.onChain => wallet.isCustodialOnchain,
          HomeLedgerBalanceView.cold => wallet.isColdWallet,
          HomeLedgerBalanceView.platform =>
            wallet.isInternalCustody && !wallet.isColdWallet,
          HomeLedgerBalanceView.total => true,
        };

    if (activeWallet != null && matches(activeWallet)) {
      return activeWallet;
    }
    return scopedWallets.isNotEmpty ? scopedWallets.first : null;
  }

  static double _sumWallets(List<Wallet> wallets) {
    return wallets.fold<double>(0, (sum, wallet) => sum + wallet.balance);
  }

  /// Kerosene-spendable only (internal + custodial available). Cold excluded.
  static double _sumSpendableWallets(List<Wallet> wallets) {
    return wallets.fold<double>(0, (sum, wallet) {
      if (wallet.isColdWallet || wallet.isObservedOnlyBalance) return sum;
      return sum + wallet.balance;
    });
  }

}

class _HomeBalanceTab {
  final HomeLedgerBalanceView view;
  final String label;
  final Color accent;

  const _HomeBalanceTab({
    required this.view,
    required this.label,
    required this.accent,
  });
}

class _HomeBalancePageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final List<Color> accents;
  final ValueChanged<int> onDotTap;

  const _HomeBalancePageDots({
    required this.count,
    required this.activeIndex,
    required this.accents,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        final accent = accents[index.clamp(0, accents.length - 1)];
        return GestureDetector(
          onTap: () => onDotTap(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: homeSize(4)),
            child: AnimatedContainer(
              duration: KeroseneMotion.fast,
              curve: KeroseneMotion.standard,
              width: active ? homeSize(18) : homeSize(7),
              height: homeSize(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(homeSize(999)),
                color: active
                    ? accent.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Legacy single-glow widget. Prefer [HomeStageAtmosphereLayer] on the home
/// Stack (classic fallback + backend multi-glow). Kept for reference / tests.
@Deprecated('Use HomeStageAtmosphereLayer — classic recipe lives there as fallback')
class HomeTopAmbientGlow extends ConsumerWidget {
  const HomeTopAmbientGlow({super.key});

  /// Previous hero glow was ~280×180 — 5× larger footprint.
  static double get _glowWidth => homeSize(280) * 5;
  static double get _glowHeight => homeSize(180) * 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(homeLedgerBalanceViewProvider);
    final accent = homeBalanceAccentFor(view);
    final topInset = MediaQuery.paddingOf(context).top;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, -_glowHeight * 0.42 + topInset * 0.15),
          child: AnimatedContainer(
            duration: KeroseneMotion.medium,
            curve: KeroseneMotion.standard,
            width: _glowWidth,
            height: _glowHeight,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 0.72,
                colors: [
                  accent.withValues(alpha: 0.52),
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.10),
                  accent.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.22, 0.52, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating balance on pure OLED black — no glass card, no ambient glow behind.
///
/// [AnimatedBalanceDisplay] is shared across ledger tabs (not recreated per
/// PageView page) so swiping never re-triggers digit odometer.
class HomeBalanceHero extends ConsumerWidget {
  final HomeBalanceCardData data;
  final VoidCallback onOpenWallets;
  final bool suppressDigitRoll;
  final bool animateInitialValue;

  const HomeBalanceHero({
    super.key,
    required this.data,
    required this.onOpenWallets,
    this.suppressDigitRoll = false,
    this.animateInitialValue = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = context.responsive;
    final isTotal = data.view == HomeLedgerBalanceView.total;
    final title = switch (data.view) {
      HomeLedgerBalanceView.total => homeTotalBalanceTitle(context),
      HomeLedgerBalanceView.onChain => homeOnchainBalanceTitle(context),
      HomeLedgerBalanceView.cold => homeColdBalanceTitle(context),
      HomeLedgerBalanceView.platform => homeInternalBalanceTitle(context),
    };
    final walletName =
        _nonEmpty(data.wallet?.name, homeGlobalWalletTitle(context));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onOpenWallets();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: homeSize(4)),
        child: Semantics(
          container: true,
          label: '$title. $walletName. Saldo: ${data.balanceHidden ? "Oculto" : "${data.balanceBtc} BTC, ou ${data.convertedBalanceLabel}"}. ${data.dailyChangeLabel}',
          excludeSemantics: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: KeroseneMotion.short,
              switchInCurve: KeroseneMotion.standard,
              switchOutCurve: KeroseneMotion.exit,
              child: Text(
                title.toUpperCase(),
                key: ValueKey('balance-title-${data.view.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(
                  color: data.accent.withValues(alpha: 0.88),
                  fontSize: homeFontSize(12),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // Wallet name only — no dual-ledger / "available vs chain" subtitle.
            if (!isTotal && data.wallet != null) ...[
              SizedBox(height: homeSize(6)),
              AnimatedSwitcher(
                duration: KeroseneMotion.short,
                child: Text(
                  walletName,
                  key: ValueKey('wallet-$walletName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.h3.copyWith(
                    color: HomeColors.textPrimary.withValues(alpha: 0.75),
                    fontSize: homeFontSize(13),
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
            SizedBox(height: homeSize(14)),
            // No background glow on the amount — swipe between wallets must stay
            // clean black. Receive feedback lives in the theater stage, not here.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBalanceDisplay(
                    key: const ValueKey('home-balance-amount'),
                    balance: data.balanceBtc,
                    decimalPlaces: data.decimalPlaces,
                    // App language separators (pt → 0,00 / en → 0.00), not BTC en_US.
                    locale: ref.watch(moneyFormatConfigProvider).numberLocaleTag,
                    // Never flash on ledger swipe / remount. Live large deltas only.
                    enableFlash: !suppressDigitRoll,
                    isHidden: data.balanceHidden,
                    digitWidthFactor: 0.72,
                    characterSpacing: 0.1,
                    decimalScaleFactor: 0.78,
                    separatorScaleFactor: 0.78,
                    animateInitialValue: animateInitialValue,
                    suppressRoll: suppressDigitRoll,
                    largeDeltaThreshold: kHomeBalanceLargeDeltaBtc,
                    style: AppTypography.homeBalance(
                      color: Colors.white,
                    ).copyWith(
                      fontSize: responsive.compactFontSize(
                        tiny: homeFontSize(40),
                        compact: homeFontSize(48),
                        regular: homeFontSize(54),
                      ),
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: homeSize(8),
                      bottom: homeSize(8),
                    ),
                    child: Text(
                      'BTC',
                      style: AppTypography.bodyLarge.copyWith(
                        color: homeMutedTextColor,
                        fontSize: homeFontSize(16),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: homeSize(10)),
            AnimatedSwitcher(
              duration: KeroseneMotion.short,
              child: Text(
                data.convertedBalanceLabel,
                key: ValueKey(data.convertedBalanceLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: homeMutedTextColor,
                  fontSize: homeFontSize(15),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
            ),
            SizedBox(height: homeSize(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.dailyChangeColor == homePositiveColor
                      ? KeroseneIcons.up
                      : KeroseneIcons.down,
                  color: data.dailyChangeColor,
                  size: homeSize(12),
                ),
                SizedBox(width: homeSize(5)),
                Flexible(
                  child: Text(
                    data.dailyChangeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: data.dailyChangeColor,
                      fontSize: homeFontSize(13),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  static String _nonEmpty(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }
}

class HomeBalanceCardData {
  final HomeLedgerBalanceView view;
  final Wallet? wallet;
  final double balanceBtc;
  final String convertedBalanceLabel;
  final String dailyChangeLabel;
  final Color dailyChangeColor;
  final int decimalPlaces;
  final bool balanceHidden;
  final Color accent;

  const HomeBalanceCardData({
    required this.view,
    required this.wallet,
    required this.balanceBtc,
    required this.convertedBalanceLabel,
    required this.dailyChangeLabel,
    required this.dailyChangeColor,
    required this.decimalPlaces,
    required this.balanceHidden,
    required this.accent,
  });

  factory HomeBalanceCardData.forWallet({
    required Wallet wallet,
    required String convertedBalanceLabel,
    required String dailyChangeLabel,
    required Color dailyChangeColor,
    required int decimalPlaces,
    required bool balanceHidden,
  }) {
    final view = wallet.isColdWallet
        ? HomeLedgerBalanceView.cold
        : wallet.isCustodialOnchain
            ? HomeLedgerBalanceView.onChain
            : HomeLedgerBalanceView.platform;
    return HomeBalanceCardData(
      view: view,
      wallet: wallet,
      balanceBtc: wallet.balance,
      convertedBalanceLabel: convertedBalanceLabel,
      dailyChangeLabel: dailyChangeLabel,
      dailyChangeColor: dailyChangeColor,
      decimalPlaces: decimalPlaces,
      balanceHidden: balanceHidden,
      accent: homeBalanceAccentFor(view),
    );
  }
}


/// Accent colors for each balance carousel page (glow + labels + dots).
Color homeBalanceAccentFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => const Color(0xFFFFFFFF),
    HomeLedgerBalanceView.platform => const Color(0xFFFFFFFF),
    HomeLedgerBalanceView.onChain => const Color(0xFFFF9500),
    HomeLedgerBalanceView.cold => const Color(0xFF7DD3FC),
  };
}

String homeInternalBalanceTitle(BuildContext context) {
  return context.tr.homeBalanceInternal;
}

String homeOnchainBalanceTitle(BuildContext context) {
  return context.tr.homeBalanceOnchain;
}

String homeColdBalanceTitle(BuildContext context) {
  return context.tr.homeBalanceCold;
}

String homeTotalBalanceTitle(BuildContext context) {
  return context.tr.homeBalanceTotal;
}

String homeTotalTabLabel(BuildContext context) {
  return context.tr.homeBalanceTotal;
}

String homeBtcMarketChangeLabel(
  BuildContext context, {
  required String sign,
  required String percent,
}) {
  return context.tr.homeBtcMarketChange(sign, percent);
}

String homeQuoteUnavailableLabel(BuildContext context, Currency currency) {
  return context.tr.homeQuoteUnavailable(currency.code);
}

/// Kept for callers; product no longer shows this dual-ledger subtitle on home.
String homeAvailableSubtitle(BuildContext context) => '';

String homePlatformTabLabel(BuildContext context) {
  return context.tr.homeWalletPlatform;
}

String homeOnchainTabLabel(BuildContext context) {
  return context.tr.homeOnchainTab;
}

String homeColdTabLabel(BuildContext context) {
  return context.tr.homeColdTab;
}

String homeCofreTabLabel(BuildContext context) => homeColdTabLabel(context);

String homeGlobalWalletTitle(BuildContext context) {
  return context.tr.homeWalletTotalLabel;
}

String homeConsolidatedWalletTitle(BuildContext context) {
  return context.tr.homeBalanceTotal;
}

String homeOnchainWalletCardTitle(BuildContext context) {
  return context.tr.homeOnchainWalletCardTitle;
}

String homeStatementActionLabel(BuildContext context) {
  return context.tr.homeStatementAction;
}
