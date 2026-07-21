import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/design_system/components/financial/send_flow_chrome.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';

class SendWalletSelectionStep extends StatelessWidget {
  final WalletState walletState;
  final Wallet? selectedWallet;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  final ValueChanged<Wallet> onWalletSelected;
  final ValueChanged<Wallet> onWalletConfirmed;

  final PaymentRail? selectedRail;
  /// When non-null, only these wallet ids (from capabilities) may be offered.
  final Set<String>? eligibleWalletIds;

  const SendWalletSelectionStep({
    super.key,
    required this.walletState,
    required this.selectedWallet,
    required this.onRefresh,
    required this.onBack,
    required this.onWalletSelected,
    required this.onWalletConfirmed,
    this.selectedRail,
    this.eligibleWalletIds,
  });

  static const internalBlack = KeroseneBrandTokens.background;
  static const internalBorder = KeroseneBrandTokens.border;
  static const internalText = KeroseneBrandTokens.textPrimary;
  static const internalMutedText = KeroseneBrandTokens.textMuted;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(child: _buildBody(context)),
        Positioned(
          top: topInset + 12,
          left: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: internalBlack.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(color: internalText.withValues(alpha: 0.10)),
            ),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(KeroseneIcons.back, size: 22),
              tooltip: context.tr.authBackAction,
              style: IconButton.styleFrom(
                foregroundColor: internalText,
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = walletState;
    if (state is WalletLoading || state is WalletInitial) {
      return _WalletLoading(
        onRefresh: onRefresh,
      );
    }
    if (state is WalletError) {
      return _WalletLoadError(message: state.message, onRefresh: onRefresh);
    }
    if (state is WalletLoaded) {
      return _WalletList(
        walletState: state,
        selectedWallet: selectedWallet,
        selectedRail: selectedRail,
        eligibleWalletIds: eligibleWalletIds,
        onWalletSelected: onWalletSelected,
        onWalletConfirmed: onWalletConfirmed,
      );
    }
    return const SizedBox.shrink();
  }
}

class _WalletLoading extends StatefulWidget {
  final VoidCallback onRefresh;

  const _WalletLoading({required this.onRefresh});

  @override
  State<_WalletLoading> createState() => _WalletLoadingState();
}

class _WalletLoadingState extends State<_WalletLoading> {
  static const int _slowLoadSeconds = 12;
  late Timer _timer;
  int _elapsedSeconds = 0;

  bool get _isSlow => _elapsedSeconds >= _slowLoadSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() => _elapsedSeconds = 0);
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSlow
        ? SendMoneyCopy.walletLoadSlowTitle(context)
        : SendMoneyCopy.walletLoadLoadingTitle(context);
    final body = _isSlow
        ? SendMoneyCopy.walletLoadSlowBody(context)
        : SendMoneyCopy.walletLoadLoadingBody(context, _elapsedSeconds);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * 0.56,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: context.responsive.appColumnConstraints,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(
                  color: SendWalletSelectionStep.internalText,
                  radius: 23,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.newsreader(
                    color: SendWalletSelectionStep.internalText,
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SendWalletSelectionStep.internalMutedText,
                        fontSize: 13,
                        height: 1.45,
                      ),
                ),
                if (_isSlow) ...[
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(KeroseneIcons.refresh, size: 18),
                    label: Text(context.tr.tryAgain),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;

  const _WalletLoadError({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            KeroseneIcons.warning,
            color: SendWalletSelectionStep.internalMutedText,
            size: 34,
          ),
          const SizedBox(height: 16),
          Text(
            SendMoneyCopy.walletLoadFailed(context),
            textAlign: TextAlign.center,
            style: AppTypography.newsreader(
              color: SendWalletSelectionStep.internalText,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ErrorTranslator.translate(context.tr, message),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SendWalletSelectionStep.internalMutedText,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(KeroseneIcons.refresh, size: 18),
            label: Text(context.tr.tryAgain),
          ),
        ],
      ),
    );
  }
}

class _WalletList extends StatefulWidget {
  final WalletLoaded walletState;
  final Wallet? selectedWallet;
  final PaymentRail? selectedRail;
  final Set<String>? eligibleWalletIds;
  final ValueChanged<Wallet> onWalletSelected;
  final ValueChanged<Wallet> onWalletConfirmed;

  const _WalletList({
    required this.walletState,
    required this.selectedWallet,
    required this.selectedRail,
    required this.onWalletSelected,
    required this.onWalletConfirmed,
    this.eligibleWalletIds,
  });

  @override
  State<_WalletList> createState() => _WalletListState();
}

class _WalletListState extends State<_WalletList> with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Find initial selected index
    final walletsList = _orderedCompatible(_getCompatibleWallets());
    int initialIndex = 0;
    if (widget.selectedWallet != null) {
      final index = walletsList.indexWhere((w) => w.id == widget.selectedWallet!.id);
      if (index != -1) initialIndex = index;
    }
    
    _currentIndex = initialIndex;
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: initialIndex,
    );
    
    _staggerController.forward();
  }
  
  bool _isBackendEligible(Wallet wallet) {
    final ids = widget.eligibleWalletIds;
    if (ids == null) return true;
    if (ids.isEmpty) return false;
    return ids.contains(wallet.id) || ids.contains(wallet.name);
  }

  List<Wallet> _getCompatibleWallets() {
    return widget.walletState.wallets.where((w) {
      if (!_isBackendEligible(w)) return false;
      return walletMatchesSendRail(w, widget.selectedRail);
    }).toList();
  }

  List<Wallet> _getIncompatibleWallets() {
    return widget.walletState.wallets.where((w) {
      if (!_isBackendEligible(w)) return true;
      return !walletMatchesSendRail(w, widget.selectedRail);
    }).toList();
  }

  List<Wallet> _orderedCompatible(List<Wallet> walletsList) {
    if (walletsList.length == 3) {
      final insuredIndex = walletsList.indexWhere((w) => w.isInternalCustody);
      if (insuredIndex != -1 && insuredIndex != 1) {
        final insuredWallet = walletsList.removeAt(insuredIndex);
        walletsList.insert(1, insuredWallet);
      }
    }
    return walletsList;
  }

  String _incompatibleReason(BuildContext context, Wallet wallet) {
    final rail = widget.selectedRail;
    if (rail == null) {
      return SendMoneyCopy.walletUnavailableGeneric(context);
    }
    switch (rail) {
      case PaymentRail.internal:
      case PaymentRail.lightning:
      case PaymentRail.paymentLink:
        return SendMoneyCopy.walletUnavailableInstant(context);
      case PaymentRail.onchain:
      case PaymentRail.coldOnchain:
        return SendMoneyCopy.walletUnavailableOnchain(context);
    }
  }

  bool _isRecommendedForRail({
    required Wallet wallet,
    required PaymentRail? rail,
    required List<Wallet> wallets,
  }) {
    if (rail == null) {
      return wallet.isInternalCustody;
    }
    switch (rail) {
      case PaymentRail.internal:
      case PaymentRail.lightning:
      case PaymentRail.paymentLink:
        return wallet.isInternalCustody;
      case PaymentRail.onchain:
      case PaymentRail.coldOnchain:
        return wallet.isCustodialOnchain ||
            wallet.isColdWallet ||
            wallet.isSelfCustody;
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    final walletsList = _orderedCompatible(_getCompatibleWallets());
    final blocked = _getIncompatibleWallets();

    if (walletsList.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SendMoneyCopy.noWalletsForSend(context),
                textAlign: TextAlign.center,
                style: tokens.bodyReading(color: tokens.textMuted),
              ),
              if (blocked.isNotEmpty) ...[
                SizedBox(height: tokens.spaceLg),
                ...blocked.map(
                  (w) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spaceSm),
                    child: Text(
                      '${w.name}: ${_incompatibleReason(context, w)}',
                      textAlign: TextAlign.center,
                      style: AppTypography.inter(
                        color: tokens.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(height: tokens.spaceSection + tokens.spaceXl),
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onWalletSelected(walletsList[index]);
            },
            itemCount: walletsList.length,
            itemBuilder: (context, index) {
              final wallet = walletsList[index];
              final isRecommended = _isRecommendedForRail(
                wallet: wallet,
                rail: widget.selectedRail,
                wallets: walletsList,
              );

              final animation = CurvedAnimation(
                parent: _staggerController,
                curve: Interval(
                  (index * 0.15).clamp(0.0, 1.0),
                  (index * 0.15 + 0.5).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic,
                ),
              );

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
                  } else if (index != _currentIndex) {
                    value = 0.8;
                  }

                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spaceSm,
                        vertical: tokens.spaceMd + 4,
                      ),
                      child: _PremiumWalletCard(
                        wallet: wallet,
                        selected: _currentIndex == index,
                        isRecommended: isRecommended,
                        onTap: () {
                          if (_currentIndex != index) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            widget.onWalletConfirmed(wallet);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (blocked.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceXl,
              tokens.spaceSm,
              tokens.spaceXl,
              0,
            ),
            child: Text(
              SendMoneyCopy.walletBlockedHint(
                context,
                reason: _incompatibleReason(context, blocked.first),
              ),
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                color: tokens.textMuted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        const Spacer(),
        SendFlowThumbDock(
          child: SendFlowPrimaryCta(
            label: SendMoneyCopy.confirmWalletAction(context),
            onPressed: () =>
                widget.onWalletConfirmed(walletsList[_currentIndex]),
          ),
        ),
      ],
    );
  }
}

class _PremiumWalletCard extends StatelessWidget {
  final Wallet wallet;
  final bool selected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _PremiumWalletCard({
    required this.wallet,
    required this.selected,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SendFlowTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: tokens.cardBorderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    tokens.surfaceHigh,
                    tokens.background,
                  ]
                : [
                    tokens.surface,
                    tokens.background,
                  ],
          ),
          border: Border.all(
            color: selected
                ? tokens.textPrimary.withValues(alpha: 0.6)
                : isRecommended
                    ? tokens.feedbackSuccess.withValues(alpha: 0.4)
                    : tokens.textPrimary.withValues(alpha: 0.05),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? tokens.cardShadow
              : const <BoxShadow>[],
        ),
        child: ClipRRect(
          borderRadius: tokens.cardBorderRadius,
          child: Stack(
            children: [
              // Abstract glowing orb
              Positioned(
                top: -40,
                right: -40,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecommended
                        ? tokens.feedbackSuccess
                            .withValues(alpha: selected ? 0.15 : 0.05)
                        : tokens.textPrimary
                            .withValues(alpha: selected ? 0.05 : 0.02),
                    backgroundBlendMode: BlendMode.screen,
                  ),
                ),
              ),
              
              // Bottom left glowing orb
              Positioned(
                bottom: -20,
                left: -20,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: selected ? 0.03 : 0.01),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Icon(
                            wallet.isColdWallet ? KeroseneIcons.lock : KeroseneIcons.wallet,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: KeroseneBrandTokens.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: KeroseneBrandTokens.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: KeroseneBrandTokens.success,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Recomendado', // Recommended
                                  style: AppTypography.newsreader(
                                    color: KeroseneBrandTokens.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Saldo Disponível', // Available Balance
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SendWalletSelectionStep.internalMutedText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${wallet.balance.toStringAsFixed(8)} BTC',
                      style: AppTypography.newsreader(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      wallet.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
