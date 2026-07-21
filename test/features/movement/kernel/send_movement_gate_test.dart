import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/execution/send_rail_handlers.dart';
import 'package:kerosene/features/movement/kernel/intent/movement_intent_bridge.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent_parser.dart';
import 'package:kerosene/features/movement/kernel/routing/movement_router.dart';
import 'package:kerosene/features/movement/kernel/routing/send_movement_gate.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_analyzer.dart';

void main() {
  const router = MovementRouter([
    PaymentLinkMovementHandler(),
    LightningMovementHandler(),
    OnchainMovementHandler(),
    InternalMovementHandler(),
  ]);
  const parser = PaymentIntentParser();

  Wallet wallet({
    required String id,
    required String mode,
    bool spendable = true,
  }) {
    return Wallet(
      id: id,
      name: id,
      address: 'addr-$id',
      walletMode: mode,
      balance: 1.0,
      availableSats: 0,
      observedSats: 0,
      derivationPath: "m/84'/0'/0'",
      type: WalletType.nativeSegwit,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      spendable: spendable,
    );
  }

  group('movementIntent bridge', () {
    test('round-trips payment intent kinds', () {
      final payment = parser.parse('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      final movement = movementIntentFromPayment(payment);
      final back = paymentIntentFromMovement(movement);
      expect(back.kind, payment.kind);
      expect(back.normalizedValue, payment.normalizedValue);
    });
  });

  group('decideSendMovement', () {
    test('routes on-chain to onchain handler', () async {
      final destination = analyzeSendDestination(
        'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      final decision = await decideSendMovement(
        router: router,
        destination: destination,
        sourceWallet: wallet(id: 'cold', mode: 'SELF_CUSTODY', spendable: false),
        expectedNetwork: BitcoinNetworkKind.testnet,
      );
      expect(decision.handler?.id, 'onchain');
      expect(decision.canContinue, isTrue);
      expect(decision.resolvedIntent?.selectedRail, PaymentRail.coldOnchain);
    });

    test('blocks cold wallet from lightning destination', () async {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final destination = analyzeSendDestination(invoice);
      expect(destination.isLightning, isTrue);
      final decision = await decideSendMovement(
        router: router,
        destination: destination,
        sourceWallet: wallet(id: 'cold', mode: 'SELF_CUSTODY', spendable: false),
      );
      expect(decision.handler?.id, 'lightning');
      expect(decision.canContinue, isFalse);
      expect(decision.blockers, isNotEmpty);
    });

    test('routes internal username to internal handler', () async {
      final destination = analyzeSendDestination('@alice');
      final decision = await decideSendMovement(
        router: router,
        destination: destination,
        sourceWallet: wallet(id: 'internal', mode: 'KEROSENE'),
      );
      expect(decision.handler?.id, 'internal');
    });

    test('rejects empty destination', () async {
      final decision = await decideSendMovement(
        router: router,
        destination: analyzeSendDestination(''),
      );
      expect(decision.canContinue, isFalse);
      expect(decision.errorMessage, isNotNull);
    });
  });
}
