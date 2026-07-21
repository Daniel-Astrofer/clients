import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/hub/movement_hub_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_sheet.dart';

const Duration _receiveWalletToHubDuration = Duration(milliseconds: 520);
const Curve _receiveWalletToHubCurve = Curves.easeInOutCubic;

/// Bottom sheet wallet picker → expand animation → receive method hub.
/// Back on the hub reverses to the wallet sheet (not the amount screen).
Future<void> pushReceiveWalletToHub({
  required BuildContext context,
  required List<Wallet> wallets,
  required double amountBtc,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    enableDrag: true,
    isDismissible: true,
    builder: (context) {
      return _ReceiveWalletToHubSheet(
        wallets: wallets,
        amountBtc: amountBtc,
      );
    },
  );
}

class _ReceiveWalletToHubSheet extends StatefulWidget {
  final List<Wallet> wallets;
  final double amountBtc;

  const _ReceiveWalletToHubSheet({
    required this.wallets,
    required this.amountBtc,
  });

  @override
  State<_ReceiveWalletToHubSheet> createState() =>
      _ReceiveWalletToHubSheetState();
}

class _ReceiveWalletToHubSheetState extends State<_ReceiveWalletToHubSheet>
    with SingleTickerProviderStateMixin {
  Wallet? _selectedWallet;
  late final AnimationController _transitionController;
  late final Animation<double> _expand;
  late final Animation<double> _sheetFade;
  late final Animation<Offset> _hubSlide;
  late final Animation<double> _hubFade;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: _receiveWalletToHubDuration,
    );
    _expand = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0, 0.88, curve: _receiveWalletToHubCurve),
    );
    _sheetFade = CurvedAnimation(
      parent: _transitionController,
      curve: const Interval(0, 0.34, curve: Curves.easeIn),
    );
    _hubSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.08, 1, curve: _receiveWalletToHubCurve),
      ),
    );
    _hubFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: const Interval(0.26, 0.92, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  double _contentHeight(BuildContext context) {
    return ReceiveFlowLayout.walletSheetHeight(context, widget.wallets.length);
  }

  Future<void> _onWalletSelected(Wallet wallet) async {
    if (_selectedWallet != null || _transitionController.isAnimating) return;
    HapticFeedback.mediumImpact();
    setState(() => _selectedWallet = wallet);
    await _transitionController.forward();
  }

  Future<void> _onHubBack() async {
    if (_transitionController.isAnimating) return;
    await _transitionController.reverse();
    if (mounted) {
      setState(() => _selectedWallet = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final contentHeight = _contentHeight(context);

    return PopScope(
      canPop: _selectedWallet == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _selectedWallet == null) return;
        _onHubBack();
      },
      child: AnimatedBuilder(
        animation: _transitionController,
        builder: (context, _) {
          final expand = _selectedWallet == null ? 0.0 : _expand.value;
          final sheetHeight =
              contentHeight + (screenHeight - contentHeight) * expand;
          final sheetOpacity =
              _selectedWallet == null ? 1.0 : (1 - _sheetFade.value);

          return SizedBox(
            height: sheetHeight,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KeroseneBrandTokens.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ReceiveFlowLayout.sheetBorderRadius),
                ),
                border: Border(
                  top: BorderSide(
                    color: ReceiveFlowLayout.sheetBorderColor,
                    width: ReceiveFlowLayout.sheetBorderWidth,
                  ),
                  left: BorderSide(
                    color: ReceiveFlowLayout.sheetBorderColor,
                    width: ReceiveFlowLayout.sheetBorderWidth,
                  ),
                  right: BorderSide(
                    color: ReceiveFlowLayout.sheetBorderColor,
                    width: ReceiveFlowLayout.sheetBorderWidth,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ReceiveFlowLayout.sheetBorderRadius),
                ),
                child: ColoredBox(
                  color: KeroseneBrandTokens.background,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (_selectedWallet != null)
                        Positioned.fill(
                          child: SlideTransition(
                            position: _hubSlide,
                            child: FadeTransition(
                              opacity: _hubFade,
                              child: MovementHubScreen(
                                wallet: _selectedWallet,
                                amountBtc: widget.amountBtc,
                                onBack: _onHubBack,
                              ),
                            ),
                          ),
                        ),
                      if (_selectedWallet == null || sheetOpacity > 0.02)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            ignoring: _selectedWallet != null && expand > 0.2,
                            child: Opacity(
                              opacity: sheetOpacity.clamp(0, 1),
                              child: ReceiveWalletPickerPanel(
                                wallets: widget.wallets,
                                selectedWallet: _selectedWallet,
                                onWalletSelected: _onWalletSelected,
                                shrinkWrap: true,
                              ),
                            ),
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
    );
  }
}
