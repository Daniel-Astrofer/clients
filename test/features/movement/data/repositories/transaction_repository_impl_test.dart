import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/movement/data/datasources/transaction_remote_datasource.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository_impl.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';

class _SpyTransactionRemoteDataSource implements TransactionRemoteDataSource {
  TxStatus response = const TxStatus(
    txid: 'tx-default',
    status: 'confirmed',
    feeSatoshis: 0,
    amountReceived: 0,
  );

  int sendCalls = 0;
  String? lastFromAddress;
  String? lastToAddress;
  double? lastAmount;
  int? lastFeeSatoshis;
  String? lastContext;
  String? lastPasskeyAssertionJson;
  String? lastConfirmationPassphrase;
  String? lastTotpCode;
  String? lastIdempotencyKey;
  int? lastRequestTimestamp;

  @override
  Future<TxStatus> sendTransaction({
    required String fromAddress,
    required String toAddress,
    required double amount,
    required int feeSatoshis,
    String? context,
    String? passkeyAssertionJson,
    String? confirmationPassphrase,
    String? totpCode,
    String? idempotencyKey,
    int? requestTimestamp,
    String? appPin,
  }) async {
    sendCalls++;
    lastFromAddress = fromAddress;
    lastToAddress = toAddress;
    lastAmount = amount;
    lastFeeSatoshis = feeSatoshis;
    lastContext = context;
    lastPasskeyAssertionJson = passkeyAssertionJson;
    lastConfirmationPassphrase = confirmationPassphrase;
    lastTotpCode = totpCode;
    lastIdempotencyKey = idempotencyKey;
    lastRequestTimestamp = requestTimestamp;
    return response;
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

class _SpyAuthLocalDataSource implements AuthLocalDataSource {
  int getTokenCalls = 0;
  String? token;

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpyTransactionRemoteDataSource remoteDataSource;
  late _SpyAuthLocalDataSource authLocalDataSource;
  late TransactionRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _SpyTransactionRemoteDataSource();
    authLocalDataSource = _SpyAuthLocalDataSource();
    repository = TransactionRepositoryImpl(
      remoteDataSource: remoteDataSource,
      authLocalDataSource: authLocalDataSource,
    );
  });

  group('TransactionRepositoryImpl.sendTransaction', () {
    test(
      'does not block manual internal transfers on a local missing token',
      () async {
        remoteDataSource.response = const TxStatus(
          txid: 'tx-manual-1',
          status: 'confirmed',
          feeSatoshis: 0,
          amountReceived: 0.125,
          sender: '42',
          receiver: 'destino',
          context: 'manual',
        );

        final result = await repository.sendTransaction(
          fromWalletId: '42',
          toAddress: 'destino',
          amount: 0.125,
          feeSatoshis: 0,
          context: 'manual',
          idempotencyKey: 'idem-1',
          requestTimestamp: 1710000000000,
        );

        expect(result, remoteDataSource.response);
        expect(authLocalDataSource.getTokenCalls, 0);
        expect(remoteDataSource.sendCalls, 1);
        expect(remoteDataSource.lastFromAddress, '42');
        expect(remoteDataSource.lastToAddress, 'destino');
        expect(remoteDataSource.lastAmount, 0.125);
        expect(remoteDataSource.lastFeeSatoshis, 0);
        expect(remoteDataSource.lastContext, 'manual');
        expect(remoteDataSource.lastIdempotencyKey, 'idem-1');
        expect(remoteDataSource.lastRequestTimestamp, 1710000000000);
      },
    );

    test('prefers the explicit KFE wallet id when it is available', () async {
      remoteDataSource.response = const TxStatus(
        txid: 'tx-manual-2',
        status: 'confirmed',
        feeSatoshis: 0,
        amountReceived: 0.5,
        sender: 'hash-da-carteira',
        receiver: 'destino',
      );

      final result = await repository.sendTransaction(
        fromWalletId: '42',
        fromAddress: '  hash-da-carteira  ',
        toAddress: 'destino',
        amount: 0.5,
        feeSatoshis: 0,
      );

      expect(result, remoteDataSource.response);
      expect(authLocalDataSource.getTokenCalls, 0);
      expect(remoteDataSource.sendCalls, 1);
      expect(remoteDataSource.lastFromAddress, '42');
      expect(remoteDataSource.lastToAddress, 'destino');
      expect(remoteDataSource.lastAmount, 0.5);
      expect(remoteDataSource.lastFeeSatoshis, 0);
      expect(remoteDataSource.lastContext, isNull);
      expect(remoteDataSource.lastIdempotencyKey, isNull);
      expect(remoteDataSource.lastRequestTimestamp, isNull);
    });
  });

  group('TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload', () {
    test('builds the network on-chain send body required by the backend', () {
      final payload =
          TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
        idempotencyKey: ' idem-123 ',
        fromWalletName: ' Minha Carteira ',
        toAddress: ' bc1qdestino ',
        amount: 0.0001,
        description: ' saque para carteira externa ',
        totpCode: ' 123456 ',
        confirmationPassphrase: ' frase ',
        passkeyAssertionJson: null,
      );

      expect(payload, {
        'idempotencyKey': 'idem-123',
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'sourceWalletId': 'Minha Carteira',
        'amountSats': 10000,
        'networkFeeSats': 0,
        'externalReference': 'bc1qdestino',
        'memo': 'saque para carteira externa',
        'totpCode': '123456',
        'confirmationPassphrase': 'frase',
      });
    });

    test('uses the default on-chain description when none is provided', () {
      final payload =
          TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
        idempotencyKey: 'idem-123',
        fromWalletName: 'Minha Carteira',
        toAddress: 'bc1qdestino',
        amount: 0.0001,
      );

      expect(payload['memo'], 'saque para carteira externa');
    });

    test('builds an internal transfer for a destination wallet UUID', () {
      final payload =
          TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
        idempotencyKey: 'idem-internal',
        fromWalletName: 'Minha Carteira',
        toAddress: '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8',
        paymentRequest: ' public-internal-id ',
        amount: 0.0001,
        networkFeeBtc: 0.0005,
      );

      expect(payload, {
        'idempotencyKey': 'idem-internal',
        'rail': 'INTERNAL',
        'direction': 'INTERNAL',
        'sourceWalletId': 'Minha Carteira',
        'destinationWalletId': '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8',
        'paymentRequestPublicId': 'public-internal-id',
        'amountSats': 10000,
        'networkFeeSats': 0,
        'memo': 'transferencia interna',
      });
    });

    test('preserves the Lightning outbound contract', () {
      final payload =
          TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
        idempotencyKey: 'idem-lightning',
        fromWalletName: 'Minha Carteira',
        paymentRequest: 'lnbcrt1paymentrequest',
        amount: 0.0001,
        isLightning: true,
        maxRoutingFeeBtc: 0.000002,
      );

      expect(payload, {
        'idempotencyKey': 'idem-lightning',
        'rail': 'LIGHTNING',
        'direction': 'OUTBOUND',
        'sourceWalletId': 'Minha Carteira',
        'amountSats': 10000,
        'networkFeeSats': 200,
        'externalReference': 'lnbcrt1paymentrequest',
        'memo': 'Pagamento Lightning',
      });
    });

    test('platform paymentRequest publicId forces INTERNAL even if isLightning',
        () {
      final payload =
          TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
        idempotencyKey: 'idem-platform-ln',
        fromWalletName: 'Minha Carteira',
        toAddress: '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8',
        paymentRequest: '8ou3btbrv9wdqgipgcicxh8k',
        amount: 0.00009333,
        isLightning: true,
      );

      expect(payload['rail'], 'INTERNAL');
      expect(payload['direction'], 'INTERNAL');
      expect(payload['destinationWalletId'],
          '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8');
      expect(payload['paymentRequestPublicId'], '8ou3btbrv9wdqgipgcicxh8k');
      expect(payload.containsKey('externalReference'), isFalse);
    });

    test('requires idempotencyKey for external withdrawals', () {
      expect(
        () => TransactionRemoteDataSourceImpl.buildWithdrawRequestPayload(
          fromWalletName: 'Minha Carteira',
          toAddress: 'bc1qdestino',
          amount: 0.0001,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
