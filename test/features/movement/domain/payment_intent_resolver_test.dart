import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_parser.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_resolver.dart';
import 'package:kerosene/features/movement/data/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';

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

    test('dest internal-only + cold source → blocked', () {
      final intent = parser.parse('@alice_01');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.watchOnly,
        capabilities: caps(internal: true, onchain: false),
        availableSources: const [SourceCustody.watchOnly],
      );
      expect(resolved.canContinue, isFalse);
      expect(
        resolved.blockers.any((b) => b.code == PaymentBlockerCode.noCapability),
        isTrue,
      );
    });

    test('dest internal+onchain + internal source → both rails, default internal',
        () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(internal: true, onchain: true),
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      expect(resolved.canContinue, isTrue);
      expect(resolved.selectedRail, PaymentRail.internal);
      expect(resolved.alternatives, hasLength(2));
      expect(
        resolved.alternatives.map((o) => o.rail),
        containsAll([PaymentRail.internal, PaymentRail.onchain]),
      );
    });

    test('dest onchain-only + internal source → onchain ok', () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(internal: false, onchain: true, walletId: null),
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      expect(resolved.canContinue, isTrue);
      expect(resolved.selectedRail, PaymentRail.onchain);
    });

    test('dest internal+onchain + cold with address → coldOnchain', () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.watchOnly,
        capabilities: caps(internal: true, onchain: true),
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
        availableSources: const [SourceCustody.watchOnly],
      );
      expect(resolved.canContinue, isTrue);
      expect(resolved.selectedRail, PaymentRail.coldOnchain);
      expect(resolved.alternatives, hasLength(1));
      expect(resolved.alternatives.first.rail, PaymentRail.onchain);
    });

    test('preferred onchain used when address present and source can L1', () {
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
        availableSources: const [
          SourceCustody.internal,
          SourceCustody.custodialOnchain,
        ],
      );
      // Current source is custodial → only onchain is selectable for this wallet.
      expect(resolved.selectedRail, PaymentRail.onchain);
      expect(resolved.alternatives, hasLength(1));
      expect(resolved.alternatives.first.rail, PaymentRail.onchain);
    });

    test('availableSources internal+custodial keeps both rails for internal source',
        () {
      final intent = parser.parse('bob_user');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(internal: true, onchain: true),
        destOnchainAddress: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
        availableSources: const [
          SourceCustody.internal,
          SourceCustody.custodialOnchain,
        ],
      );
      expect(resolved.alternatives, hasLength(2));
      expect(resolved.selectedRail, PaymentRail.internal);
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

    test('override onchain clamped when dest is internal-only', () {
      final intent = parser.parse('@alice_01');
      final resolved = resolver.resolveWithCapabilities(
        intent: intent,
        source: SourceCustody.internal,
        capabilities: caps(internal: true, onchain: false),
        userSelectedRail: PaymentRail.onchain,
      );
      expect(resolved.selectedRail, PaymentRail.internal);
      expect(resolved.alternatives, hasLength(1));
    });

    test('sourceCanExecute matrix', () {
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.internal,
          SourceCustody.internal,
        ),
        isTrue,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.lightning,
          SourceCustody.internal,
        ),
        isTrue,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.onchain,
          SourceCustody.internal,
        ),
        isTrue,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.lightning,
          SourceCustody.watchOnly,
        ),
        isFalse,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.internal,
          SourceCustody.watchOnly,
        ),
        isFalse,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.onchain,
          SourceCustody.watchOnly,
        ),
        isTrue,
      );
      expect(
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.lightning,
          SourceCustody.custodialOnchain,
        ),
        isFalse,
      );
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

    test('lightning invoice from internal continues', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse(invoice);
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.internal,
      );
      expect(resolved.selectedRail, PaymentRail.lightning);
      expect(resolved.canContinue, isTrue);
    });

    test('lightning invoice from custodial is blocked', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse(invoice);
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.custodialOnchain,
      );
      expect(resolved.selectedRail, PaymentRail.lightning);
      expect(resolved.canContinue, isFalse);
    });

    test('lightning invoice from cold is blocked', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final intent = parser.parse(invoice);
      final resolved = resolver.resolveLocal(
        intent: intent,
        source: SourceCustody.watchOnly,
      );
      expect(resolved.canContinue, isFalse);
    });

    test('walletMatchesSendRail checks spendability appropriately', () {
      Wallet wallet(String id, String mode, bool spendable) {
        return Wallet(
          id: id,
          name: 'W',
          address: 'bc1q...',
          walletMode: mode,
          balance: 0.0,
          availableSats: 0,
          observedSats: 0,
          derivationPath: "m/84'/0'/0'",
          type: WalletType.nativeSegwit,
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
          spendable: spendable,
        );
      }
      
      final internalSpendable = wallet('1', 'KEROSENE', true);
      final internalNotSpendable = wallet('2', 'KEROSENE', false);
      final custodialSpendable = wallet('3', 'CUSTODIAL_ONCHAIN', true);
      final custodialNotSpendable = wallet('4', 'CUSTODIAL_ONCHAIN', false);
      final cold = wallet('5', 'SELF_CUSTODY', true);

      // Internal rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.internal), isTrue);
      expect(walletMatchesSendRail(internalNotSpendable, PaymentRail.internal), isFalse);

      // Lightning rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.lightning), isTrue);
      expect(walletMatchesSendRail(custodialSpendable, PaymentRail.lightning), isFalse);

      // Onchain rail
      expect(walletMatchesSendRail(internalSpendable, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(custodialSpendable, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(custodialNotSpendable, PaymentRail.onchain), isFalse);
      expect(walletMatchesSendRail(cold, PaymentRail.onchain), isTrue);
      expect(walletMatchesSendRail(cold, PaymentRail.coldOnchain), isTrue);
    });
  });
}
