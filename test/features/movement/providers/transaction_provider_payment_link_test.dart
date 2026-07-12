import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show WalletNotifier, walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/domain/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

void main() {
  const destinationWalletId = '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8';
  const onchainAddress = 'bcrt1qpaymentrequest';

  test('pays an INTERNAL link using its destination hash', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'internal-link',
              payerWalletName: 'payer-wallet',
              idempotencyKey: 'internal-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [destinationWalletId]);
  });

  test('pays an ONCHAIN link using its deposit address', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'ONCHAIN',
        depositAddress: onchainAddress,
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'onchain-link',
              payerWalletName: 'payer-wallet',
              idempotencyKey: 'onchain-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [onchainAddress]);
  });

  test('keeps the INTERNAL destination hash during passkey retry', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
      challengeFailures: 1,
    );
    final signedChallenges = <String>[];
    final container = _container(
      repository,
      passkeyAssertionBuilder: (challenge) async {
        signedChallenges.add(challenge);
        return '{"signed":true}';
      },
    );
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'internal-link',
              payerWalletName: 'payer-wallet',
              idempotencyKey: 'internal-retry-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations,
        [destinationWalletId, destinationWalletId]);
    expect(signedChallenges, [_passkeyChallenge]);
    expect(repository.passkeyAssertions, [null, '{"signed":true}']);
  });

  test('keeps the ONCHAIN deposit address during passkey retry', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'ONCHAIN',
        depositAddress: onchainAddress,
      ),
      challengeFailures: 1,
    );
    final container = _container(
      repository,
      passkeyAssertionBuilder: (_) async => '{"signed":true}',
    );
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'onchain-link',
              payerWalletName: 'payer-wallet',
              idempotencyKey: 'onchain-retry-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [onchainAddress, onchainAddress]);
  });

  test('rejects an INTERNAL link without a destination hash', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:',
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'invalid-internal-link',
              payerWalletName: 'payer-wallet',
              idempotencyKey: 'invalid-internal-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, isEmpty);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('ERR_KFE_PAYMENT_LINK_DESTINATION_MISSING'),
    );
  });
}

const _passkeyChallenge =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

ProviderContainer _container(
  _PaymentLinkRepository repository, {
  Future<String> Function(String)? passkeyAssertionBuilder,
}) {
  return ProviderContainer(
    overrides: [
      transactionRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(_UnauthenticatedController.new),
      walletProvider.overrideWith(_TestWalletNotifier.new),
      paymentLinkNotifierProvider.overrideWith(
        () => PaymentLinkNotifier(
          passkeyAssertionBuilder: passkeyAssertionBuilder,
        ),
      ),
    ],
  );
}

PaymentLink _link({
  required String paymentRail,
  required String depositAddress,
  String? destinationHash,
}) {
  return PaymentLink(
    id: 'payment-link',
    userId: 7,
    amountBtc: 0.0001,
    description: 'Payment request',
    depositAddress: depositAddress,
    destinationHash: destinationHash,
    locked: paymentRail == 'INTERNAL',
    status: 'PENDING',
    paymentRail: paymentRail,
  );
}

class _UnauthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _TestWalletNotifier extends WalletNotifier {
  @override
  WalletState build() => const WalletInitial();

  @override
  Future<void> refresh() async {}
}

class _PaymentLinkRepository implements TransactionRepository {
  final PaymentLink link;
  int challengeFailures;
  final List<String> withdrawalDestinations = [];
  final List<String?> passkeyAssertions = [];

  _PaymentLinkRepository(this.link, {this.challengeFailures = 0});

  @override
  Future<PaymentLink> getPaymentLink(String linkId) async => link;

  @override
  Future<TxStatus> withdraw({
    required String fromWalletName,
    String? toAddress,
    String? paymentRequest,
    required double amount,
    String? totpCode,
    bool isLightning = false,
    double networkFeeBtc = 0,
    double maxRoutingFeeBtc = 0.000001,
    String? description,
    String? confirmationPassphrase,
    String? passkeyAssertionJson,
    String? idempotencyKey,
    String? appPin,
  }) async {
    withdrawalDestinations.add(toAddress ?? '');
    passkeyAssertions.add(passkeyAssertionJson);
    if (challengeFailures > 0) {
      challengeFailures--;
      throw const ServerException(
        message: 'PASSKEY_CHALLENGE_REQUIRED:$_passkeyChallenge',
      );
    }
    return const TxStatus(
      txid: 'transaction-id',
      status: 'SETTLED',
      feeSatoshis: 0,
      amountReceived: 0.0001,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
