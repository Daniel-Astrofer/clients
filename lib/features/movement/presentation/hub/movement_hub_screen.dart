import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/navigation/app_page_transitions.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_flow_coordinator.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_registry.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show walletProvider;
import 'package:kerosene/features/movement/presentation/shared/movement_amount_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_availability_provider.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_title_bar.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_flow_screen.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import '../activity/statement_screen.dart';

export '../activity/statement_screen.dart';

Future<void> openTransactionStatement(
  BuildContext context, {
  required GlobalKey originKey,
  String? initialTransactionId,
}) {
  final navigator = Navigator.of(context);
  final overlayObject = navigator.overlay?.context.findRenderObject();
  final overlayBox = overlayObject is RenderBox ? overlayObject : null;
  final originRect = _originRectForKey(originKey, overlayBox) ??
      _fallbackOriginRect(MediaQuery.sizeOf(context));

  return navigator.push<void>(
    _transactionStatementRoute(
      originRect: originRect,
      initialTransactionId: initialTransactionId,
    ),
  );
}

Rect? _originRectForKey(GlobalKey key, RenderBox? overlayBox) {
  if (overlayBox == null) return null;
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlayBox);
  return topLeft & renderObject.size;
}

Rect _fallbackOriginRect(Size size) {
  return Rect.fromLTWH(size.width / 2 - 28, size.height - 120, 56, 56);
}

Route<void> _transactionStatementRoute({
  required Rect originRect,
  String? initialTransactionId,
}) {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: KeroseneMotion.long,
    reverseTransitionDuration: KeroseneMotion.medium,
    pageBuilder: (context, animation, secondaryAnimation) {
      return TransactionStatementScreen(
        initialTransactionId: initialTransactionId,
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      final curved = CurvedAnimation(
        parent: animation,
        curve: KeroseneMotion.standard,
        reverseCurve: KeroseneMotion.exit,
      );
      if (reduceMotion) {
        return FadeTransition(opacity: curved, child: child);
      }

      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final center = Offset(originRect.center.dx, originRect.bottom);
          final startRadius = math.max(originRect.width, originRect.height) / 2;
          final endRadius = _distanceToFarthestCorner(center, size);
          final radius = startRadius + (endRadius - startRadius) * curved.value;
          final opacity = const Interval(
            0.10,
            0.78,
            curve: KeroseneMotion.standard,
          ).transform(curved.value);

          return ClipPath(
            clipper: _CircularRevealClipper(center: center, radius: radius),
            child: Opacity(opacity: opacity, child: child),
          );
        },
      );
    },
  );
}

double _distanceToFarthestCorner(Offset center, Size size) {
  return [
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ].map((corner) => (corner - center).distance).reduce(math.max);
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

Color get _receiveBackground => KeroseneBrandTokens.background;
Color get _receiveSurfaceHigh => ThemeTokenBridge.isLight
    ? KeroseneBrandTheme.light.surface
    : KeroseneBrandTheme.dark.surface;
Color get _receiveTextColor => KeroseneBrandTokens.textPrimary;
Color get _receiveMutedTextColor => KeroseneBrandTokens.textMuted;
Color get _receiveSubtleTextColor => KeroseneBrandTokens.textMuted;

// Gateway providers screen palette aliases.

class MovementHubScreen extends ConsumerStatefulWidget {
  final Wallet? initialWallet;
  final Wallet? wallet;
  final double? amountBtc;
  final VoidCallback? onBack;

  /// True only when hosted inside the wallet→hub expand sheet.
  final bool embeddedInSheet;

  const MovementHubScreen({
    super.key,
    this.initialWallet,
    this.wallet,
    this.amountBtc,
    this.onBack,
    this.embeddedInSheet = false,
  });

  @override
  ConsumerState<MovementHubScreen> createState() => _MovementHubScreenState();
}

class _MovementHubScreenState extends ConsumerState<MovementHubScreen> {
  Route<T> _flowRoute<T>(WidgetBuilder builder) {
    return keroseneHorizontalRoute<T>(builder: builder);
  }

  bool get _amountFirstFlow =>
      widget.wallet != null && (widget.amountBtc ?? 0) > 0;

  void _openReceive(ReceiveAmountMethod method) {
    final wallet = _resolveWallet(ref.read(walletProvider));
    if (wallet == null) {
      _showWalletRequiredNotice();
      return;
    }

    final nfcCompatible =
        ref.read(receiveNfcCompatibilityProvider).asData?.value ?? true;
    if (method == ReceiveAmountMethod.nfc && !nfcCompatible) {
      return;
    }

    ref.read(movementFlowCoordinatorProvider.notifier).configureReceive(
          wallet: wallet,
          method: method,
          nfcCompatible: nfcCompatible,
        );
    HapticFeedback.lightImpact();

    if (_amountFirstFlow) {
      _openReceiveAfterAmount(method: method, wallet: wallet);
      return;
    }

    Navigator.of(context).push<void>(
      _flowRoute(
        (_) => MovementAmountScreen(
          wallet: wallet,
          method: method,
          onChainWallet: isReceiveOnChainWallet(wallet),
        ),
      ),
    );
  }

  Future<void> _openReceiveAfterAmount({
    required ReceiveAmountMethod method,
    required Wallet wallet,
  }) async {
    final amountBtc = widget.amountBtc!;
    final onChainWallet = isReceiveOnChainWallet(wallet);

    if (method == ReceiveAmountMethod.nfc) {
      try {
        final paymentLink =
            await ref.read(transactionRepositoryProvider).createPaymentLink(
          amount: amountBtc,
          description: ReceiveMoneyCopy.paymentLinkDescription(
            context,
            wallet.name,
          ),
          expiresInMinutes: 15,
          visibility: 'PRIVATE',
          confirmationMode: 'USER_ACTION_REQUIRED',
          amountLocked: true,
          referenceLabel: wallet.name,
          metadata: {
            'walletId': wallet.id,
            'walletName': wallet.name,
            'rail': onChainWallet ? 'ONCHAIN' : 'INTERNAL',
            'method': method.name,
            'source': 'receive_flow',
          },
        );
        if (!mounted) return;
        if (paymentLink.id.trim().isEmpty) {
          SnackbarHelper.showError(ReceiveMoneyCopy.nfcIdMissing(context));
          return;
        }
        await Navigator.of(context).push<void>(
          _flowRoute(
            (_) => ReceiveNfcFlowScreen(
              wallet: wallet,
              onChainWallet: onChainWallet,
              amountBtc: amountBtc,
              paymentRequestUri:
                  QrPaymentParser.encodePaymentLink(paymentLink.id),
              paymentRail: paymentLink.paymentRail,
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        SnackbarHelper.showError(error.toString());
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      _flowRoute(
        (_) => ReceiveRequestFlowScreen(
          wallet: wallet,
          method: method,
          onChainWallet: onChainWallet,
          amountBtc: amountBtc,
          paymentLinkExpiresInMinutes: 15,
          deferNetworkUntilChosen: onChainWallet || wallet.isColdWallet,
        ),
      ),
    );
  }

  void _openGatewayProviders() {
    final wallet = _resolveWallet(ref.read(walletProvider));
    if (wallet == null) {
      _showWalletRequiredNotice();
      return;
    }

    HapticFeedback.lightImpact();
    Navigator.of(context).push<void>(
      _flowRoute((_) => ReceiveGatewayProvidersScreen(wallet: wallet)),
    );
  }

  void _showWalletRequiredNotice() {
    HapticFeedback.selectionClick();
    SnackbarHelper.showInfo(context.tr.receiveHubNoWalletMessage);
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final selectedWallet = _resolveWallet(walletState);
    final nfcCompatibility = ref.watch(receiveNfcCompatibilityProvider);
    final canShowNfc = nfcCompatibility.asData?.value ?? true;

    final isWalletLoading = widget.wallet == null &&
        widget.initialWallet == null &&
        (walletState is WalletInitial || walletState is WalletLoading);

    final methodSelection = _buildMethodSelection(
      selectedWallet,
      canShowNfc: canShowNfc,
      isLoading: isWalletLoading,
    );

    // One shell for amount-first and legacy — status pad + lead + centered body.
    return ColoredBox(
      color: _receiveBackground,
      child: AnimatedSwitcher(
        duration: KeroseneMotion.medium,
        switchInCurve: KeroseneMotion.standard,
        switchOutCurve: KeroseneMotion.exit,
        child: methodSelection,
      ),
    );
  }

  Widget _buildMethodSelection(
    Wallet? wallet, {
    required bool canShowNfc,
    bool isLoading = false,
  }) {
    final kind = wallet == null
        ? MovementReceiveWalletKind.internal
        : classifyReceiveWallet(wallet);
    final providers = ref.watch(movementEntryProvidersRegistry);
    final caps = MovementCapability(wallet: wallet, nfcAvailable: canShowNfc);
    final actions =
        providers.expand((p) => p.entriesFor(context, wallet, caps)).toList();
    final showNfcOption = actions.any(
      (action) => action.id == 'nfc',
    );
    final receiveMethodLabel = ReceiveMoneyCopy.hubTitle(context);
    final subtitle = ReceiveMoneyCopy.hubSubtitle(
      context,
      isInternal: kind == MovementReceiveWalletKind.internal,
      isCold: kind == MovementReceiveWalletKind.coldWallet,
      showNfc: showNfcOption,
    );
    final onBack = widget.onBack ?? () => Navigator.maybePop(context);
    return KeyedSubtree(
      key: ValueKey('receive-method-${wallet?.id ?? kind.name}'),
      child: ReceiveFlowScreenShell(
        onBack: onBack,
        title: receiveMethodLabel,
        subtitle: subtitle,
        embeddedInSheet: widget.embeddedInSheet,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiveFlowLayout.pageHorizontal,
            0,
            ReceiveFlowLayout.pageHorizontal,
            ReceiveFlowLayout.pageBottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: _ReceiveActionList(
                      children: [
                        for (var index = 0; index < actions.length; index++)
                          _actionTileFor(
                            context,
                            actions[index],
                            showDivider: index < actions.length - 1,
                            isLoading: isLoading,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  _ReceiveActionTile _actionTileFor(
    BuildContext context,
    MovementEntry entry, {
    required bool showDivider,
    bool isLoading = false,
  }) {
    return _ReceiveActionTile(
      icon: entry.icon ?? KeroseneIcons.qr,
      title: entry.title,
      subtitle: entry.subtitle,
      onTap: isLoading
          ? () {}
          : () {
              if (entry.id == 'gateway') {
                _openGatewayProviders();
              } else if (entry.extraArgs is ReceiveAmountMethod) {
                _openReceive(entry.extraArgs as ReceiveAmountMethod);
              }
            },
      showDivider: showDivider,
      verticalPadding: 24,
      isLoading: isLoading,
    );
  }

  Wallet? _resolveWallet(WalletState walletState) {
    if (widget.wallet != null) {
      return widget.wallet!;
    }
    if (widget.initialWallet != null) {
      return widget.initialWallet!;
    }
    if (walletState is! WalletLoaded) {
      return null;
    }
    for (final wallet in walletState.wallets) {
      if (wallet.isActive) {
        return wallet;
      }
    }
    return walletState.wallets.isNotEmpty ? walletState.wallets.first : null;
  }
}

class _ReceiveActionList extends StatelessWidget {
  final List<_ReceiveActionTile> children;

  const _ReceiveActionList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _ReceiveActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  final double verticalPadding;
  final bool isLoading;

  const _ReceiveActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
    this.verticalPadding = 20,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: ink.withValues(alpha: 0.06),
        highlightColor: ink.withValues(alpha: 0.04),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: ink.withValues(alpha: 0.08),
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _receiveTextColor,
                        ),
                      ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _receiveSurfaceHigh,
                      ),
                      child: Icon(icon, color: _receiveTextColor, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        color: _receiveTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionLarge.copyWith(
                        color: _receiveMutedTextColor,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                KeroseneIcons.chevronRight,
                color: _receiveMutedTextColor.withValues(alpha: 0.76),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiveGatewayProvidersScreen extends ConsumerWidget {
  final Wallet wallet;

  const ReceiveGatewayProvidersScreen({
    super.key,
    required this.wallet,
  });

  List<_GatewayProviderSection> _providerSections(BuildContext context) {
    final tr = context.tr;
    return [
      _GatewayProviderSection(
        title: tr.receiveGatewayRecommendedBrazil,
        providers: [
          _GatewayProvider(
            name: 'MoonPay',
            methods: tr.receiveGatewayMoonPayMethods,
            fees: tr.receiveGatewayMoonPayFees,
            icon: KeroseneIcons.creditCard,
            aliases: const ['moonpay'],
          ),
          _GatewayProvider(
            name: 'Banxa',
            methods: tr.receiveGatewayBanxaMethods,
            fees: tr.receiveGatewayBanxaFees,
            icon: KeroseneIcons.fiat,
            aliases: const ['banxa'],
          ),
          _GatewayProvider(
            name: 'Mercuryo',
            methods: tr.receiveGatewayMercuryoMethods,
            fees: tr.receiveGatewayMercuryoFees,
            icon: KeroseneIcons.device,
            aliases: const ['mercuryo'],
          ),
          _GatewayProvider(
            name: 'Ramp Network',
            methods: tr.receiveGatewayRampMethods,
            fees: tr.receiveGatewayRampFees,
            icon: KeroseneIcons.trendUp,
            aliases: const ['ramp', 'ramp_network', 'rampnetwork'],
          ),
        ],
      ),
      _GatewayProviderSection(
        title: tr.receiveGatewayInstitutional,
        providers: [
          _GatewayProvider(
            name: 'Stripe Crypto Onramp',
            methods: tr.receiveGatewayStripeMethods,
            fees: tr.receiveGatewayStripeFees,
            icon: KeroseneIcons.business,
            badge: tr.receiveGatewayInstitutionalBadge,
            aliases: const [
              'stripe',
              'stripe_crypto_onramp',
              'stripe_onramp',
            ],
          ),
          _GatewayProvider(
            name: 'Coinbase Onramp',
            methods: tr.receiveGatewayCoinbaseMethods,
            fees: tr.receiveGatewayCoinbaseFees,
            icon: KeroseneIcons.database,
            badge: tr.receiveGatewayInstitutionalBadge,
            aliases: const ['coinbase', 'coinbase_onramp'],
          ),
        ],
      ),
      _GatewayProviderSection(
        title: tr.receiveGatewayAggregators,
        providers: [
          _GatewayProvider(
            name: 'Onramper',
            methods: tr.receiveGatewayOnramperMethods,
            fees: tr.receiveGatewayOnramperFees,
            icon: KeroseneIcons.stack,
            aliases: const ['onramper'],
          ),
        ],
      ),
      _GatewayProviderSection(
        title: tr.receiveGatewayOther,
        providers: [
          _GatewayProvider(
            name: 'Transak',
            methods: tr.receiveGatewayTransakMethods,
            fees: tr.receiveGatewayTransakFees,
            icon: KeroseneIcons.internalTransfer,
            aliases: const ['transak'],
          ),
          _GatewayProvider(
            name: 'Wert',
            methods: tr.receiveGatewayWertMethods,
            fees: tr.receiveGatewayWertFees,
            icon: KeroseneIcons.lightning,
            aliases: const ['wert'],
          ),
          _GatewayProvider(
            name: 'GateFi / Unlimit',
            methods: tr.receiveGatewayGateFiMethods,
            fees: tr.receiveGatewayGateFiFees,
            icon: KeroseneIcons.globe,
            aliases: const ['gatefi', 'unlimit', 'gatefi_unlimit'],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(_receiveGatewayProviderUrlsProvider);
    final providers = _providerSections(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ReceiveFlowScreenShell(
        onBack: () => Navigator.of(context).maybePop(),
        title: context.tr.receiveGatewayProvidersTitle,
        subtitle:
            'Third-party links only. Kerosene does not process fiat '
            'or custody onramp funds. Testnet beta — use with care.',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiveFlowLayout.pageHorizontal,
            0,
            ReceiveFlowLayout.pageHorizontal,
            ReceiveFlowLayout.pageBottom,
          ),
          child: urlsAsync.when(
            loading: () => _GatewayProviderList(
              sections: providers,
              urls: const {},
              onSelect: (_) {},
              isLoading: true,
            ),
            error: (_, __) => _GatewayEmptyState(
              message:
                  'Could not load buy options. Try again later, or receive on-chain / Lightning instead.',
              providers: providers,
              onSelectUnavailable: (provider) =>
                  _showProviderUnavailable(context, provider),
            ),
            data: (urls) {
              final hasAny = urls.values.any((v) => v.trim().isNotEmpty);
              if (!hasAny) {
                return _GatewayEmptyState(
                  message:
                      'No buy providers are configured for this environment. '
                      'Receive BTC on-chain or via payment request instead.',
                  providers: providers,
                  onSelectUnavailable: (provider) =>
                      _showProviderUnavailable(context, provider),
                );
              }
              return _GatewayProviderList(
                sections: providers,
                urls: urls,
                onSelect: (provider) => _selectProvider(context, provider, urls),
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectProvider(
    BuildContext context,
    _GatewayProvider provider,
    Map<String, String> urls,
  ) {
    final url = provider.resolveUrl(urls);
    if (url == null || url.isEmpty) {
      _showProviderUnavailable(context, provider);
      return;
    }

    Clipboard.setData(ClipboardData(text: url));
    SnackbarHelper.showSuccess(
      context.tr.receiveGatewayLinkCopied(provider.name, wallet.name),
    );
  }

  void _showProviderUnavailable(
    BuildContext context,
    _GatewayProvider provider,
  ) {
    SnackbarHelper.showInfo(
      context.tr.receiveGatewayProviderUnavailable(provider.name),
    );
  }
}

final _receiveGatewayProviderUrlsProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final result = await ref.read(transactionRepositoryProvider).getOnrampUrls();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (urls) => urls,
  );
});

class _GatewayEmptyState extends StatelessWidget {
  final String message;
  final List<_GatewayProviderSection> providers;
  final ValueChanged<_GatewayProvider> onSelectUnavailable;

  const _GatewayEmptyState({
    required this.message,
    required this.providers,
    required this.onSelectUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KeroseneBrandTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _receiveMutedTextColor,
                    height: 1.4,
                  ),
            ),
          ),
        ),
        Expanded(
          child: _GatewayProviderList(
            sections: providers,
            urls: const {},
            onSelect: onSelectUnavailable,
          ),
        ),
      ],
    );
  }
}

class _GatewayProviderList extends StatelessWidget {
  final List<_GatewayProviderSection> sections;
  final Map<String, String> urls;
  final ValueChanged<_GatewayProvider> onSelect;
  final bool isLoading;

  const _GatewayProviderList({
    required this.sections,
    required this.urls,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 30),
      itemBuilder: (context, sectionIndex) {
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _receiveMutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < section.providers.length; index++) ...[
              if (index > 0) const SizedBox(height: 24),
              _GatewayProviderTile(
                provider: section.providers[index],
                available: isLoading
                    ? true
                    : section.providers[index].resolveUrl(urls) != null,
                onTap: isLoading
                    ? () {}
                    : () => onSelect(section.providers[index]),
                isLoading: isLoading,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GatewayProviderTile extends StatelessWidget {
  final _GatewayProvider provider;
  final bool available;
  final VoidCallback onTap;
  final bool isLoading;

  const _GatewayProviderTile({
    required this.provider,
    required this.available,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _receiveTextColor,
                      ),
                    ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? KeroseneBrandTheme.dark.surface
                          : KeroseneBrandTheme.light.surface,
                    ),
                    child: Icon(
                      provider.icon,
                      color: _receiveMutedTextColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _receiveTextColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    letterSpacing: 0,
                                  ),
                        ),
                      ),
                      if (provider.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _receiveMutedTextColor.withValues(
                                alpha: 0.56,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            provider.badge!,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: _receiveMutedTextColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    provider.methods,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _receiveMutedTextColor,
                          fontSize: 12,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    available
                        ? provider.fees
                        : '${provider.fees} • ${context.tr.receiveGatewayComingSoon}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _receiveSubtleTextColor,
                          fontSize: 12,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              KeroseneIcons.chevronRight,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayProviderSection {
  final String title;
  final List<_GatewayProvider> providers;

  const _GatewayProviderSection({
    required this.title,
    required this.providers,
  });
}

class _GatewayProvider {
  final String name;
  final String methods;
  final String fees;
  final IconData icon;
  final String? badge;
  final List<String> aliases;

  const _GatewayProvider({
    required this.name,
    required this.methods,
    required this.fees,
    required this.icon,
    required this.aliases,
    this.badge,
  });

  String? resolveUrl(Map<String, String> urls) {
    for (final entry in urls.entries) {
      final normalizedKey = _normalize(entry.key);
      for (final alias in aliases) {
        if (normalizedKey == _normalize(alias)) {
          final value = entry.value.trim();
          return value.isEmpty ? null : value;
        }
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
