// ignore_for_file: use_key_in_widget_constructors, unused_import, unused_element

import 'dart:math' as math;

import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';
import 'package:kerosene/features/home/presentation/providers/home_feed_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';

import 'home_screen_dependencies.dart';
import 'home_screen.dart';
import 'home_screen_surface.dart';
import 'home_screen_transactions.dart' show homeHasUnseenCancelledProvider;

class HomeEducationCarousel extends ConsumerStatefulWidget {
  const HomeEducationCarousel();

  @override
  ConsumerState<HomeEducationCarousel> createState() =>
      HomeEducationCarouselState();
}

class HomeEducationCarouselState extends ConsumerState<HomeEducationCarousel> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  HomeLedgerBalanceView? _lastView;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = ref.watch(homeLedgerBalanceViewProvider);
    final surfaceFeed = ref.watch(homeSurfaceProvider.select((s) => s.feed));
    final remoteAsync = ref.watch(homeFeedProvider);
    final remoteFromLegacy = remoteAsync.asData?.value;
    // Prefer surface feed items when the envelope already carried them.
    final remote =
        surfaceFeed.items.isNotEmpty ? surfaceFeed.items : remoteFromLegacy;
    final cards = resolveHomeFeedCards(
      context: context,
      view: view,
      remote: remote,
    );
    final feedHeight = homeSize(surfaceFeed.resolvedHeight);
    final cardPadding = homeSize(surfaceFeed.cardPadding);
    final gap = homeSize(surfaceFeed.gap);

    if (_lastView != view) {
      _lastView = view;
      _activeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: feedHeight,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _activeIndex = index);
              },
              itemBuilder: (context, index) {
                final card = cards[index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : gap / 2,
                    right: index == cards.length - 1 ? 0 : gap / 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(homeSize(16)),
                      onTap: card.cta?.isNavigate == true
                          ? () => _openFeedCta(context, card.cta!)
                          : null,
                      child: HomeGlassPanel(
                        borderRadius: BorderRadius.circular(homeSize(16)),
                        padding: EdgeInsets.all(cardPadding),
                        child: Row(
                          children: [
                            _HomeFeedMediaThumb(
                              media: card.media,
                              kind: card.kind,
                              feedItem: card,
                            ),
                            SizedBox(width: homeSize(16)),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.newsreader(
                                      textStyle: theme.textTheme.titleMedium,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: HomeTypography.cardTitleSize,
                                      fontWeight: FontWeight.w200,
                                      height: 1.1,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  SizedBox(height: homeSize(8)),
                                  Text(
                                    card.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: HomeTypography.captionSize,
                                      height: 1.45,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  SizedBox(height: homeSize(12)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card.tag.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                            fontSize: HomeTypography.smallLabelSize,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      if (card.cta?.isNavigate == true)
                                        Text(
                                          card.cta!.label,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: homeAmberColor,
                                            fontSize: HomeTypography.smallLabelSize,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: homeSize(12)),
        HomePaginationDots(
          count: cards.length,
          activeIndex: _activeIndex.clamp(0, cards.length - 1),
        ),
      ],
    );
  }
}

void _openFeedCta(BuildContext context, HomeFeedCta cta) {
  HapticFeedback.selectionClick();
  final target = cta.target.trim();
  if (target.isEmpty) return;
  if (target.startsWith('/')) {
    Navigator.of(context).pushNamed(target);
    return;
  }
  // Unknown scheme — ignore safely.
}

class _HomeFeedMediaThumb extends StatelessWidget {
  final HomeFeedMedia media;
  final HomeFeedKind kind;
  final HomeFeedItem? feedItem;

  const _HomeFeedMediaThumb({
    required this.media,
    required this.kind,
    this.feedItem,
  });

  @override
  Widget build(BuildContext context) {
    final accent = switch (kind) {
      HomeFeedKind.promo => homeAmberColor,
      HomeFeedKind.announcement => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
      HomeFeedKind.feature => const Color(0xFF5EE9A0),
      _ => Theme.of(context).colorScheme.onSurface,
    };

    Widget child;
    final url = media.url?.trim() ?? '';
    final poster = media.posterUrl?.trim() ?? '';
    final imageUrl = poster.isNotEmpty ? poster : url;
    // Skip legacy mock product shots under assets/feed/cards/.
    final isLegacyMockCard = imageUrl.contains('feed/cards/');
    final isAsset = imageUrl.startsWith('asset:');
    final assetPath = isAsset ? imageUrl.substring('asset:'.length) : imageUrl;

    final isImageCard = !isLegacyMockCard &&
        (media.type == HomeFeedMediaType.image ||
            media.type == HomeFeedMediaType.video ||
            media.type == HomeFeedMediaType.lottie) &&
        imageUrl.isNotEmpty;
    final thumbW = isImageCard ? homeSize(72) : homeSize(56);
    final thumbH = homeSize(46);
    final imgH = isImageCard ? homeSize(42) : homeSize(36);

    if (isImageCard) {
      final image = isAsset
          ? Image.asset(
              assetPath,
              width: thumbW,
              height: imgH,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                media.resolveIcon(),
                color: accent,
                size: homeSize(21),
              ),
            )
          : Image.network(
              imageUrl,
              width: thumbW,
              height: imgH,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                media.resolveIcon(),
                color: accent,
                size: homeSize(21),
              ),
            );
      child = ClipRRect(
        borderRadius: BorderRadius.circular(homeSize(8)),
        child: image,
      );
    } else {
      child = Icon(
        media.resolveIcon(),
        color: accent,
        size: homeSize(21),
      );
    }

    return Container(
      width: thumbW,
      height: thumbH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(homeSize(12)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Legacy local model kept for tests/callers that still import the name.
class HomeEducationCardData {
  final IconData icon;
  final String title;
  final String body;
  final String tag;

  const HomeEducationCardData({
    required this.icon,
    required this.title,
    required this.body,
    required this.tag,
  });
}

List<HomeEducationCardData> homeEducationCards(
  BuildContext context,
  HomeLedgerBalanceView view,
) {
  return localEducationFallback(context, view)
      .map(
        (item) => HomeEducationCardData(
          icon: item.media.resolveIcon(),
          title: item.title,
          body: item.body,
          tag: item.tag,
        ),
      )
      .toList(growable: false);
}

/// Same duration/curve as activity card expand/collapse.
const Duration _kHomeDistributionRevealDuration = Duration(milliseconds: 800);
const Curve _kHomeDistributionRevealCurve = Curves.easeInOutCubic;

class HomeFundsDistributionSection extends ConsumerStatefulWidget {
  final WalletState walletState;
  final VoidCallback onViewStatement;

  const HomeFundsDistributionSection({
    required this.walletState,
    required this.onViewStatement,
  });

  @override
  ConsumerState<HomeFundsDistributionSection> createState() =>
      _HomeFundsDistributionSectionState();
}

class _HomeFundsDistributionSectionState
    extends ConsumerState<HomeFundsDistributionSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  late final Animation<double> _progress;
  ScrollPosition? _scrollPosition;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: _kHomeDistributionRevealDuration,
    );
    _progress = CurvedAnimation(
      parent: _reveal,
      curve: _kHomeDistributionRevealCurve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _scrollPosition)) {
      _scrollPosition?.removeListener(_checkVisibility);
      _scrollPosition = position;
      _scrollPosition?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted || _started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    final screenH = MediaQuery.sizeOf(context).height;
    // Fire when the section enters the lower/mid viewport while scrolling.
    final visible = bottom > screenH * 0.1 && topLeft.dy < screenH * 0.92;
    if (!visible) return;
    _started = true;
    if (KeroseneMotion.reduceMotion(context)) {
      _reveal.value = 1;
    } else {
      unawaited(_reveal.forward());
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_checkVisibility);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallets = widget.walletState is WalletLoaded
        ? (widget.walletState as WalletLoaded).wallets
        : const <Wallet>[];
    final displayWallets = _sortedWallets(wallets);
    final totalBalance = displayWallets.fold<double>(
      0,
      (sum, wallet) => sum + math.max(0, wallet.balance),
    );
    final entries = <HomeWalletDistributionEntry>[
      for (var index = 0; index < displayWallets.length; index++)
        HomeWalletDistributionEntry(
          wallet: displayWallets[index],
          color: displayWallets.length == 1
              ? Theme.of(context).disabledColor
              : _walletDistributionColor(context, index),
          share: totalBalance > 0
              ? math.max(0, displayWallets[index].balance) / totalBalance
              : 0,
        ),
    ];
    final dominantEntry = entries.isEmpty
        ? null
        : entries.reduce((a, b) {
            if (b.share != a.share) return b.share > a.share ? b : a;
            return a.wallet.name.toLowerCase().compareTo(
                          b.wallet.name.toLowerCase(),
                        ) <=
                    0
                ? a
                : b;
          });
    final dominantId = dominantEntry?.wallet.id;

    return HomeGlassPanel(
      borderRadius: BorderRadius.circular(homeSize(16)),
      padding: EdgeInsets.fromLTRB(
        homeSize(18),
        homeSize(16),
        homeSize(18),
        homeSize(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  homeFundsDistributionTitle(context),
                  style: AppTypography.newsreader(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: HomeTypography.sectionTitleSize,
                    fontWeight: FontWeight.w200,
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onViewStatement,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                  padding: EdgeInsets.symmetric(horizontal: homeSize(8)),
                  minimumSize: Size(0, homeSize(32)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelSmall?.copyWith(
                    fontSize: homeFontSize(12),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                // Extrato already lives on Insights — use "Ver detalhes" here.
                child: Text(context.tr.txListViewDetails),
              ),
            ],
          ),
          SizedBox(height: homeSize(14)),
          if (entries.isEmpty)
            HomeDistributionEmptyState()
          else
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final t = _progress.value;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: homeSize(142),
                      height: homeSize(142),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size.square(homeSize(142)),
                            painter: HomeDistributionChartPainter(context: context, 
                              entries: entries,
                              progress: t,
                            ),
                          ),
                          Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: SizedBox(
                              width: homeSize(84),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dominantEntry?.wallet.name ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                                      fontSize: homeFontSize(10),
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  SizedBox(height: homeSize(4)),
                                  Text(
                                    _homeDistributionPercentLabel(
                                      (dominantEntry?.share ?? 0) * 100,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: homeFontSize(17),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: homeSize(16)),
                    Expanded(
                      child: Column(
                        children: [
                          for (final entry in entries.take(4))
                            HomeDistributionLegendItem(
                              entry: entry,
                              progress: t,
                              isDominant: entry.wallet.id == dominantId,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static List<Wallet> _sortedWallets(List<Wallet> wallets) {
    final active = wallets.where((wallet) => wallet.isActive).toList();
    final source = active.isNotEmpty ? active : List<Wallet>.from(wallets);
    source.sort((a, b) {
      final byBalance = b.balance.compareTo(a.balance);
      if (byBalance != 0) return byBalance;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return source;
  }
}

class HomeWalletDistributionEntry {
  final Wallet wallet;
  final Color color;
  final double share;

  const HomeWalletDistributionEntry({
    required this.wallet,
    required this.color,
    required this.share,
  });
}

class HomeDistributionEmptyState extends StatelessWidget {
  HomeDistributionEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(homeSize(16)),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141517) : const Color(0xFFF2F4F7)),
        borderRadius: BorderRadius.circular(homeSize(14)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: homeSize(36),
            height: homeSize(36),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141517) : const Color(0xFFF2F4F7)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              KeroseneIcons.wallet,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
              size: homeSize(18),
            ),
          ),
          SizedBox(width: homeSize(12)),
          Expanded(
            child: Text(
              _distributionCopy(
                context,
                pt: 'Nenhuma carteira disponível para distribuir fundos.',
                en: 'No wallet available for fund distribution.',
                es: 'No hay billeteras disponibles para distribuir fondos.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: homeFontSize(12),
                height: 1.35,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDistributionLegendItem extends StatelessWidget {
  final HomeWalletDistributionEntry entry;
  final double progress;
  final bool isDominant;

  const HomeDistributionLegendItem({
    required this.entry,
    required this.progress,
    required this.isDominant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = progress.clamp(0.0, 1.0);
    final share = entry.share.clamp(0.0, 1.0);
    // Dominant wallet keeps the largest bar; others scale relative to share.
    final barHeight = isDominant ? homeSize(7) : homeSize(5);

    return Padding(
      padding: EdgeInsets.only(bottom: homeSize(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: entry.color,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: homeSize(8)),
          ),
          SizedBox(width: homeSize(8)),
          // Wallet name — leave typography untouched.
          Expanded(
            flex: 5,
            child: Text(
              entry.wallet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: homeFontSize(12),
                fontWeight: FontWeight.w400,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(width: homeSize(8)),
          // White horizontal bar grows right → left on the wallet line only.
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final width = maxW * share * t;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: width,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(homeSize(99)),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: homeSize(8)),
          // Dominant share: black % on white chip (readable on dark panel).
          // Others: light % — wallet name styles stay untouched above.
          if (isDominant)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: homeSize(6),
                vertical: homeSize(2),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(homeSize(6)),
              ),
              child: Text(
                _homeDistributionPercentLabel(entry.share * 100),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  fontSize: homeFontSize(12),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            )
          else
            Text(
              _homeDistributionPercentLabel(entry.share * 100),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: homeFontSize(12),
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class HomeDistributionChartPainter extends CustomPainter {
  final List<HomeWalletDistributionEntry> entries;
  final BuildContext context;

  /// 0 → 1 reveal; arcs ease into their final positions.
  final double progress;

  const HomeDistributionChartPainter({required this.context, 
    required this.entries,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - homeSize(12);
    final strokeWidth = homeSize(16);
    final basePaint = Paint()
      ..color = Theme.of(context).dividerColor.withValues(alpha: 0.72 * (0.35 + 0.65 * t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, basePaint);

    final totalShare =
        entries.fold<double>(0, (sum, entry) => sum + entry.share);
    if (totalShare <= 0 || t <= 0) return;

    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    const gap = 0.012;

    for (final entry in entries) {
      final normalizedShare = entry.share / totalShare;
      // Sweep grows with reveal so slices “take” their seats.
      final sweep = (math.pi * 2) * normalizedShare * t;
      if (sweep <= 0) continue;
      segmentPaint.color = entry.color.withValues(
        alpha: (entry.color.a * (0.55 + 0.45 * t)).clamp(0.0, 1.0),
      );
      canvas.drawArc(
        rect,
        start + gap,
        math.max(0, sweep - gap * 2),
        false,
        segmentPaint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant HomeDistributionChartPainter oldDelegate) {
    if (oldDelegate.progress != progress) return true;
    if (oldDelegate.entries.length != entries.length) return true;
    for (var index = 0; index < entries.length; index++) {
      final old = oldDelegate.entries[index];
      final current = entries[index];
      if (old.wallet.id != current.wallet.id ||
          old.wallet.balance != current.wallet.balance ||
          old.share != current.share ||
          old.color != current.color) {
        return true;
      }
    }
    return false;
  }
}

Color _walletDistributionColor(BuildContext context, int index) {
  return switch (index % 6) {
    0 => Theme.of(context).colorScheme.onSurface,
    1 => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
    2 => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
    3 => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48),
    4 => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.34),
    _ => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
  };
}

String _homeDistributionPercentLabel(double percent) {
  if (percent.isNaN || percent.isInfinite || percent <= 0) return '0%';
  if ((percent - percent.round()).abs() < 0.05) {
    return '${percent.round()}%';
  }
  return '${percent.toStringAsFixed(1)}%';
}

String _distributionCopy(
  BuildContext context, {
  required String pt,
  required String en,
  required String es,
}) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => en,
    'es' => es,
    _ => pt,
  };
}

class HomeActivityFilterChips extends ConsumerWidget {
  const HomeActivityFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(homeActivityFilterProvider);
    // Home only: Todas · Recebido · Enviado · Canceladas.
    const filters = [
      HomeActivityFilter.all,
      HomeActivityFilter.incoming,
      HomeActivityFilter.outgoing,
      HomeActivityFilter.cancelled,
    ];

    // Reset legacy filters (onchain, lightning, …) that no longer have a chip.
    if (!filters.contains(selectedFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(homeActivityFilterProvider) != HomeActivityFilter.all) {
          ref.read(homeActivityFilterProvider.notifier).state =
              HomeActivityFilter.all;
        }
      });
    }

    final hasUnseenCancelled = ref.watch(homeHasUnseenCancelledProvider);

    void selectFilter(HomeActivityFilter filter) {
      HapticFeedback.selectionClick();
      ref.read(homeActivityFilterProvider.notifier).state = filter;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++) ...[
            if (index > 0) SizedBox(width: homeSize(8)),
            HomeActivityFilterChip(
              label: homeFilterLabel(context, filters[index]),
              selected: selectedFilter == filters[index],
              onTap: () => selectFilter(filters[index]),
              showUnseenDot: filters[index] == HomeActivityFilter.cancelled &&
                  hasUnseenCancelled,
            ),
          ],
        ],
      ),
    );
  }
}

class HomeActivityFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Red circle when there are cancelled txs the user has not opened yet.
  final bool showUnseenDot;

  const HomeActivityFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showUnseenDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(homeSize(999)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Ink(
              padding: EdgeInsets.symmetric(
                horizontal: homeSize(16),
                vertical: homeSize(7),
              ),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(homeSize(999)),
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: selected ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: HomeTypography.captionSize,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (showUnseenDot)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String homeFundsDistributionTitle(BuildContext context) {
  return context.tr.homeFundsDistributionTitle;
}

String homeRecentActivitiesTitle(BuildContext context) {
  return context.tr.homeRecentActivitiesTitle;
}

String homeViewAllLabel(BuildContext context) {
  return context.tr.viewAll;
}

String homeViewStatementShortLabel(BuildContext context) {
  return context.tr.homeViewStatementShortLabel;
}

String homeOnchainFilterLabel(BuildContext context) {
  return context.tr.homeOnchainFilterLabel;
}

String homePlatformFilterLabel(BuildContext context) {
  return context.tr.homePlatformFilterLabel;
}

String homeNoticesFilterLabel(BuildContext context) {
  return context.tr.homeNoticesFilterLabel;
}

String homeFilterLabel(BuildContext context, HomeActivityFilter filter) {
  return switch (filter) {
    HomeActivityFilter.all => context.tr.financialStatementFilterAll,
    HomeActivityFilter.incoming => context.tr.financialStatementFilterIncoming,
    HomeActivityFilter.outgoing => context.tr.financialStatementFilterOutgoing,
    HomeActivityFilter.internal => context.tr.activityFilterInstant,
    HomeActivityFilter.onchain => context.tr.activityFilterOnchain,
    HomeActivityFilter.lightning => context.tr.activityFilterLightning,
    HomeActivityFilter.cold => context.tr.activityFilterCold,
    HomeActivityFilter.pending => context.tr.activityFilterInProgress,
    HomeActivityFilter.failed => context.tr.activityFilterProblems,
    HomeActivityFilter.cancelled =>
      context.tr.financialStatementFilterCancelled,
    HomeActivityFilter.archived => context.tr.financialStatementFilterArchived,
  };
}

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAction;

  /// Text action (e.g. “Veja seu extrato”); when null, falls back to icon.
  final String? actionLabel;
  final IconData actionIcon;
  final String? actionTooltip;

  /// Trailing chevron after [actionLabel] (→ at end of the phrase).
  final bool actionTrailingChevron;

  const HomeSectionHeader({
    required this.title,
    required this.onAction,
    this.actionLabel,
    this.actionIcon = KeroseneIcons.history,
    this.actionTooltip,
    this.actionTrailingChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltip = actionTooltip ?? context.tr.statementScreenTitle;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.newsreader(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: HomeTypography.sectionTitleSize,
              fontWeight: FontWeight.w200,
              letterSpacing: 0,
              height: 1.15,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: HomeTypography.bodySize,
                letterSpacing: 0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                if (actionTrailingChevron) ...[
                  SizedBox(width: homeSize(2)),
                  Icon(
                    KeroseneIcons.chevronRight,
                    size: homeSize(16),
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ],
              ],
            ),
          )
        else
          IconButton(
            onPressed: onAction,
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              actionIcon,
              color: Theme.of(context).colorScheme.onSurface,
              size: homeSize(22),
            ),
          ),
      ],
    );
  }
}

/// CTA under Atividades: “Veja seu extrato” + chevron.
String homeSeeYourStatementLabel(BuildContext context) {
  return _distributionCopy(
    context,
    pt: 'Veja seu extrato',
    en: 'See your statement',
    es: 'Vea su extracto',
  );
}
