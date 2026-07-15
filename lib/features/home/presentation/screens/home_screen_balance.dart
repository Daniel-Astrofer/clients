// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'dart:math' as math;

import 'home_screen_dependencies.dart';
import 'home_screen.dart';
import 'home_screen_surface.dart';

class HomeBalanceSection extends ConsumerStatefulWidget {
  final String userName;
  final WalletState walletState;
  final Wallet? activeWallet;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onViewStatement;
  final VoidCallback onOpenWallets;

  const HomeBalanceSection({
    required this.userName,
    required this.walletState,
    required this.activeWallet,
    required this.onReceive,
    required this.onSend,
    required this.onViewStatement,
    required this.onOpenWallets,
  });

  @override
  ConsumerState<HomeBalanceSection> createState() => HomeBalanceSectionState();
}

class HomeBalanceSectionState extends ConsumerState<HomeBalanceSection> {
  final GlobalKey _notificationButtonKey = GlobalKey();
  late final PageController _pageController;
  int _lastSyncedIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialPage = ref.read(homeLedgerBalancePageProvider);
    _lastSyncedIndex = initialPage;
    _pageController = PageController(initialPage: initialPage);
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
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final selectedCurrency = ref.watch(currencyProvider);
    final balanceSettings = ref.watch(balanceSettingsProvider);
    final notificationCount = ref.watch(sessionNotificationUnreadCountProvider);
    final priceFeedActive = ref.watch(homeRouteActiveProvider);
    final btcUsd = priceFeedActive ? ref.watch(latestBtcPriceProvider) : null;
    final btcEur = priceFeedActive ? ref.watch(btcEurPriceProvider) : null;
    final btcBrl = priceFeedActive ? ref.watch(btcBrlPriceProvider) : null;
    final btcDailyChangePercent =
        priceFeedActive ? ref.watch(btcDailyChangePercentProvider) : null;
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
      if (hasInternal)
        _HomeBalanceTab(
          view: HomeLedgerBalanceView.platform,
          label: homePlatformTabLabel(context),
          accent: homeBalanceAccentFor(HomeLedgerBalanceView.platform),
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
      final balanceBtc = _sumWallets(scopedWallets);
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
              ? MoneyDisplay.format(
                  amount: convertedBalanceValue,
                  currency: quoteCurrency,
                )
              : '${quoteCurrency.code} indisponivel';
      final dailyChangeValue = hasSelectedQuote && btcDailyChangePercent != null
          ? convertedBalanceValue * (btcDailyChangePercent / 100)
          : null;
      final isDailyChangePositive = (dailyChangeValue ?? 0) >= 0;
      final dailyChangeColor =
          isDailyChangePositive ? homePositiveColor : AppColors.hexFFFF5A67;
      final dailyChangeSign = isDailyChangePositive ? '+' : '-';
      final percentSeparator =
          MoneyDisplay.localeFor(quoteCurrency).startsWith('en') ? '.' : ',';
      final dailyChangePercentLabel = btcDailyChangePercent
          ?.abs()
          .toStringAsFixed(2)
          .replaceAll('.', percentSeparator);
      final dailyChangeLabel = dailyChangePercentLabel != null
          ? '$dailyChangeSign$dailyChangePercentLabel% (24h)'
          : '${quoteCurrency.code} indisponivel';

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

    void toggleVisibility() {
      HapticFeedback.lightImpact();
      ref.read(balanceSettingsProvider.notifier).toggleVisibility();
    }

    void onPageChanged(int index) {
      if (index < 0 || index >= tabs.length) return;
      final view = tabs[index].view;
      _lastSyncedIndex = index;
      HapticFeedback.selectionClick();
      ref.read(homeLedgerBalanceViewProvider.notifier).state = view;
      ref.read(homeLedgerBalancePageProvider.notifier).state = index;
    }

    final heroHeight = responsive.isTinyPhone ? homeSize(220) : homeSize(236);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _localizedGreeting(context, widget.userName),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: AppTypography.newsreader(
                    textStyle: theme.textTheme.titleLarge,
                    color: Colors.white,
                    fontSize: _greetingFontSize(
                      userName: widget.userName,
                      baseFontSize: responsive.compactFontSize(
                        tiny: homeFontSize(22),
                        compact: homeFontSize(24),
                        regular: homeFontSize(25),
                      ),
                    ),
                    fontWeight: FontWeight.w300,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            SizedBox(width: homeSize(12)),
            HomeHeaderIconButton(
              icon: balanceSettings.isHidden
                  ? KeroseneIcons.eyeOff
                  : KeroseneIcons.eye,
              onTap: toggleVisibility,
            ),
            SizedBox(width: homeSize(8)),
            HomeHeaderIconButton(
              key: _notificationButtonKey,
              icon: KeroseneIcons.notifications,
              hasBadge: notificationCount > 0,
              onTap: () async {
                HapticFeedback.selectionClick();
                if (!mounted) {
                  return;
                }
                await openNotificationCenter(
                  context,
                  originKey: _notificationButtonKey,
                );
              },
            ),
            SizedBox(width: homeSize(8)),
            HomeHeaderIconButton(
              icon: KeroseneIcons.settings,
              onTap: () {
                HapticFeedback.selectionClick();
                AppPrimaryNavigationBar.navigateTo(
                  context,
                  AppPrimaryDestination.settings,
                );
              },
            ),
          ],
        ),
        SizedBox(height: homeSize(12)),
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
              _pageController.animateToPage(
                index,
                duration: KeroseneMotion.medium,
                curve: KeroseneMotion.standard,
              );
            },
          ),
        ],
        SizedBox(height: homeSize(20)),
        Row(
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

  static String _localizedGreeting(BuildContext context, String userName) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return context.tr.homeGreetingMorning(userName);
    }
    if (hour < 18) {
      return context.tr.homeGreetingAfternoon(userName);
    }
    return context.tr.homeGreetingEvening(userName);
  }

  static double _greetingFontSize({
    required String userName,
    required double baseFontSize,
  }) {
    const maxNameCharsAtBaseSize = 9;
    final nameLength = userName.runes.length;
    if (nameLength <= maxNameCharsAtBaseSize) {
      return baseFontSize;
    }

    return (baseFontSize * maxNameCharsAtBaseSize / nameLength)
        .clamp(homeFontSize(14), baseFontSize);
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

/// Large ambient glow at the top of the home screen (not behind the balance).
/// Solid core near the top edge; soft gradient falls toward the balance zone.
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
                  // Solid core at the top of the screen.
                  accent.withValues(alpha: 0.52),
                  accent.withValues(alpha: 0.28),
                  // Soft falloff reaching toward the balance area.
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
class HomeBalanceHero extends ConsumerWidget {
  final HomeBalanceCardData data;
  final VoidCallback onOpenWallets;

  const HomeBalanceHero({
    super.key,
    required this.data,
    required this.onOpenWallets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: data.accent.withValues(alpha: 0.88),
                fontSize: homeFontSize(12),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            if (!isTotal && data.wallet != null) ...[
              SizedBox(height: homeSize(6)),
              Text(
                walletName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: homeFontSize(13),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
            ],
            SizedBox(height: homeSize(14)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBalanceDisplay(
                    balance: data.balanceBtc,
                    decimalPlaces: data.decimalPlaces,
                    locale: MoneyDisplay.localeFor(Currency.btc),
                    enableFlash: false,
                    isHidden: data.balanceHidden,
                    digitWidthFactor: 0.72,
                    characterSpacing: 0.1,
                    decimalScaleFactor: 0.78,
                    separatorScaleFactor: 0.78,
                    style:
                        AppTypography.homeBalance(color: Colors.white).copyWith(
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
                      style: theme.textTheme.bodyLarge?.copyWith(
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
            Text(
              data.convertedBalanceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: homeMutedTextColor,
                fontSize: homeFontSize(15),
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
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
                    style: theme.textTheme.bodySmall?.copyWith(
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

/// Kept for storybook / legacy references — glass card removed from home path.
class HomeBalanceCard extends ConsumerWidget {
  final HomeBalanceCardData data;
  final VoidCallback onViewStatement;
  final VoidCallback onOpenWallets;

  const HomeBalanceCard({
    required this.data,
    required this.onViewStatement,
    required this.onOpenWallets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeBalanceHero(
      data: data,
      onOpenWallets: onOpenWallets,
    );
  }
}

class HomeAvatar extends StatelessWidget {
  final String name;

  const HomeAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = _initialFor(name);

    return Container(
      width: homeSize(40),
      height: homeSize(40),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: homeCardColor,
        border: Border.all(color: homePanelBorderColor),
        image: const DecorationImage(
          image: AssetImage(KeroseneLogo.assetPath),
          fit: BoxFit.cover,
          opacity: 0.18,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }

  static String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '...') {
      return 'K';
    }
    return trimmed.characters.first.toUpperCase();
  }
}

/// Accent colors for each balance carousel page (glow + labels + dots).
Color homeBalanceAccentFor(HomeLedgerBalanceView view) {
  return switch (view) {
    HomeLedgerBalanceView.total => const Color(0xFFE8E8E8),
    HomeLedgerBalanceView.onChain => const Color(0xFF40A0FF),
    HomeLedgerBalanceView.cold => const Color(0xFF7DD3FC),
    HomeLedgerBalanceView.platform => const Color(0xFFF59E0B),
  };
}

String homeInternalBalanceTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Internal balance',
    'es' => 'Saldo interno',
    _ => 'Saldo Interno',
  };
}

String homeOnchainBalanceTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'On-chain balance',
    'es' => 'Saldo on-chain',
    _ => 'Saldo Onchain',
  };
}

String homeColdBalanceTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Cold wallet balance',
    'es' => 'Saldo cold wallet',
    _ => 'Saldo Cold Wallet',
  };
}

String homeTotalBalanceTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Total balance',
    'es' => 'Saldo total',
    _ => 'Saldo Total',
  };
}

String homeTotalTabLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Total',
    'es' => 'Total',
    _ => 'Total',
  };
}

String homePlatformTabLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Internal',
    'es' => 'Interno',
    _ => 'Interno',
  };
}

String homeOnchainTabLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'On-chain',
    'es' => 'On-chain',
    _ => 'Onchain',
  };
}

String homeColdTabLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Cold',
    'es' => 'Cold',
    _ => 'Cold',
  };
}

String homeCofreTabLabel(BuildContext context) => homeColdTabLabel(context);

String homeGlobalWalletTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Global wallet',
    'es' => 'Cartera global',
    _ => 'Carteira Global',
  };
}

String homeConsolidatedWalletTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Total Balance',
    'es' => 'Saldo Total',
    _ => 'Saldo Total',
  };
}

String homeOnchainWalletCardTitle(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'On-chain wallet',
    'es' => 'Cartera on-chain',
    _ => 'Carteira Onchain',
  };
}

String homeStatementActionLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Go to statement',
    'es' => 'Ir al extracto',
    _ => 'Ir para extrato',
  };
}
