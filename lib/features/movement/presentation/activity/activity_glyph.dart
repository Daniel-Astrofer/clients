import 'package:kerosene/design_system/foundation/theme/kerosene_ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_palette.dart';

/// Layered activity icon: **rail (primary) + direction badge + optional product pip**.
///
/// Network is always the hero. Direction never stands alone. Status is drawn
/// outside this widget (ring / chip) so cancel/fail never erases the rail.
@immutable
class ActivityGlyphSpec {
  final IconData primary;
  final IconData? direction;
  final bool emphasizeProduct;

  const ActivityGlyphSpec({
    required this.primary,
    this.direction,
    @Deprecated('Removed: only one floating icon allowed') IconData? productPip,
    this.emphasizeProduct = false,
  });

  IconData? get productPip => null;

  /// Settled / in-flight movement from taxonomy axes.
  factory ActivityGlyphSpec.fromAxes(TransactionAxes axes) {
    // Lifecycle never steals the primary product/rail icon (status is external).
    if (axes.product == TxProduct.fee) {
      return const ActivityGlyphSpec(primary: KeroseneIcons.fee);
    }
    if (axes.product == TxProduct.swap) {
      return const ActivityGlyphSpec(primary: KeroseneIcons.swap);
    }

    // Payment link / invoice: QR is the product (not internal ↔ arrows).
    // Only one floating icon is allowed (direction badge).
    if (axes.product == TxProduct.paymentLink) {
      return ActivityGlyphSpec(
        primary: KeroseneIcons.productPaymentLink,
        direction: _directionBadge(axes.direction),
        emphasizeProduct: true,
      );
    }

    final primary = _railPrimary(axes.rail);
    final direction = _directionBadge(axes.direction);

    // Cancelled / failed still keep rail + direction (status is external).
    return ActivityGlyphSpec(
      primary: primary,
      direction: direction,
      emphasizeProduct: false,
    );
  }

  factory ActivityGlyphSpec.fromTransaction(Transaction tx) {
    final axes = TransactionAxes.classify(tx);
    return ActivityGlyphSpec.fromAxes(axes);
  }

  /// Open / unpaid payment request — QR primary, receive direction.
  factory ActivityGlyphSpec.fromPaymentLink(PaymentLink link) {
    return ActivityGlyphSpec(
      primary: KeroseneIcons.productPaymentLink,
      // Open invoice is always a receive request from the merchant side.
      direction: KeroseneIcons.dirIn,
      emphasizeProduct: true,
    );
  }

  static IconData _railPrimary(TxRail rail) {
    return switch (rail) {
      TxRail.lightning => KeroseneIcons.railLightning,
      TxRail.onchain => KeroseneIcons.railOnchain,
      TxRail.internal => KeroseneIcons.railInternal,
      TxRail.cold => KeroseneIcons.railCold,
    };
  }

  static IconData? _directionBadge(TxDirection direction) {
    return switch (direction) {
      TxDirection.incoming => KeroseneIcons.dirIn,
      TxDirection.outgoing => KeroseneIcons.dirOut,
      TxDirection.neutral => null,
    };
  }
}

/// Composed glyph for list / detail activity rows.
class ActivityGlyph extends StatelessWidget {
  final ActivityGlyphSpec spec;
  final double size;
  final Color wellColor;
  final Color wellBorder;
  final Color iconColor;
  final Color badgeWellColor;
  final Color badgeIconColor;
  final Color? pipWellColor;
  final Color? pipIconColor;

  /// When false, only icon layers are drawn (parent supplies the well / ring).
  final bool showWell;

  const ActivityGlyph({
    super.key,
    required this.spec,
    this.size = 42,
    this.wellColor = TransactionPalette.iconWell,
    this.wellBorder = TransactionPalette.iconWellBorder,
    this.iconColor = AppColors.hexFFF2F2F3,
    this.badgeWellColor = Colors.black,
    this.badgeIconColor = AppColors.hexFFF2F2F3,
    this.pipWellColor,
    this.pipIconColor,
    this.showWell = true,
  });

  factory ActivityGlyph.forTransaction(
    Transaction tx, {
    Key? key,
    double size = 42,
    Color? wellColor,
    Color? wellBorder,
    Color? iconColor,
    bool showWell = true,
  }) {
    return ActivityGlyph(
      key: key,
      spec: ActivityGlyphSpec.fromTransaction(tx),
      size: size,
      wellColor: wellColor ?? TransactionPalette.iconWell,
      wellBorder: wellBorder ?? TransactionPalette.iconWellBorder,
      iconColor: iconColor ?? AppColors.hexFFF2F2F3,
      showWell: showWell,
    );
  }

  factory ActivityGlyph.forPaymentLink(
    PaymentLink link, {
    Key? key,
    double size = 42,
  }) {
    return ActivityGlyph(
      key: key,
      spec: ActivityGlyphSpec.fromPaymentLink(link),
      size: size,
    );
  }

  factory ActivityGlyph.forAxes(
    TransactionAxes axes, {
    Key? key,
    double size = 42,
    Color? wellColor,
    Color? wellBorder,
    Color? iconColor,
    bool showWell = true,
  }) {
    return ActivityGlyph(
      key: key,
      spec: ActivityGlyphSpec.fromAxes(axes),
      size: size,
      wellColor: wellColor ?? TransactionPalette.iconWell,
      wellBorder: wellBorder ?? TransactionPalette.iconWellBorder,
      iconColor: iconColor ?? AppColors.hexFFF2F2F3,
      showWell: showWell,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primarySize = size * (showWell ? 0.46 : 0.52);
    // Floating icon increased by 25% (from 0.60 to 0.75; icon from 0.30 to 0.375)
    final badgeSize = size * 0.75;
    final badgeIconSize = size * 0.375;

    return KeroseneUiScale.icon(
        context,
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (showWell)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: wellColor,
                      border: Border.all(color: wellBorder, width: 1),
                    ),
                  ),
                ),
              // Primary — rail (tx) or QR (open payment link).
              Icon(
                spec.primary,
                size: primarySize,
                color: iconColor,
              ),
              // Direction badge — bottom-end (single floating icon).
              // Sits with half of its diameter over the edge of the parent well.
              if (spec.direction != null)
                Positioned(
                  right: -badgeSize / 2,
                  bottom: -badgeSize / 2,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeWellColor,
                      border: Border.all(color: wellBorder, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      spec.direction,
                      size: badgeIconSize,
                      color: badgeIconColor,
                    ),
                  ),
                ),
            ],
          ),
        ));
  }
}
