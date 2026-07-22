import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/wallet_hold_selection_tile.dart';

class WalletFlowSelector extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final Wallet? initialWallet;
  final ValueChanged<Wallet> onContinue;
  final VoidCallback? onBack;
  final bool showBackButton;

  const WalletFlowSelector({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onContinue,
    this.initialWallet,
    this.onBack,
    this.showBackButton = true,
  });

  @override
  ConsumerState<WalletFlowSelector> createState() => _WalletFlowSelectorState();
}

class _WalletFlowSelectorState extends ConsumerState<WalletFlowSelector> {
  static const Color _background = AppColors.hexFF000000;
  static const Color _text = AppColors.hexFFFFFFFF;
  static const Color _muted = AppColors.hexFFA1A1A1;

  Wallet? _selectedWallet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(walletProvider);
      if (state is WalletInitial || state is WalletError) {
        unawaited(ref.read(walletProvider.notifier).refresh());
      }
    });
  }

  @override
  void didUpdateWidget(covariant WalletFlowSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWallet?.id != widget.initialWallet?.id) {
      _selectedWallet = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(balanceWebSocketServiceProvider);
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(context, walletState)),
          _buildBackButton(context),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    if (!widget.showBackButton) {
      return const SizedBox.shrink();
    }
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Positioned(
      top: topInset + 12,
      left: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _background.withValues(alpha: 0.42),
          shape: BoxShape.circle,
          border: Border.all(color: _text.withValues(alpha: 0.10)),
        ),
        child: IconButton(
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
          icon: const Icon(KeroseneIcons.back, size: 22),
          tooltip: context.tr.authBackAction,
          style: IconButton.styleFrom(
            foregroundColor: _text,
            minimumSize: const Size.square(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WalletState walletState) {
    return switch (walletState) {
      WalletInitial() || WalletLoading() => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(_text),
            ),
          ),
        ),
      WalletError(:final message) => _buildError(context, message),
      WalletLoaded(:final wallets) => wallets.isEmpty
          ? _buildEmpty(context)
          : _buildWalletGrid(context, walletState),
    };
  }

  Widget _buildError(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(KeroseneIcons.warning, color: _muted, size: 34),
          const SizedBox(height: 16),
          Text(
            context.tr.walletSelectorLoadErrorTitle,
            textAlign: TextAlign.center,
            style: AppTypography.newsreader(
              color: _text,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            ErrorTranslator.translate(context.tr, message),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _muted,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
            icon: const Icon(KeroseneIcons.refresh, size: 18),
            label: Text(context.tr.walletSelectorRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          context.tr.walletSelectorNoWallets,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _muted,
                height: 1.45,
              ),
        ),
      ),
    );
  }

  Widget _buildWalletGrid(BuildContext context, WalletLoaded walletState) {
    final wallets = walletState.wallets.toList();
    if (wallets.length == 3) {
      final insuredIndex = wallets.indexWhere((w) => w.isInternalCustody);
      if (insuredIndex != -1 && insuredIndex != 1) {
        final insuredWallet = wallets.removeAt(insuredIndex);
        wallets.insert(1, insuredWallet);
      }
    }
    final selectedWallet = _resolveSelectedWallet(
      walletState.copyWith(wallets: wallets),
    );

    return Semantics(
      label: widget.subtitle,
      container: true,
      child: _buildWalletList(wallets, selectedWallet),
    );
  }

  Widget _buildWalletList(List<Wallet> wallets, Wallet? selectedWallet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final compact = width < 380 || height < 720 || wallets.length >= 3;
        final isSideBySide = wallets.length > 1 && wallets.length <= 3;
        final isSingle = wallets.length <= 1;

        Widget itemBuilder(Wallet wallet,
            {required bool fill, required bool isRow}) {
          final selected = _sameWallet(wallet, selectedWallet);
          final tile = WalletHoldSelectionTile(
            wallet: wallet,
            selected: selected,
            compact: compact,
            onSelect: _select,
            onConfirmed: _continueWith,
          );
          return AnimatedContainer(
            key: ValueKey('wallet-flow-tile-${wallet.id}'),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: isRow ? null : width,
            child: fill ? SizedBox.expand(child: tile) : tile,
          );
        }

        if (isSingle) {
          return SizedBox.expand(
            child: wallets.isEmpty
                ? const SizedBox.shrink()
                : itemBuilder(wallets[0], fill: true, isRow: false),
          );
        }

        if (isSideBySide) {
          return SizedBox.expand(
            child: Row(
              children: [
                for (var index = 0; index < wallets.length; index++) ...[
                  Expanded(
                    flex: _sameWallet(wallets[index], selectedWallet) ? 5 : 4,
                    child: itemBuilder(wallets[index], fill: true, isRow: true),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(0, 84, 0, 28),
          itemCount: wallets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) =>
              itemBuilder(wallets[index], fill: false, isRow: false),
        );
      },
    );
  }

  Wallet? _resolveSelectedWallet(WalletLoaded walletState) {
    final selected = _selectedWallet;
    if (selected != null) {
      final loaded = _findLoadedWallet(walletState.wallets, selected);
      if (loaded != null) return loaded;
    }
    final initial = widget.initialWallet;
    if (initial != null) {
      final loaded = _findLoadedWallet(walletState.wallets, initial);
      if (loaded != null) return loaded;
    }
    final stateSelected = walletState.selectedWallet;
    if (stateSelected != null) {
      final loaded = _findLoadedWallet(walletState.wallets, stateSelected);
      if (loaded != null) return loaded;
    }
    if (walletState.wallets.length == 3) {
      final insured = walletState.wallets.firstWhere((w) => w.isInternalCustody,
          orElse: () => walletState.wallets[1]);
      return insured;
    }
    return walletState.wallets.isNotEmpty ? walletState.wallets.first : null;
  }

  Wallet? _findLoadedWallet(List<Wallet> wallets, Wallet candidate) {
    for (final wallet in wallets) {
      if (_sameWallet(wallet, candidate)) {
        return wallet;
      }
    }
    return null;
  }

  bool _sameWallet(Wallet? left, Wallet? right) {
    if (left == null || right == null) return false;
    return left.id == right.id || left.name == right.name;
  }

  void _select(Wallet wallet) {
    if (_selectedWallet?.id != wallet.id) {
      HapticFeedback.selectionClick();
    }
    setState(() => _selectedWallet = wallet);
  }

  void _continueWith(Wallet wallet) {
    HapticFeedback.mediumImpact();
    ref.read(walletProvider.notifier).selectWallet(wallet);
    widget.onContinue(wallet);
  }
}
