import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/performance/kerosene_graphics_policy.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';

const Color _solidBg = Color(0xFF2C2C2E);
const Color _solidFg = Color(0xFFFFFFFF);
const Color _solidMuted = Color(0xFF8E8E93);
const Color _solidDivider = Color(0xFF3A3A3C);
const double _chipMaxWidth = 160;
const EdgeInsets _rowPad = EdgeInsets.symmetric(horizontal: 7, vertical: 8);

/// Closed pill radius ≈ half of the single-row height (~32 → 16).
const double _chipCorner = 16;

/// Visual treatment for [WalletExpandChip].
///
/// [solid] — default send/receive chrome (unchanged).
/// [glass] — frosted glass for home balance (does not affect other screens).
enum WalletExpandChipAppearance { solid, glass }

/// Icon mapping for wallet kinds shown in the expand chip.
IconData walletExpandChipIcon(Wallet wallet) {
  if (wallet.isColdWallet) return KeroseneIcons.coldWallet;
  if (wallet.isCustodialOnchain) return KeroseneIcons.shield;
  return KeroseneIcons.user;
}

class _ChipPalette {
  const _ChipPalette({
    required this.foreground,
    required this.muted,
    required this.divider,
  });

  final Color foreground;
  final Color muted;
  final Color divider;

  static const solid = _ChipPalette(
    foreground: _solidFg,
    muted: _solidMuted,
    divider: _solidDivider,
  );

  static _ChipPalette glassOf(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _ChipPalette(
      foreground: onSurface,
      muted: onSurface.withValues(alpha: 0.55),
      divider: onSurface.withValues(alpha: 0.14),
    );
  }
}

/// Single-line wallet chip that expands into a connected list (same width /
/// row height as the closed chip). Shared by send + receive amount entry.
class WalletExpandChip extends ConsumerStatefulWidget {
  final List<Wallet> wallets;
  final Wallet? selectedWallet;
  final ValueChanged<Wallet> onWalletSelected;

  /// Defaults to [WalletExpandChipAppearance.solid] so send/receive stay identical.
  final WalletExpandChipAppearance appearance;

  const WalletExpandChip({
    super.key,
    required this.wallets,
    required this.selectedWallet,
    required this.onWalletSelected,
    this.appearance = WalletExpandChipAppearance.solid,
  });

  @override
  ConsumerState<WalletExpandChip> createState() => _WalletExpandChipState();
}

class _WalletExpandChipState extends ConsumerState<WalletExpandChip>
    with TickerProviderStateMixin {
  late final AnimationController _open;
  late final AnimationController _arrow;
  double _lastInset = 0;
  bool _busy = false;

  static const _expandDuration = KeroseneMotion.medium;
  static const _expandCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(vsync: this, duration: _expandDuration);
    _arrow = AnimationController(vsync: this, duration: _expandDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 40 && _lastInset <= 40 && _open.value > 0.02) {
      unawaited(_animateClosed());
    }
    _lastInset = inset;
  }

  @override
  void dispose() {
    _open.dispose();
    _arrow.dispose();
    super.dispose();
  }

  Future<void> _animateOpen(bool opening) {
    final target = opening ? 1.0 : 0.0;
    return Future.wait<void>([
      _open.animateTo(target, curve: _expandCurve),
      _arrow.animateTo(opening ? 0.25 : 0.0, curve: _expandCurve),
    ]);
  }

  Future<void> _animateClosed() => _animateOpen(false);

  Future<void> _toggle() async {
    if (_busy || _others.isEmpty) return;
    _busy = true;
    HapticFeedback.selectionClick();
    try {
      await _animateOpen(_open.value < 0.5);
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
        await _animateClosed();
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
        ? walletExpandChipIcon(selected)
        : Icons.account_balance_wallet_outlined;
    final others = _others;
    final canExpand = others.isNotEmpty;
    final isGlass = widget.appearance == WalletExpandChipAppearance.glass;
    final palette =
        isGlass ? _ChipPalette.glassOf(context) : _ChipPalette.solid;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _chipMaxWidth),
        child: AnimatedBuilder(
          animation: Listenable.merge([_open, _arrow]),
          builder: (context, _) {
            final openT = _open.value.clamp(0.0, 1.0);
            final radius = BorderRadius.circular(_chipCorner);
            final body = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: canExpand ? _toggle : null,
                  borderRadius: radius,
                  child: Padding(
                    padding: _rowPad,
                    child: _WalletChipRow(
                      icon: icon,
                      name: name,
                      nameKey: ValueKey<String>(selected?.id ?? name),
                      palette: palette,
                      trailing: canExpand
                          ? Transform.rotate(
                              angle: _arrow.value * 2 * math.pi,
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: palette.muted,
                              ),
                            )
                          : null,
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
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: palette.divider,
                                  ),
                                  _WalletConnectedRow(
                                    wallet: wallet,
                                    palette: palette,
                                    onTap: () => _select(wallet),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            );

            if (isGlass) {
              final isLight =
                  Theme.of(context).brightness == Brightness.light;
              final onSurface = Theme.of(context).colorScheme.onSurface;
              final policy = ref.watch(graphicsPolicyProvider);
              final useBlur = policy.allowBackdropBlur &&
                  !KeroseneMotion.reduceMotion(context);
              final fillOpacity = useBlur
                  ? (isLight ? 0.55 : 0.14)
                  : (isLight ? 0.60 : 0.19);
              final panel = DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: fillOpacity),
                  borderRadius: radius,
                  border: Border.all(
                    color: onSurface.withValues(alpha: isLight ? 0.12 : 0.22),
                    width: 1,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: body,
                ),
              );

              return ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: useBlur
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: panel,
                      )
                    : panel,
              );
            }

            return Material(
              color: _solidBg,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: body,
            );
          },
        ),
      ),
    );
  }
}

/// Icon left / name centered in the option / optional trailing on the right.
class _WalletChipRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final Key? nameKey;
  final Widget? trailing;
  final _ChipPalette palette;

  const _WalletChipRow({
    required this.icon,
    required this.name,
    required this.palette,
    this.nameKey,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.inter(
      color: palette.foreground,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: AnimatedSwitcher(
            duration: KeroseneMotion.short,
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              name,
              key: nameKey ?? ValueKey<String>(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: label,
            ),
          ),
        ),
        Row(
          children: [
            Icon(icon, size: 14, color: palette.foreground),
            const Spacer(),
            SizedBox(
              width: 16,
              child: trailing == null
                  ? const SizedBox.shrink()
                  : Center(child: trailing),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletConnectedRow extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onTap;
  final _ChipPalette palette;

  const _WalletConnectedRow({
    required this.wallet,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final name = wallet.name.trim().isEmpty ? '—' : wallet.name.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: _rowPad,
        child: _WalletChipRow(
          icon: walletExpandChipIcon(wallet),
          name: name,
          nameKey: ValueKey<String>(wallet.id),
          palette: palette,
        ),
      ),
    );
  }
}

/// Backward-compatible alias while call sites migrate.
@Deprecated('Use WalletExpandChip')
typedef ReceiveWalletExpandChip = WalletExpandChip;
