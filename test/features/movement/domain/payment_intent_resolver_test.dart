import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/movement/domain/payment_intent.dart';
import 'package:kerosene/features/movement/domain/payment_intent_parser.dart';
import 'package:kerosene/features/movement/domain/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/flow/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';

void main() {
  const parser = PaymentIntentParser();
  const resolver = PaymentIntentResolver();

  KfeReceivingCapabilities caps({
    bool internal = true,
    bool onchain = false,
    bool lightning = false,
    String preferred = 'INTERNAL',
    String? walletId = '61a8bb23-e18e-4f32-8414-9844e7300c14',
    String? onchainReceiveAddress,
    String display = 'Alice',
    List<String> missing = const [],
  }) {
    return KfeReceivingCapabilities(
      canReceiveInternal: internal,
      canReceiveLightning: lightning,
      canReceiveOnchain: onchain,
      preferredRail: preferred,
      missingRequirements: missing,
      receiverDisplayName: display,
      internalWalletId: walletId,
      onchainReceiveAddress: onchainReceiveAddress,
      availableRails: [
        if (internal) 'INTERNAL',
        if (onchain) 'ONCHAIN',
        if (lightning) 'LIGHTNING',
      ],
    );
  }

  group('PaymentIntentResolver', () {
    test('on-chain from custodial → onchain rail', () {
      final intent = parser.parse('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.custodialOnchain,
      );
      expect(resolved.selectedRail, PaymentRail.onchain);
      expect(resolved.canContinue, isTrue);
      expect(
        resolver.toLockedDestination(resolved).type,
        SendDestinationType.onChain,
      );
    });

    test('on-chain from cold → coldOnchain rail', () {
      final intent = parser.parse('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.watchOnly,
      );
      expect(resolved.selectedRail, PaymentRail.coldOnchain);
      expect(resolved.canContinue, isTrue);
    });

    test('network mismatch blocks', () {
      final intent = parser.parse('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4');
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.internal,
        expectedNetwork: BitcoinNetworkKind.testnet,
      );
      expect(resolved.canContinue, isFalse);
      expect(
        resolved.blockers.any((b) => b.code == PaymentBlockerCode.networkMismatch),
        isTrue,
      );
    });

    test('self-pay by wallet id blocks', () {
      final id = '61a8bb23-e18e-4f32-8414-9844e7300c14';
      final intent = parser.parse(id);
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.internal,
        sourceWalletId: id,
      );
      expect(
        resolved.blockers.any((b) => b.code == PaymentBlockerCode.selfPay),
        isTrue,
      );
    });

    test('username with internal-only capabilities → internal rail', () {
      final intent = parser.parse('@alice_01');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(internal: true, onchain: false),
      );
      expect(resolved.canContinue, isTrue);
      expect(resolved.selectedRail, PaymentRail.internal);
      expect(resolved.destWalletId, isNotEmpty);
      expect(resolved.alternatives, hasLength(1));
      final locked = resolver.toLockedDestination(resolved);
      expect(locked.type, SendDestinationType.internal);
      expect(locked.normalizedValue, resolved.destWalletId);
      expect(locked.label, 'Alice');
    });

    test('preferred onchain used when address present', () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.custodialOnchain,
        capabilities: caps(
          internal: true,
          onchain: true,
          preferred: 'ONCHAIN',
        ),
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      expect(resolved.selectedRail, PaymentRail.onchain);
      expect(resolved.alternatives.length, greaterThanOrEqualTo(2));
    });

    test('user can override preferred rail', () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(
          internal: true,
          onchain: true,
          preferred: 'ONCHAIN',
        ),
        userSelectedRail: PaymentRail.internal,
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      expect(resolved.selectedRail, PaymentRail.internal);
    });

    test('no capabilities → blocker', () {
      final intent = parser.parse('ghost_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(
          internal: false,
          onchain: false,
          walletId: null,
          missing: const ['KFE_INTERNAL_WALLET_NOT_FOUND'],
        ),
      );
      expect(resolved.canContinue, isFalse);
      expect(
        resolved.blockers.any((b) => b.code == PaymentBlockerCode.noCapability),
        isTrue,
      );
    });

    test('payment link from cold is blocked', () {
      final intent = parser.parse('kerosene:link:abc');
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.watchOnly,
      );
      expect(resolved.selectedRail, PaymentRail.paymentLink);
      expect(resolved.canContinue, isFalse);
    });

    test('lightning invoice from custodial continues', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse(invoice);
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.custodialOnchain,
      );
      expect(resolved.selectedRail, PaymentRail.lightning);
      expect(resolved.canContinue, isTrue);
    });
  });
}
