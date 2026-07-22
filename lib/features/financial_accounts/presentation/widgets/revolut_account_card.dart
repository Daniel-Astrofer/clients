import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_widgets/bottom_sheets.dart';
import '../financial_hub_flow/theme/financial_hub_tokens.dart';

/// Revolut-style account card carousel with tap-to-flip (front ↔ back).
class RevolutAccountCardPager extends StatefulWidget {
  final List<BitcoinAccount> accounts;
  final String userDisplayName;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final ReceivingRequestView? selectedReceiveRequest;

  const RevolutAccountCardPager({
    super.key,
    required this.accounts,
    required this.userDisplayName,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedReceiveRequest,
  });

  @override
  State<RevolutAccountCardPager> createState() =>
      _RevolutAccountCardPagerState();
}

class _RevolutAccountCardPagerState extends State<RevolutAccountCardPager> {
  late final PageController _pageController;
  late int _pageIndex;
  final Set<String> _flippedIds = <String>{};

  static const double _viewportFraction = 0.94;
  static const double _cardAspectRatio = 1.72;
  static const double _flipBreathingRoom = 40.0;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.selectedIndex.clamp(0, _maxIndex);
    _pageController = PageController(
      initialPage: _pageIndex,
      viewportFraction: _viewportFraction,
    );
  }

  int get _maxIndex => widget.accounts.isEmpty ? 0 : widget.accounts.length - 1;

  @override
  void didUpdateWidget(covariant RevolutAccountCardPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accounts.isEmpty) return;

    final next = widget.selectedIndex.clamp(0, _maxIndex);
    if (next != _pageIndex && _pageController.hasClients) {
      _pageIndex = next;
      _pageController.animateToPage(
        next,
        duration: KeroseneMotion.medium,
        curve: KeroseneMotion.standard,
      );
    } else if (next != _pageIndex) {
      _pageIndex = next;
    }

    final liveIds = widget.accounts.map((a) => a.id).toSet();
    _flippedIds.removeWhere((id) => !liveIds.contains(id));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _pageIndex = index;
      _flippedIds.clear();
    });
    widget.onChanged(index);
  }

  void _toggleFlip(BitcoinAccount account) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_flippedIds.contains(account.id)) {
        _flippedIds.remove(account.id);
      } else {
        _flippedIds
          ..clear()
          ..add(account.id);
      }
    });
  }

  double _cardSlotHeight(double maxWidth) {
    final cardWidth = maxWidth * _viewportFraction;
    final cardHeight = cardWidth / _cardAspectRatio;
    return cardHeight + _flipBreathingRoom;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);
    final accounts = widget.accounts;
    if (accounts.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotHeight = _cardSlotHeight(constraints.maxWidth);

        return Column(
          children: [
            SizedBox(
              height: slotHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: accounts.length,
                onPageChanged: _onPageChanged,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isFocused = index == _pageIndex;
                  final receiveRequest = index == widget.selectedIndex
                      ? widget.selectedReceiveRequest
                      : null;

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      var scale = 1.0;
                      var opacity = 1.0;
                      if (_pageController.position.haveDimensions) {
                        final page =
                            _pageController.page ?? _pageIndex.toDouble();
                        final distance = (page - index).abs().clamp(0.0, 1.0);
                        scale = 1.0 - (distance * 0.06);
                        opacity = 1.0 - (distance * 0.28);
                      } else if (!isFocused) {
                        scale = 0.94;
                        opacity = 0.78;
                      }
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(opacity: opacity, child: child),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: _flipBreathingRoom / 2,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: AspectRatio(
                          aspectRatio: _cardAspectRatio,
                          child: _FlippableAccountCard(
                            account: account,
                            userDisplayName: widget.userDisplayName,
                            receiveRequest: receiveRequest,
                            isFlipped: _flippedIds.contains(account.id),
                            isFocused: isFocused,
                            onFlip: () => _toggleFlip(account),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (accounts.length > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < accounts.length; index++)
                    AnimatedContainer(
                      duration: KeroseneMotion.fast,
                      curve: KeroseneMotion.standard,
                      width: index == _pageIndex ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: index == _pageIndex
                            ? colors.text
                            : colors.text.withValues(alpha: 0.18),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _flippedIds.contains(accounts[_pageIndex.clamp(0, _maxIndex)].id)
                  ? 'Toque para voltar'
                  : 'Toque no cartão para ver detalhes',
              style: FinancialHubTokens.caption(
                color: colors.mutedText,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlippableAccountCard extends StatefulWidget {
  final BitcoinAccount account;
  final String userDisplayName;
  final ReceivingRequestView? receiveRequest;
  final bool isFlipped;
  final bool isFocused;
  final VoidCallback onFlip;

  const _FlippableAccountCard({
    required this.account,
    required this.userDisplayName,
    required this.receiveRequest,
    required this.isFlipped,
    required this.isFocused,
    required this.onFlip,
  });

  @override
  State<_FlippableAccountCard> createState() => _FlippableAccountCardState();
}

class _FlippableAccountCardState extends State<_FlippableAccountCard>
    with SingleTickerProviderStateMixin {
  /// Snappy, even acceleration/deceleration — no slow start or hard stop.
  static const Duration _flipDuration = Duration(milliseconds: 280);
  static const Curve _flipCurve = Curves.easeInOutCubic;

  late final AnimationController _controller;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _flipDuration,
      value: widget.isFlipped ? 1.0 : 0.0,
    );
    _flip = CurvedAnimation(
      parent: _controller,
      curve: _flipCurve,
      reverseCurve: _flipCurve,
    );
  }

  @override
  void didUpdateWidget(covariant _FlippableAccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlipped == widget.isFlipped) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.isFlipped ? 1.0 : 0.0;
      return;
    }

    // Interrupt mid-flight cleanly so reverse/forward feels instant on tap.
    if (widget.isFlipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = RevolutCardPalette.forAccount(widget.account);

    return Semantics(
      button: true,
      label: widget.isFlipped
          ? 'Verso do cartão ${widget.account.label}. Toque para voltar.'
          : 'Cartão ${widget.account.label}. Toque para virar.',
      child: GestureDetector(
        onTap: widget.onFlip,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final showBack = angle > (math.pi / 2);

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.0009)
              ..rotateY(showBack ? angle - math.pi : angle);

            return Transform(
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              transform: transform,
              child: showBack
                  ? _CardBack(
                      account: widget.account,
                      palette: palette,
                      isFocused: widget.isFocused,
                    )
                  : _CardFront(
                      account: widget.account,
                      userDisplayName: widget.userDisplayName,
                      receiveRequest: widget.receiveRequest,
                      palette: palette,
                      isFocused: widget.isFocused,
                    ),
            );
          },
        ),
      ),
    );
  }
}

@immutable
class RevolutCardPalette {
  final Color surface;
  final Color surfaceEdge;
  final Color shine;
  final Color ink;
  final Color inkMuted;
  final Color borderTop;
  final Color borderBottom;

  const RevolutCardPalette({
    required this.surface,
    required this.surfaceEdge,
    required this.shine,
    required this.ink,
    required this.inkMuted,
    required this.borderTop,
    required this.borderBottom,
  });

  /// Near-solid metals — tiny edge shift only (no banding / cut lines).
  factory RevolutCardPalette.forAccount(BitcoinAccount account) {
    if (account.isWatchOnly) {
      return const RevolutCardPalette(
        surface: Color(0xFF1A1A1C),
        surfaceEdge: Color(0xFF141416),
        shine: Color(0x14FFFFFF),
        ink: Color(0xFFF2F2F7),
        inkMuted: Color(0xFF8E8E93),
        borderTop: Color(0x4DFFFFFF),
        borderBottom: Color(0xB3000000),
      );
    }
    if (account.isCustodialOnchain) {
      return const RevolutCardPalette(
        surface: Color(0xFF151916),
        surfaceEdge: Color(0xFF101412),
        shine: Color(0x1228C47A),
        ink: Color(0xFFF2F2F7),
        inkMuted: Color(0xFF8E9A93),
        borderTop: Color(0x40FFFFFF),
        borderBottom: Color(0xB3000000),
      );
    }
    return const RevolutCardPalette(
      surface: Color(0xFF161618),
      surfaceEdge: Color(0xFF101012),
      shine: Color(0x12FFFFFF),
      ink: Color(0xFFF5F5F7),
      inkMuted: Color(0xFF8E8E93),
      borderTop: Color(0x52FFFFFF),
      borderBottom: Color(0xCC000000),
    );
  }
}

String custodyFrontLabel(BitcoinAccount account) {
  if (account.isWatchOnly) return 'Carteira Fria';
  if (account.isCustodialOnchain) return 'Carteira onchain';
  return 'Carteira assegurada';
}

class _CardShell extends StatelessWidget {
  final RevolutCardPalette palette;
  final bool isFocused;
  final Widget child;

  const _CardShell({
    required this.palette,
    required this.isFocused,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFocused ? 0.48 : 0.30),
            blurRadius: isFocused ? 20 : 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Single near-solid fill — edge colors are almost the same to
            // avoid visible internal bands/cuts.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.surface,
                    palette.surface,
                    palette.surfaceEdge,
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
            // Soft continuous sheen (very low alpha, no hard edges).
            Positioned(
              top: -48,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.85),
                      radius: 1.35,
                      colors: [
                        palette.shine,
                        palette.shine.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Revolut-like rim: brighter top, darker bottom (stroke only).
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RevolutEdgeBorderPainter(
                    borderTop: palette.borderTop,
                    borderBottom: palette.borderBottom,
                    radius: 18,
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _RevolutEdgeBorderPainter extends CustomPainter {
  final Color borderTop;
  final Color borderBottom;
  final double radius;

  _RevolutEdgeBorderPainter({
    required this.borderTop,
    required this.borderBottom,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2),
      Radius.circular(radius - 0.6),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          borderTop,
          borderTop.withValues(alpha: 0.18),
          borderBottom,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RevolutEdgeBorderPainter oldDelegate) {
    return oldDelegate.borderTop != borderTop ||
        oldDelegate.borderBottom != borderBottom ||
        oldDelegate.radius != radius;
  }
}

class _CardFront extends StatelessWidget {
  final BitcoinAccount account;
  final String userDisplayName;
  final ReceivingRequestView? receiveRequest;
  final RevolutCardPalette palette;
  final bool isFocused;

  const _CardFront({
    required this.account,
    required this.userDisplayName,
    required this.receiveRequest,
    required this.palette,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    final owner =
        userDisplayName.trim().isEmpty ? 'Usuário' : userDisplayName.trim();
    final custody = custodyFrontLabel(account);
    final addressLine = formatOnchainAddressGroups(
      resolveReceiveAddress(account, receiveRequest),
    );
    final balanceLabel = formatSats(bitcoinAccountVisibleBalance(account));
    final balanceCaption = account.isWatchOnly
        ? 'NA REDE'
        : account.isCustodialOnchain
            ? 'DISPONÍVEL'
            : 'DISPONÍVEL';
    final heldLabel = !account.isWatchOnly && account.heldSats > 0
        ? 'Retido: ${formatSats(account.heldSats)}'
        : null;
    final chainLabel = bitcoinAccountChainObservedLabel(account);

    return _CardShell(
      palette: palette,
      isFocused: isFocused,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FinancialHubTokens.titleH2(
                      color: palette.ink,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  custody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FinancialHubTokens.caption(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                addressLine,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.technicalMono(
                  textStyle: TextStyle(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balanceCaption,
                        style: FinancialHubTokens.caption(
                          color: palette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        balanceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FinancialHubTokens.titleH2(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      if (heldLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          heldLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FinancialHubTokens.caption(
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                      if (chainLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          chainLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FinancialHubTokens.caption(
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String resolveReceiveAddress(
  BitcoinAccount account,
  ReceivingRequestView? receiveRequest,
) {
  final fromRequest = receiveRequest?.address.trim() ?? '';
  if (fromRequest.isNotEmpty &&
      !fromRequest.toLowerCase().startsWith('kerosene:')) {
    return fromRequest;
  }
  final identifier = bitcoinAccountCardIdentifier(
    account,
    receiveRequest: receiveRequest,
  ).trim();
  if (identifier.isNotEmpty &&
      !identifier.toLowerCase().startsWith('kerosene:')) {
    return identifier;
  }
  final cardId = (account.cardId ?? '').trim();
  if (cardId.isNotEmpty) return cardId;
  return account.id;
}

String formatOnchainAddressGroups(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[\s\-–—]+'), '')
      .replaceAll(RegExp(r'^bitcoin:', caseSensitive: false), '');
  if (cleaned.isEmpty) return '•••• •••• •••• ••••';

  final buffer = StringBuffer();
  for (var i = 0; i < cleaned.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(cleaned[i]);
  }
  return buffer.toString();
}

/// Minimal back face — stripe + CVV only (no custody/network/address/locks).
class _CardBack extends StatelessWidget {
  final BitcoinAccount account;
  final RevolutCardPalette palette;
  final bool isFocused;

  const _CardBack({
    required this.account,
    required this.palette,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    final code = cardCode(account);

    return _CardShell(
      palette: palette,
      isFocused: isFocused,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Container(
            height: 44,
            color: const Color(0xFF080808),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    kKeroseneBrandLabel,
                    style: FinancialHubTokens.caption(
                      color: palette.inkMuted,
                    ),
                  ),
                ),
                _CvvBadge(code: code),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CvvBadge extends StatelessWidget {
  final String code;

  const _CvvBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'CVV',
            style: FinancialHubTokens.caption(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            code,
            style: AppTypography.technicalMono(
              textStyle: const TextStyle(
                color: AppColors.hexFF111111,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
