import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_sheet.dart';

const Color _chipBg = Color(0xFF2C2C2E);
const Color _chipFg = Color(0xFFFFFFFF);
const Color _chipMuted = Color(0xFF8E8E93);
const Color _divider = Color(0xFF3A3A3C);
const double _chipMaxWidth = 160;
const EdgeInsets _rowPad = EdgeInsets.symmetric(horizontal: 7, vertical: 8);

/// Closed pill radius ≈ half of the single-row height (~32 → 16).
/// Never lerp from 999 while height grows (that reads as a circle).
const double _chipCorner = 16;

/// Single-line wallet chip that expands into a **connected** list (same width
/// and row height as the closed chip — not separate floating option cards).
class ReceiveWalletExpandChip extends StatefulWidget {
  final List<Wallet> wallets;
  final Wallet? selectedWallet;
  final ValueChanged<Wallet> onWalletSelected;

  const ReceiveWalletExpandChip({
    super.key,
    required this.wallets,
    required this.selectedWallet,
    required this.onWalletSelected,
  });

  @override
  State<ReceiveWalletExpandChip> createState() =>
      _ReceiveWalletExpandChipState();
}

class _ReceiveWalletExpandChipState extends State<ReceiveWalletExpandChip>
    with TickerProviderStateMixin {
  late final AnimationController _open;
  late final AnimationController _press;
  late final AnimationController _arrow;
  double _lastInset = 0;
  bool _busy = false;

  static const _openSpring = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 18,
  );

  @override
  void initState() {
    super.initState();
    _open = AnimationController.unbounded(vsync: this)..value = 0;
    _press = AnimationController.unbounded(vsync: this)..value = 1;
    _arrow = AnimationController.unbounded(vsync: this)..value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 40 && _lastInset <= 40 && _open.value > 0.02) {
      _springTo(_open, 0);
      _springTo(_arrow, 0);
    }
    _lastInset = inset;
  }

  @override
  void dispose() {
    _open.dispose();
    _press.dispose();
    _arrow.dispose();
    super.dispose();
  }

  void _springTo(
    AnimationController controller,
    double target, {
    double velocity = 0,
    SpringDescription spring = _openSpring,
  }) {
    controller.animateWith(
      SpringSimulation(spring, controller.value, target, velocity),
    );
  }

  Future<void> _playPress() async {
    if (KeroseneMotion.reduceMotion(context)) return;
    _springTo(
      _press,
      0.96,
      velocity: -2,
      spring: const SpringDescription(mass: 1, stiffness: 400, damping: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (!mounted) return;
    _springTo(
      _press,
      1,
      spring: const SpringDescription(mass: 1, stiffness: 280, damping: 14),
    );
  }

  Future<void> _toggle() async {
    if (_busy || widget.wallets.length <= 1) return;
    _busy = true;
    HapticFeedback.selectionClick();
    unawaited(_playPress());
    try {
      final opening = _open.value < 0.5;
      _springTo(_open, opening ? 1 : 0, velocity: opening ? 2 : -1);
      _springTo(_arrow, opening ? 0.25 : 0);
    } finally {
      if (mounted) _busy = false;
    }
  }

  Future<void> _select(Wallet wallet) async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.selectionClick();
    widget.onWalletSelected(wallet);
    try {
      if (_open.value > 0.02) {
        _springTo(_open, 0, velocity: -1);
        _springTo(_arrow, 0);
      }
    } finally {
      if (mounted) _busy = false;
    }
  }

  List<Wallet> get _others {
    final selected = widget.selectedWallet;
    if (selected == null) return widget.wallets;
    return widget.wallets
        .where((w) => w.id != selected.id)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedWallet;
    final name = (selected?.name.trim().isNotEmpty ?? false)
        ? selected!.name.trim()
        : '—';
    final icon = selected != null
        ? ReceiveWalletPickerPanel.iconFor(selected)
        : Icons.account_balance_wallet_outlined;
    final others = _others;
    final canExpand = others.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _chipMaxWidth),
        child: AnimatedBuilder(
          animation: Listenable.merge([_open, _press, _arrow]),
          builder: (context, _) {
            final openT = _open.value.clamp(0.0, 1.0);
            // Fixed corner from the first frame of expand — no 999→circle morph.
            final radius = BorderRadius.circular(_chipCorner);

            return Transform.scale(
              scale: _press.value,
              child: Material(
                color: _chipBg,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: canExpand ? _toggle : null,
                      borderRadius: radius,
                      child: Padding(
                        padding: _rowPad,
                        child: Row(
                          children: [
                            Icon(icon, size: 14, color: _chipFg),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                name,
                                key: ValueKey<String>(selected?.id ?? name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.inter(
                                  color: _chipFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (canExpand) ...[
                              const SizedBox(width: 4),
                              Transform.rotate(
                                angle: _arrow.value * 2 * math.pi,
                                child: const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: _chipMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: openT,
                        child: others.isEmpty
                            ? const SizedBox.shrink()
                            : Opacity(
                                opacity: openT.clamp(0.0, 1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final wallet in others) ...[
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: _divider,
                                      ),
                                      _WalletConnectedRow(
                                        wallet: wallet,
                                        onTap: () => _select(wallet),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WalletConnectedRow extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onTap;

  const _WalletConnectedRow({
    required this.wallet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = wallet.name.trim().isEmpty ? '—' : wallet.name.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: _rowPad,
        child: Row(
          children: [
            Icon(
              ReceiveWalletPickerPanel.iconFor(wallet),
              size: 14,
              color: _chipFg,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.inter(
                  color: _chipFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
