import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
// architecture-allow-large-file: movement rail selection and navigation keep
// their existing provider and platform-channel contracts together.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
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

import 'receive_gateway_providers_screen.dart';

export 'receive_gateway_providers_screen.dart';
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

class MovementHubScreen extends ConsumerStatefulWidget {
  final Wallet? initialWallet;
  final Wallet? wallet;
  final double? amountBtc;
  final MovementMoney? money;
  final VoidCallback? onBack;

  /// True only when hosted inside the wallet→hub expand sheet.
  final bool embeddedInSheet;

  const MovementHubScreen({
    super.key,
    this.initialWallet,
    this.wallet,
    this.amountBtc,
    this.money,
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
              money: widget.money,
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
    final requestOwner = ref.read(sessionStorageScopeProvider)?.trim();
    await Navigator.of(context).push<void>(
      _flowRoute(
        (_) => ReceiveRequestFlowScreen(
          ownerScope: requestOwner,
          money: widget.money,
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
    return Material(
      color: _receiveBackground,
      child: AnimatedSwitcher(
        duration: KeroseneMotion.duration(context, KeroseneMotion.medium),
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
                      child: KeroseneIcon(icon,
                          color: _receiveTextColor, size: 22),
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
              KeroseneIcon(
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
