import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/widgets/activity_glyph.dart';

void main() {
  group('ActivityGlyphSpec', () {
    test('lightning outgoing uses rail primary + direction badge', () {
      final axes = const TransactionAxes(
        direction: TxDirection.outgoing,
        rail: TxRail.lightning,
        product: TxProduct.transfer,
        lifecycle: TxLifecycle.pending,
        variant: TxVisualVariant.lightningOut,
      );
      final spec = ActivityGlyphSpec.fromAxes(axes);
      expect(spec.primary, KeroseneIcons.railLightning);
      expect(spec.direction, KeroseneIcons.dirOut);
      expect(spec.productPip, isNull);
    });

    test('onchain incoming uses chain primary + dir in', () {
      final axes = const TransactionAxes(
        direction: TxDirection.incoming,
        rail: TxRail.onchain,
        product: TxProduct.transfer,
        lifecycle: TxLifecycle.confirmed,
        variant: TxVisualVariant.onchainIn,
      );
      final spec = ActivityGlyphSpec.fromAxes(axes);
      expect(spec.primary, KeroseneIcons.railOnchain);
      expect(spec.direction, KeroseneIcons.dirIn);
    });

    test('cancelled lifecycle does not replace rail primary', () {
      final axes = const TransactionAxes(
        direction: TxDirection.outgoing,
        rail: TxRail.lightning,
        product: TxProduct.transfer,
        lifecycle: TxLifecycle.cancelled,
        variant: TxVisualVariant.cancelled,
      );
      final spec = ActivityGlyphSpec.fromAxes(axes);
      expect(spec.primary, KeroseneIcons.railLightning);
      expect(spec.direction, KeroseneIcons.dirOut);
    });

    test('payment link open uses QR primary + receive dir + rail pip', () {
      final link = PaymentLink(
        id: 'pl_1',
        userId: 1,
        amountBtc: 0.001,
        description: 'test',
        depositAddress: 'tb1q',
        status: 'pending',
        paymentRail: 'LIGHTNING',
        paymentRequest: 'lnbc1test',
      );
      final spec = ActivityGlyphSpec.fromPaymentLink(link);
      expect(spec.primary, KeroseneIcons.productPaymentLink);
      expect(spec.productPip, KeroseneIcons.railLightning);
      expect(spec.direction, KeroseneIcons.dirIn);
    });

    test('settled payment-link receive is QR not internal arrows', () {
      final axes = const TransactionAxes(
        direction: TxDirection.incoming,
        rail: TxRail.internal,
        product: TxProduct.paymentLink,
        lifecycle: TxLifecycle.confirmed,
        variant: TxVisualVariant.paymentLinkIn,
      );
      final spec = ActivityGlyphSpec.fromAxes(axes);
      expect(spec.primary, KeroseneIcons.productPaymentLink);
      expect(spec.primary, isNot(KeroseneIcons.railInternal));
      expect(spec.direction, KeroseneIcons.dirIn);
      expect(spec.productPip, KeroseneIcons.railInternal);
    });

    test('fee has no direction badge', () {
      final axes = const TransactionAxes(
        direction: TxDirection.neutral,
        rail: TxRail.internal,
        product: TxProduct.fee,
        lifecycle: TxLifecycle.confirmed,
        variant: TxVisualVariant.fee,
      );
      final spec = ActivityGlyphSpec.fromAxes(axes);
      expect(spec.primary, KeroseneIcons.fee);
      expect(spec.direction, isNull);
    });

    test('iconFor never returns direction-only for rails', () {
      final axes = const TransactionAxes(
        direction: TxDirection.outgoing,
        rail: TxRail.internal,
        product: TxProduct.transfer,
        lifecycle: TxLifecycle.confirmed,
        variant: TxVisualVariant.internalOut,
      );
      // Primary rail, not bare up/down.
      expect(
        ActivityGlyphSpec.fromAxes(axes).primary,
        isNot(KeroseneIcons.up),
      );
      expect(
        ActivityGlyphSpec.fromAxes(axes).primary,
        KeroseneIcons.railInternal,
      );
    });
  });
}
