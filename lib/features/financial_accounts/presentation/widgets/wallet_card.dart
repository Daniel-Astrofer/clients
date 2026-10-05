import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/core/utils/safe_display_text.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';

import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

const _bitcoinGlyph = '₿';
const _bitcoinNetworkLabel = 'BITCOIN';

/// Premium Wallet Card Component - Refactored
class WalletCard extends StatefulWidget {
  final Wallet wallet;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onAddressCopied;
  final int colorIndex;
  final double tilt;
  final Function(String action)? onMenuAction;

  const WalletCard({
    super.key,
    required this.wallet,
    this.isSelected = false,
    this.onTap,
    this.onAddressCopied,
    this.onMenuAction,
    this.colorIndex = 0,
    this.tilt = 0.0,
  });

  @override
  State<WalletCard> createState() => _WalletCardState();

  String _shortAddress(String address) {
    return SafeDisplayText.maskAddress(address);
  }
}

class _WalletCardState extends State<WalletCard> {
  void _showCardMenu(BuildContext context) {
    if (widget.onMenuAction == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Icon(KeroseneIcons.edit,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text(context.tr.walletEditNameAction.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(fontWeight: FontWeight.w900, letterSpacing: 1)),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction?.call('edit');
              },
            ),
            ListTile(
              leading: Icon(KeroseneIcons.trash,
                  color: Theme.of(context).colorScheme.error),
              title: Text(context.tr.removeWallet.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction?.call('delete');
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    final height = width / 1.65;
    final surface = HomeSurfaceTheme.of(context);
    final shineY = widget.tilt * -1.5;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      width: width + 4,
      height: height + 4,
      child: GestureDetector(
        onTap: widget.isSelected ? () => _showCardMenu(context) : widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: surface.card,
                borderRadius:
                    BorderRadius.circular(HomeSurfaceTokens.radiusCard),
                border: Border.all(
                  color: widget.isSelected
                      ? surface.textPrimary.withValues(alpha: 0.62)
                      : surface.panelBorder,
                  width: widget.isSelected ? 1.25 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(HomeSurfaceTokens.radiusCard - 1),
                child: Stack(
                  children: [
                    // A quiet carbon surface keeps wallet selection aligned
                    // with the rest of the OLED financial surfaces.
                    Positioned.fill(
                      child: ColoredBox(color: surface.card),
                    ),

                    Positioned(
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: Icon(KeroseneIcons.lightning,
                          color: surface.textMuted.withValues(alpha: 0.45),
                          size: 32),
                    ),

                    // ── Shine on selection ──
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: KeroseneMotion.fast,
                        opacity: widget.isSelected ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.0),
                                Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.1),
                                Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.0),
                              ],
                              stops: const [0.35, 0.5, 0.65],
                              transform:
                                  GradientTranslation(Offset(0.0, shineY)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Card content ──
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: 4),
                                decoration: BoxDecoration(
                                  color: surface.surfaceDim,
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: surface.surfaceBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_bitcoinGlyph,
                                        style: TextStyle(
                                            color: HomeSurfaceTokens.amber,
                                            fontSize: 18,
                                            fontWeight: AppTypography.w590)),
                                    SizedBox(width: 4),
                                    Text(_bitcoinNetworkLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall!
                                            .copyWith(
                                                fontWeight: AppTypography.w510,
                                                color: surface.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.wallet.name.toUpperCase(),
                                style: AppTypography.h3Small.copyWith(
                                  color: surface.textPrimary,
                                  letterSpacing: -0.2,
                                  fontWeight: AppTypography.w510,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget
                                          ._shortAddress(widget.wallet.address),
                                      style: AppTypography.financial(
                                        fontSize: 12,
                                        color: surface.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Clipboard.setData(ClipboardData(
                                          text: widget.wallet.address));
                                      widget.onAddressCopied?.call();
                                    },
                                    icon: Icon(KeroseneIcons.copy,
                                        size: 14, color: surface.textSecondary),
                                    style: IconButton.styleFrom(
                                      backgroundColor: surface.surfaceDim,
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}

class GradientTranslation extends GradientTransform {
  final Offset offset;
  const GradientTranslation(this.offset);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
        offset.dx * bounds.width, offset.dy * bounds.height, 0.0);
  }
}
