import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/movement/data/datasources/transaction_remote_datasource.dart';

void main() {
  const walletId = '6de12a56-2cc4-47ca-9f9c-5939ffaf35e8';

  test('creates INTERNAL payment request without asking for a Bitcoin address',
      () async {
    final apiClient = _PaymentRequestApiClient(walletId: walletId);
    final dataSource = TransactionRemoteDataSourceImpl(apiClient);

    final link = await dataSource.createPaymentLink(
      amount: 0.0001,
      description: 'Internal payment',
      referenceLabel: 'Conta principal',
      metadata: const {
        'walletName': 'Conta principal',
        'rail': 'internal',
      },
    );

    expect(apiClient.postedPath, AppConfig.kfePaymentRequests);
    expect(apiClient.postedData?['rail'], 'INTERNAL');
    expect(apiClient.postedData?.containsKey('issueFreshAddress'), isFalse);
    expect(link.id, 'public-internal-id');
    expect(link.userId, 7);
    expect(link.destinationHash, walletId);
    expect(link.locked, isTrue);
    expect(
      link.paymentUri,
      'kerosene://payment/pay/public-internal-id',
    );
    expect(link.paymentRail, 'INTERNAL');
    expect(link.depositAddress, 'kerosene:wallet:$walletId');
  });

  test('keeps ONCHAIN address issuance behavior by default', () async {
    final apiClient = _PaymentRequestApiClient(walletId: walletId);
    final dataSource = TransactionRemoteDataSourceImpl(apiClient);

    final link = await dataSource.createPaymentLink(
      amount: 0.0001,
      referenceLabel: 'Conta principal',
      metadata: const {'walletName': 'Conta principal'},
    );

    expect(apiClient.postedData?['rail'], 'ONCHAIN');
    expect(apiClient.postedData?['issueFreshAddress'], isTrue);
    expect(link.paymentRail, 'ONCHAIN');
    expect(link.depositAddress, 'tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x');
    expect(link.destinationHash, isNull);
    expect(link.locked, isFalse);
    expect(
      link.paymentUri,
      'bitcoin:tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x'
      '?amount=0.0001&label=Conta+principal',
    );
  });

  test('maps LIGHTNING payment request bolt11 into shareable payload',
      () async {
    final apiClient = _PaymentRequestApiClient(walletId: walletId);
    final dataSource = TransactionRemoteDataSourceImpl(apiClient);
    const bolt11 = 'lntb100n1pkerosenetestinvoiceforfrontend';

    final link = await dataSource.createPaymentLink(
      amount: 0.0001,
      description: 'Lightning receive',
      referenceLabel: 'Conta principal',
      metadata: const {
        'walletName': 'Conta principal',
        'rail': 'LIGHTNING',
      },
    );

    expect(apiClient.postedData?['rail'], 'LIGHTNING');
    expect(apiClient.postedData?.containsKey('issueFreshAddress'), isFalse);
    expect(link.paymentRail, 'LIGHTNING');
    expect(link.isLightningPaymentRequest, isTrue);
    expect(link.paymentRequest, bolt11);
    expect(link.paymentHash, 'hash-lightning-1');
    expect(link.shareablePaymentPayload, bolt11);
    expect(link.paymentUri, bolt11);
  });
}

class _PaymentRequestApiClient implements ApiClient {
  final String walletId;
  String? postedPath;
  Map<String, dynamic>? postedData;

  _PaymentRequestApiClient({required this.walletId});

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'wallets': [
          {
            'walletId': walletId,
            'label': 'Conta principal',
          },
        ],
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    postedPath = path;
    postedData = Map<String, dynamic>.from(data! as Map);
    final rail = postedData!['rail'] as String;
    final internal = rail == 'INTERNAL';
    final lightning = rail == 'LIGHTNING';
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'id': internal
            ? 'private-internal-id'
            : lightning
                ? 'private-lightning-id'
                : 'private-onchain-id',
        'publicId': internal
            ? 'public-internal-id'
            : lightning
                ? 'public-lightning-id'
                : 'public-onchain-id',
        'userId': 7,
        'walletId': walletId,
        'address': internal
            ? 'kerosene:wallet:$walletId'
            : lightning
                ? ''
                : 'tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x',
        if (lightning)
          'paymentRequest': 'lntb100n1pkerosenetestinvoiceforfrontend',
        if (lightning) 'paymentHash': 'hash-lightning-1',
        'rail': rail,
        'status': 'OPEN',
        'amountSats': 10000,
      },
      statusCode: 201,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
