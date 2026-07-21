import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/execution/send_contexts.dart';
import 'package:kerosene/features/movement/kernel/execution/send_rail_handlers.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_analyzer.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';

void main() {
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

  group('send rail quote', () {
    test('internal quotes passthrough debit', () {
      final destination = analyzeSendDestination('@alice');
      final quoted = const InternalMovementHandler().quote(
        SendQuoteRequest(
          wallet: wallet(id: 'w1', mode: 'KEROSENE'),
          destination: destination,
          amountBtc: 0.01,
          feeTier: NetworkFeeTier.standard,
        ),
      );
      expect(quoted, isNotNull);
      expect(quoted!.totalDebitedBtc, 0.01);
      expect(quoted.networkFeeBtc, 0);
    });

    test('lightning marks routing fee unknown until pay', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final destination = analyzeSendDestination(invoice);
      final quoted = const LightningMovementHandler().quote(
        SendQuoteRequest(
          wallet: wallet(id: 'w1', mode: 'KEROSENE'),
          destination: destination,
          amountBtc: 0.002,
          feeTier: NetworkFeeTier.standard,
        ),
      );
      expect(quoted?.networkFeeCertainty, NetworkFeeCertainty.unknownUntilPay);
    });

    test('lightning from cold returns cold_no_lightning error', () {
      const invoice =
          'lntb20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq';
      final destination = analyzeSendDestination(invoice);
      final quoted = const LightningMovementHandler().quote(
        SendQuoteRequest(
          wallet: wallet(id: 'cold', mode: 'SELF_CUSTODY', spendable: false),
          destination: destination,
          amountBtc: 0.002,
          feeTier: NetworkFeeTier.standard,
        ),
      );
      expect(quoted?.error, 'cold_no_lightning');
    });

    test('onchain without estimate is loading', () {
      final destination = analyzeSendDestination(
        'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      );
      final quoted = const OnchainMovementHandler().quote(
        SendQuoteRequest(
          wallet: wallet(id: 'w1', mode: 'KEROSENE'),
          destination: destination,
          amountBtc: 0.01,
          feeTier: NetworkFeeTier.fast,
          feeEstimateLoading: true,
        ),
      );
      expect(quoted?.isLoading, isTrue);
      expect(quoted?.networkFeeCertainty, NetworkFeeCertainty.loading);
    });
  });
}
