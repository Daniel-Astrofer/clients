import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_wallet_sheet.dart';

const Color _chipBg = Color(0xFF2C2C2E);
const Color _chipFg = Color(0xFFFFFFFF);
const Color _chipMuted = Color(0xFF8E8E93);
const Color _optionBg = Color(0xFF1A1A1A);

/// Single-line wallet chip that expands into a curved wallet list.
///
/// Chevron: right when closed → down when open (¼ turn), driven by the same
/// controller as the list so arrow and panel never desync.
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
  /// Shared open/close progress for list + chevron.
  late final AnimationController _open;
  late final AnimationController _press;
  late final Animation<double> _pressScale;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _arrowTurns;
  double _lastInset = 0;
  bool _busy = false;

  bool get _isOpen =>
      _open.status == AnimationStatus.completed ||
      _open.status == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(
        parent: _press,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
    final openCurve = CurvedAnimation(
      parent: _open,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _sizeFactor = openCurve;
    // 0 → 0.25 turn = chevron_right points down when open.
    _arrowTurns = Tween<double>(begin: 0, end: 0.25).animate(openCurve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    // Collapse when keyboard opens — keeps arrow + list in sync.
    if (inset > 40 && _lastInset <= 40 && _open.value > 0) {
      _open.reverse();
    }
    _lastInset = inset;
  }

  @override
  void dispose() {
    _open.dispose();
    _press.dispose();
    super.dispose();
  }

  Future<void> _playPress() async {
    if (KeroseneMotion.reduceMotion(context)) return;
    await _press.forward(from: 0);
    if (mounted) await _press.reverse();
  }

  Future<void> _toggle() async {
    if (_busy || widget.wallets.isEmpty) return;
    _busy = true;
    HapticFeedback.selectionClick();
    unawaited(_playPress());
    try {
      if (_isOpen) {
        await _open.reverse();
      } else {
        await _open.forward();
      }
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
      if (_open.value > 0) {
        await _open.reverse();
      }
    } finally {
      if (mounted) _busy = false;
    }
  }

  List<Wallet> get _ordered {
    final selected = widget.selectedWallet;
    if (selected == null) return widget.wallets;
    final rest = widget.wallets
        .where((w) => w.id != selected.id)
        .toList(growable: false);
    return [selected, ...rest];
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
    final nameDuration = KeroseneMotion.duration(
      context,
      const Duration(milliseconds: 220),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pressScale,
              child: Material(
                color: _chipBg,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: widget.wallets.isEmpty ? null : _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: _chipFg),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: nameDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final fade = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return FadeTransition(
                                opacity: fade,
                                child: child,
                              );
                            },
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
                        ),
                        const SizedBox(width: 4),
                        RotationTransition(
                          turns: _arrowTurns,
                          child: const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: _chipMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _sizeFactor,
              axis: Axis.vertical,
              alignment: Alignment.topCenter,
              child: widget.wallets.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _ordered.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _WalletOptionRow(
                              wallet: _ordered[i],
                              selected: selected?.id == _ordered[i].id,
                              onTap: () => _select(_ordered[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletOptionRow extends StatefulWidget {
  final Wallet wallet;
  final bool selected;
  final VoidCallback onTap;

  const _WalletOptionRow({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_WalletOptionRow> createState() => _WalletOptionRowState();
}

class _WalletOptionRowState extends State<_WalletOptionRow> {
  bool _pressed = false;

  Future<void> _handleTap() async {
    if (!mounted) return;
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: KeroseneMotion.duration(
        context,
        const Duration(milliseconds: 90),
      ),
      curve: _pressed ? Curves.easeInCubic : Curves.easeOutCubic,
      child: Material(
        color: _optionBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  ReceiveWalletPickerPanel.iconFor(widget.wallet),
                  size: 18,
                  color: _chipFg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.wallet.name.trim().isEmpty
                        ? '—'
                        : widget.wallet.name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.inter(
                      color: _chipFg,
                      fontSize: 14,
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.selected)
                  const Icon(Icons.check, size: 16, color: _chipMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
