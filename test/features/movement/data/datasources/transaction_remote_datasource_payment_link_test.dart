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
    expect(link.depositAddress, 'bcrt1qpaymentrequest');
    expect(link.destinationHash, isNull);
    expect(link.locked, isFalse);
    expect(link.paymentUri, isNull);
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
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'id': internal ? 'private-internal-id' : 'private-onchain-id',
        'publicId': internal ? 'public-internal-id' : 'public-onchain-id',
        'userId': 7,
        'walletId': walletId,
        'address':
            internal ? 'kerosene:wallet:$walletId' : 'bcrt1qpaymentrequest',
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
