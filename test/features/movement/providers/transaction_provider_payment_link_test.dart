import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show WalletNotifier, walletProvider;
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_execution_overlay.dart';
import 'package:kerosene/features/movement/presentation/send/send_rail_executors.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';

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
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'internal-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.sourceWalletIds, ['payer-wallet-id']);
    expect(repository.withdrawalDestinations, [destinationWalletId]);
    expect(repository.paymentRequestPublicIds, ['payment-link']);
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
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'onchain-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [onchainAddress]);
    expect(repository.paymentRequestPublicIds, [null]);
  });

  test('pays a LIGHTNING platform link via INTERNAL ledger (not LND)',
      () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'LIGHTNING',
        depositAddress: 'lntb10u1ptest',
        destinationHash: destinationWalletId,
        paymentRequest: 'lntb10u1ptest',
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'ln-platform-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'ln-platform-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [destinationWalletId]);
    expect(repository.paymentRequestPublicIds, ['payment-link']);
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
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'internal-retry-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations,
        [destinationWalletId, destinationWalletId]);
    expect(signedChallenges, [_passkeyChallenge]);
    expect(repository.passkeyAssertions, [null, '{"signed":true}']);
    expect(
        repository.paymentRequestPublicIds, ['payment-link', 'payment-link']);
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
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'onchain-retry-idempotency',
            );

    expect(result, isNotNull);
    expect(repository.withdrawalDestinations, [onchainAddress, onchainAddress]);
    expect(repository.paymentRequestPublicIds, [null, null]);
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
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'invalid-internal-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, isEmpty);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('ERR_KFE_PAYMENT_LINK_DESTINATION_MISSING'),
    );
  });

  test('rejects an INTERNAL link without a public reference', () async {
    final repository = _PaymentLinkRepository(
      _link(
        id: ' ',
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'invalid-internal-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'missing-reference-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, isEmpty);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('ERR_KFE_PAYMENT_LINK_REFERENCE_MISSING'),
    );
  });

  test('rejects self-payment before submitting an INTERNAL link', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
    );
    final container = _container(
      repository,
      authState: AuthAuthenticated(
        User(
          id: '7',
          username: 'receiver',
          createdAt: DateTime(2026, 1, 1),
        ),
      ),
    );
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'self-payment-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'self-payment-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, isEmpty);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('LEDGER_009'),
    );
  });

  for (final terminalStatus in const [
    'CANCELLED',
    'CANCELED',
    'HIDDEN',
    'EXPIRED',
    'PAID',
    'COMPLETED',
  ]) {
    test('rejects $terminalStatus link before withdrawal', () async {
      final repository = _PaymentLinkRepository(
        _link(
          paymentRail: 'ONCHAIN',
          depositAddress: onchainAddress,
          status: terminalStatus,
        ),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final result =
          await container.read(paymentLinkNotifierProvider.notifier).pay(
                linkId: 'terminal-link',
                payerWalletId: 'payer-wallet-id',
                idempotencyKey: 'terminal-$terminalStatus',
              );

      expect(result, isNull);
      expect(repository.withdrawalDestinations, isEmpty);
    });
  }

  test('rejects a locally expired link before withdrawal', () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'ONCHAIN',
        depositAddress: onchainAddress,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'locally-expired-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'locally-expired-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, isEmpty);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('ERR_KFE_PAYMENT_LINK_NOT_OPEN'),
    );
  });

  test('clears error when passkey assertion is cancelled by the user',
      () async {
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
      challengeFailures: 1,
    );
    final container = _container(
      repository,
      passkeyAssertionBuilder: (_) async {
        throw const DeviceKeyException(
          'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED',
          'A confirmação do dispositivo foi cancelada.',
        );
      },
    );
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'cancel-passkey-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'cancel-passkey-idempotency',
            );

    expect(result, isNull);
    // First attempt triggers challenge; retry builder cancels — no ugly error.
    expect(repository.withdrawalDestinations, [destinationWalletId]);
    expect(container.read(paymentLinkNotifierProvider).error, isNull);
    expect(container.read(paymentLinkNotifierProvider).cause,
        isA<PaymentAuthorizationCancelledException>());
    expect(container.read(paymentLinkNotifierProvider).isLoading, isFalse);
  });

  for (final cancelled in [true, false]) {
    testWidgets(
        '${cancelled ? 'cancelled' : 'accepted'} proof reaches review through the real payment executor',
        (tester) async {
      final repository = _PaymentLinkRepository(
        _link(
            paymentRail: 'INTERNAL',
            depositAddress: 'kerosene:wallet:$destinationWalletId',
            destinationHash: destinationWalletId),
        challengeFailures: 1,
        successResult: const TxStatus(
            txid: '9229cdb5-f644-4d3e-a924-e3447159b938',
            status: 'EXECUTING',
            feeSatoshis: 0,
            amountReceived: 0.0001),
      );
      final container =
          _container(repository, passkeyAssertionBuilder: (_) async {
        if (cancelled) {
          throw const DeviceKeyException('ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED',
              'A confirmação do dispositivo foi cancelada.');
        }
        return '{"signed":true}';
      });
      addTearDown(container.dispose);
      var finished = false;
      var notices = 0;
      Object? executionError;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
              builder: (context, ref, _) => Scaffold(
                    body: Column(children: [
                      const Text('Revisão: R\$ 50,00'),
                      TextButton(
                          onPressed: () async {
                            final result =
                                await SendPaymentExecutionOverlay.show<dynamic>(
                              context,
                              onExecute: () => executePaymentLinkSend(
                                confirmationContext: context,
                                ref: ref,
                                wallet: Wallet(
                                    id: 'payer-wallet-id',
                                    name: 'Conta',
                                    address: '',
                                    balance: 0.001,
                                    derivationPath: '',
                                    type: WalletType.segwit,
                                    createdAt: DateTime(2026),
                                    updatedAt: DateTime(2026)),
                                destination: const SendDestinationAnalysis(
                                    type: SendDestinationType.paymentLink,
                                    normalizedValue: 'payment-link'),
                                amount: 0.0001,
                                toAddress: destinationWalletId,
                                linkId: 'payment-link',
                                authResult:
                                    const TransactionAuthResult.success(),
                                showSentTransactionNotification: (
                                    {required wallet,
                                    required destination,
                                    required amount,
                                    required toAddress}) async {
                                  notices++;
                                },
                                isMounted: () => context.mounted,
                              ).catchError((Object error) {
                                executionError = error;
                                throw error;
                              }),
                            );
                            if (cancelled) {
                              expect(result, isNull);
                            } else {
                              expect(result, isA<TxStatus>());
                              expect((result as TxStatus).isConfirmed, isFalse);
                              expect(result.status, 'EXECUTING');
                            }
                            finished = true;
                          },
                          child: const Text('Autorizar')),
                    ]),
                  )),
        ),
      ));
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();
      if (cancelled) {
        expect(executionError, isA<PaymentAuthorizationCancelledException>());
      } else {
        expect(executionError, isNull);
      }
      expect(find.byType(SendPaymentExecutionOverlay<dynamic>), findsNothing);
      await tester.pump();
      expect(finished, isTrue);
      expect(find.text('Revisão: R\$ 50,00'), findsOneWidget);
      expect(find.text('Resultado em verificação'), findsNothing);
      expect(repository.withdrawalDestinations, hasLength(cancelled ? 1 : 2));
      expect(notices, cancelled ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'keeps a transport failure after signing even when it mentions cancellation',
      () async {
    const failure = ServerException(
      message: 'RPC response lost after user canceled a remote request',
      errorCode: 'ERR_TRANSPORT_RESPONSE_LOST',
      statusCode: 503,
    );
    final repository = _PaymentLinkRepository(
      _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
      ),
      challengeFailures: 1,
      withdrawalFailure: failure,
    );
    final container = _container(repository,
        passkeyAssertionBuilder: (_) async => '{"signed":true}');
    addTearDown(container.dispose);

    final result = await container
        .read(paymentLinkNotifierProvider.notifier)
        .pay(
            linkId: 'response-lost-link',
            payerWalletId: 'payer-wallet-id',
            idempotencyKey: 'response-lost-idempotency');

    expect(result, isNull);
    expect(repository.withdrawalDestinations, hasLength(2));
    expect(container.read(paymentLinkNotifierProvider).error,
        contains('ERR_TRANSPORT_RESPONSE_LOST'));
    expect(container.read(paymentLinkNotifierProvider).cause, same(failure));
  });

  test('does not retry withdrawal when the link becomes paid', () async {
    final openLink = _link(
      paymentRail: 'INTERNAL',
      depositAddress: 'kerosene:wallet:$destinationWalletId',
      destinationHash: destinationWalletId,
    );
    final repository = _PaymentLinkRepository(
      openLink,
      retryLink: _link(
        paymentRail: 'INTERNAL',
        depositAddress: 'kerosene:wallet:$destinationWalletId',
        destinationHash: destinationWalletId,
        status: 'PAID',
      ),
      challengeFailures: 1,
    );
    var passkeyBuilds = 0;
    final container = _container(
      repository,
      passkeyAssertionBuilder: (_) async {
        passkeyBuilds++;
        return '{"signed":true}';
      },
    );
    addTearDown(container.dispose);

    final result =
        await container.read(paymentLinkNotifierProvider.notifier).pay(
              linkId: 'paid-during-retry-link',
              payerWalletId: 'payer-wallet-id',
              idempotencyKey: 'paid-during-retry-idempotency',
            );

    expect(result, isNull);
    expect(repository.withdrawalDestinations, [destinationWalletId]);
    expect(passkeyBuilds, 0);
    expect(
      container.read(paymentLinkNotifierProvider).error,
      contains('ERR_KFE_PAYMENT_LINK_ALREADY_PAID'),
    );
  });
}

const _passkeyChallenge =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

ProviderContainer _container(
  _PaymentLinkRepository repository, {
  Future<String> Function(String)? passkeyAssertionBuilder,
  AuthState authState = const AuthUnauthenticated(),
}) {
  return ProviderContainer(
    overrides: [
      transactionRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(
        () => _TestAuthController(authState),
      ),
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
  String id = 'payment-link',
  required String paymentRail,
  required String depositAddress,
  String? destinationHash,
  String status = 'PENDING',
  DateTime? expiresAt,
  String? paymentRequest,
}) {
  return PaymentLink(
    id: id,
    userId: 7,
    amountBtc: 0.0001,
    description: 'Payment request',
    depositAddress: depositAddress,
    destinationHash: destinationHash,
    locked: paymentRail == 'INTERNAL' || paymentRail == 'LIGHTNING',
    status: status,
    expiresAt: expiresAt,
    paymentRail: paymentRail,
    paymentRequest: paymentRequest,
  );
}

class _TestAuthController extends AuthController {
  final AuthState initialState;

  _TestAuthController(this.initialState);

  @override
  AuthState build() => initialState;
}

class _TestWalletNotifier extends WalletNotifier {
  @override
  WalletState build() => const WalletInitial();

  @override
  Future<void> refresh() async {}
}

class _PaymentLinkRepository implements TransactionRepository {
  final PaymentLink link;
  final PaymentLink? retryLink;
  final Object? withdrawalFailure;
  final TxStatus successResult;
  int challengeFailures;
  int paymentLinkReads = 0;
  final List<String> withdrawalDestinations = [];
  final List<String> sourceWalletIds = [];
  final List<String?> paymentRequestPublicIds = [];
  final List<String?> passkeyAssertions = [];

  _PaymentLinkRepository(
    this.link, {
    this.retryLink,
    this.withdrawalFailure,
    this.challengeFailures = 0,
    this.successResult = const TxStatus(
        txid: 'transaction-id',
        status: 'SETTLED',
        feeSatoshis: 0,
        amountReceived: 0.0001),
  });

  @override
  Future<PaymentLink> getPaymentLink(String linkId) async {
    paymentLinkReads++;
    return paymentLinkReads > 1 && retryLink != null ? retryLink! : link;
  }

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
    int? networkFeeSats,
    int? feeRateSatPerVbyte,
    int? feeTargetBlocks,
    String? description,
    String? confirmationPassphrase,
    String? passkeyAssertionJson,
    String? idempotencyKey,
    String? appPin,
  }) async {
    sourceWalletIds.add(fromWalletName);
    withdrawalDestinations.add(toAddress ?? '');
    paymentRequestPublicIds.add(paymentRequest);
    passkeyAssertions.add(passkeyAssertionJson);
    if (challengeFailures > 0) {
      challengeFailures--;
      throw const ServerException(
        message: 'PASSKEY_CHALLENGE_REQUIRED:$_passkeyChallenge',
      );
    }
    final failure = withdrawalFailure;
    if (failure != null) throw failure;
    return successResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Transaction> cancelTransaction(String transactionId) async {
    throw UnimplementedError();
  }

  @override
  Future<PaymentLink> cancelPaymentRequest(String requestId) async {
    throw UnimplementedError();
  }
}
