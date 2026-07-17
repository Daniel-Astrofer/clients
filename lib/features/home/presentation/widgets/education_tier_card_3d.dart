import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/widgets/wallet_card_appearance.dart';
import 'package:kerosene/features/home/domain/entities/home_feed_item.dart';

/// Maps education feed items to the real platform card tier (not mock PNGs).
WalletCardType? educationTierFromFeedItem(HomeFeedItem item) {
  final tag = item.tag.trim().toUpperCase();
  final id = item.id.toLowerCase();
  final campaign = (item.campaignId ?? '').toLowerCase();
  if (tag == 'BRONZE' ||
      id.contains('bronze') ||
      campaign.contains('bronze')) {
    return WalletCardType.bronze;
  }
  if (tag == 'WHITE' ||
      tag == 'METAL' ||
      tag == 'SILVER' ||
      id.contains('white') ||
      id.contains('metal') ||
      campaign.contains('white') ||
      campaign.contains('metal')) {
    return WalletCardType.white;
  }
  if (tag == 'BLACK' ||
      tag == 'GOLD' ||
      id.contains('black') ||
      id.contains('gold') ||
      campaign.contains('black') ||
      campaign.contains('gold')) {
    return WalletCardType.black;
  }
  return null;
}

bool isEducationTierFeedItem(HomeFeedItem item) =>
    educationTierFromFeedItem(item) != null;

/// Compact credit-card face with subtle 3D tilt — same palettes as live wallets.
/// Replaces mock PNG thumbs in the home education carousel.
///
/// Static transform only — a continuous tilt ticker was killing home scroll FPS.
class EducationTierCard3D extends StatelessWidget {
  final WalletCardType tier;
  final double width;
  final double height;

  const EducationTierCard3D({
    super.key,
    required this.tier,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final appearance = WalletCardAppearance.fromCardType(tier);
    // Frozen gentle pose (same resting pose as the old mid-tilt frame).
    const t = 0.35;
    final yaw = (t - 0.5) * 0.22;
    final pitch = math.sin(t * math.pi) * 0.08;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0022)
        ..rotateY(yaw)
        ..rotateX(pitch),
      child: _TierCardFace(
        appearance: appearance,
        width: width,
        height: height,
      ),
    );
  }
}

class _TierCardFace extends StatelessWidget {
  final WalletCardAppearance appearance;
  final double width;
  final double height;

  const _TierCardFace({
    required this.appearance,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = height * 0.12;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // Soft shadow only (no large blurRadius — cheap paint on home scroll).
        boxShadow: [
          BoxShadow(
            color: appearance.cardShadowColor.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: appearance.backgroundGradient,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Soft specular highlight (flat, not chrome-metal shimmer).
            Positioned(
              top: -height * 0.2,
              left: -width * 0.1,
              child: Container(
                width: width * 0.7,
                height: height * 0.55,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      appearance.cardHighlightColor.withValues(alpha: 0.35),
                      appearance.cardHighlightColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.09,
                height * 0.12,
                width * 0.09,
                height * 0.12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'KEROSENE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: appearance.inkSecondary,
                            fontSize: height * 0.11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Icon(
                        KeroseneIcons.contactless,
                        size: height * 0.18,
                        color: appearance.inkPrimary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Mini chip
                  Container(
                    width: width * 0.18,
                    height: height * 0.16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          appearance.cardHighlightColor.withValues(alpha: 0.9),
                          appearance.accentColor.withValues(alpha: 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: appearance.inkPrimary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.08),
                  Text(
                    appearance.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: appearance.inkPrimary,
                      fontSize: height * 0.14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
