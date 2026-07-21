import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/data/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/data/fee_tier_selection.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

void main() {
  const fee = FeeEstimate(
    fastSatPerByte: 30,
    standardSatPerByte: 12,
    slowSatPerByte: 4,
    estimatedFastBtc: 0.00003000,
    estimatedStandardBtc: 0.00001200,
    estimatedSlowBtc: 0.00000400,
    amountReceived: 0.001,
    totalToSend: 0.001012,
    keroseneFeeBtc: 0,
    totalFeeBtc: 0.000012,
    estimatedVbytes: 140,
    estimatedConfirmationBlocks: 3,
    fastEstimatedSeconds: 600,
    standardEstimatedSeconds: 1800,
    slowEstimatedSeconds: 3600,
    quoteExpiresAt: null,
    serverPriced: false,
  );

  group('FeeTierSelection', () {
    test('picks fast tier values', () {
      final pick =
          FeeTierSelection.fromEstimate(fee, tier: NetworkFeeTier.fast);
      expect(pick.networkFeeBtc, 0.00003000);
      expect(pick.feeRateSatPerByte, 30);
      expect(pick.estimatedSettlementSeconds, 600);
    });

    test('picks standard tier values', () {
      final pick =
          FeeTierSelection.fromEstimate(fee, tier: NetworkFeeTier.standard);
      expect(pick.networkFeeBtc, 0.00001200);
      expect(pick.feeRateSatPerByte, 12);
      expect(pick.estimatedSettlementSeconds, 1800);
    });

    test('picks slow tier values', () {
      final pick =
          FeeTierSelection.fromEstimate(fee, tier: NetworkFeeTier.slow);
      expect(pick.networkFeeBtc, 0.00000400);
      expect(pick.feeRateSatPerByte, 4);
      expect(pick.estimatedSettlementSeconds, 3600);
    });

    test('SendFeeQuote expires correctly', () {
      final expired = SendFeeQuote(
        requestedAmountBtc: 0.001,
        receiverAmountBtc: 0.001,
        platformFeeRate: 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0.00001,
        totalDebitedBtc: 0.00101,
        quoteExpiresAt:
            DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
      );
      expect(expired.isQuoteExpired, isTrue);
      expect(expired.isReady, isFalse);

      final fresh = SendFeeQuote(
        requestedAmountBtc: 0.001,
        receiverAmountBtc: 0.001,
        platformFeeRate: 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0.00001,
        totalDebitedBtc: 0.00101,
        quoteExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 2)),
      );
      expect(fresh.isQuoteExpired, isFalse);
      expect(fresh.isReady, isTrue);
    });

    test('lightning unknown certainty is not treated as known onchain fee', () {
      const quote = SendFeeQuote(
        requestedAmountBtc: 0.001,
        receiverAmountBtc: 0.001,
        platformFeeRate: 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: 0.001,
        networkFeeCertainty: NetworkFeeCertainty.unknownUntilPay,
      );
      expect(quote.isReadyForOnchainSubmit, isFalse);
      expect(quote.isReady, isTrue);
    });
  });
}
