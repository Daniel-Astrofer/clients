import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/nfc_payment_request_codec.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/features/movement/application/unified_send_flags.dart';
import 'package:kerosene/features/movement/domain/fee_tier_selection.dart';
import 'package:kerosene/features/movement/domain/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/domain/payment_intent.dart';
import 'package:kerosene/features/movement/domain/payment_intent_parser.dart';
import 'package:kerosene/features/movement/domain/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/domain/payment_security_guards.dart';
import 'package:kerosene/features/movement/flow/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';

/// Automated slice of the PAYMENT_SWISS_ARMY PR8 smoke matrix (no device / no cluster).
void main() {
  const parser = PaymentIntentParser();
  const resolver = PaymentIntentResolver();

  group('PR8 automated smoke matrix', () {
    test('1 @user internal resolves via capabilities', () {
      final intent = parser.parse('@alice_01');
      expect(intent.kind, PaymentDestinationKind.internal);
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: const KfeReceivingCapabilities(
          canReceiveInternal: true,
          canReceiveLightning: false,
          canReceiveOnchain: true,
          preferredRail: 'INTERNAL',
          missingRequirements: [],
          receiverDisplayName: 'Alice',
          internalWalletId: '61a8bb23-e18e-4f32-8414-9844e7300c14',
          onchainReceiveAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
          availableRails: ['INTERNAL', 'ONCHAIN'],
        ),
      );
      expect(resolved.canContinue, isTrue);
      expect(resolved.selectedRail, PaymentRail.internal);
      expect(resolved.alternatives.length, greaterThanOrEqualTo(2));
    });

    test('2 payment link kinds', () {
      final id = 'smoke-link-1';
      for (final raw in [
        QrPaymentParser.encodePaymentLink(id),
        'kerosene:link:$id',
        'https://app.example/pay/$id',
      ]) {
        expect(parser.parse(raw).kind, PaymentDestinationKind.paymentLink);
        expect(parser.parse(raw).paymentLinkId, id);
      }
    });

    test('3 BIP-21 amount lock', () {
      const addr = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
      final uri = QrPaymentParser.encode(address: addr, amountBtc: 0.00025);
      final intent = parser.parse(uri);
      expect(intent.kind, PaymentDestinationKind.onchain);
      expect(intent.hasLockedAmount, isTrue);
      expect(intent.amountBtc, closeTo(0.00025, 1e-12));
    });

    test('4 fee tier changes network fee', () {
      const fee = FeeEstimate(
        fastSatPerByte: 25,
        standardSatPerByte: 10,
        slowSatPerByte: 3,
        estimatedFastBtc: 0.000025,
        estimatedStandardBtc: 0.000010,
        estimatedSlowBtc: 0.000003,
        amountReceived: 0.001,
        totalToSend: 0.00101,
        serverPriced: false,
      );
      final fast =
          FeeTierSelection.fromEstimate(fee, tier: NetworkFeeTier.fast);
      final slow =
          FeeTierSelection.fromEstimate(fee, tier: NetworkFeeTier.slow);
      expect(fast.networkFeeBtc, greaterThan(slow.networkFeeBtc));
    });

    test('6 NFC receive encode → parse id matches QR', () {
      const id = 'nfc-smoke';
      final qr = QrPaymentParser.encodePaymentLink(id);
      final nfc = NfcPaymentRequestCodec.encodeUri(qr);
      final decoded = NfcPaymentRequestCodec.decodeMessage(nfc)!;
      expect(parser.parse(decoded).paymentLinkId, id);
      expect(parser.parse(qr).paymentLinkId, id);
    });

    test('9 cold source selects coldOnchain rail', () {
      final intent =
          parser.parse('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.watchOnly,
      );
      expect(resolved.selectedRail, PaymentRail.coldOnchain);
      expect(resolved.canContinue, isTrue);
    });

    test('11 network mismatch block', () {
      expectedBitcoinNetworkOverride = BitcoinNetworkKind.testnet;
      expect(
        networkMismatchMessage('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
        isNotNull,
      );
    });

    test('12 quote expired blocks isReady', () {
      final expired = SendFeeQuote(
        requestedAmountBtc: 0.001,
        receiverAmountBtc: 0.001,
        platformFeeRate: 0,
        platformFeeBtc: 0,
        networkFeeBtc: 0.00001,
        totalDebitedBtc: 0.00101,
        quoteExpiresAt:
            DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      expect(expired.isQuoteExpired, isTrue);
      expect(expired.isReady, isFalse);
    });

    test('13 self-pay block', () {
      const id = '61a8bb23-e18e-4f32-8414-9844e7300c14';
      final resolved = resolver.resolveLocal(
        intent: parser.parse(id),
        source: SourceCustody.internal,
        sourceWalletId: id,
      );
      expect(
        resolved.blockers.any((b) => b.code == PaymentBlockerCode.selfPay),
        isTrue,
      );
    });

    test('unified_send_v2 defaults on', () {
      expect(kUnifiedSendV2CompileDefault, isTrue);
    });
  });
}
