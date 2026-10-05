import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/movement/data/datasources/transaction_remote_datasource.dart';

void main() {
  test('maps server fee tiers, platform fee, total and settlement estimate',
      () async {
    final apiClient = _FeeQuoteApiClient();
    final dataSource = TransactionRemoteDataSourceImpl(apiClient);

    final fee = await dataSource.estimateFee(0.001);

    expect(apiClient.postedPath, '${AppConfig.kfeTransactions}/quote');
    expect(apiClient.postedData, {
      'rail': 'ONCHAIN',
      'direction': 'OUTBOUND',
      'amountSats': 100000,
      'networkFeeSats': 0,
    });
    expect(fee.fastSatPerByte, 25);
    expect(fee.standardSatPerByte, 12);
    expect(fee.slowSatPerByte, 6);
    expect(fee.estimatedFastBtc, 0.000045);
    expect(fee.estimatedStandardBtc, 0.0000216);
    expect(fee.estimatedSlowBtc, 0.0000108);
    expect(fee.keroseneFeeBtc, 0.000009);
    expect(fee.totalFeeBtc, 0.0000306);
    expect(fee.amountReceived, 0.001);
    expect(fee.totalToSend, 0.0010306);
    expect(fee.estimatedVbytes, 180);
    expect(fee.estimatedConfirmationBlocks, 3);
    expect(fee.fastEstimatedSeconds, 1200);
    expect(fee.standardEstimatedSeconds, 1800);
    expect(fee.slowEstimatedSeconds, 3600);
    expect(fee.feeSource, 'BITCOIN_CORE');
    expect(
      fee.quoteExpiresAt,
      DateTime.parse('2026-07-12T15:02:00Z'),
    );
    expect(fee.serverPriced, isTrue);
  });
}

class _FeeQuoteApiClient implements ApiClient {
  String? postedPath;
  Map<String, dynamic>? postedData;

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
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'grossAmountSats': 100000,
        'receiverAmountSats': 100000,
        'networkFeeSats': 2160,
        'totalDebitSats': 103060,
        'keroseneFeeSats': 900,
        'totalFeeSats': 3060,
        'feeRateSatPerVbyte': 12,
        'estimatedVbytes': 180,
        'estimatedConfirmationBlocks': 3,
        'estimatedSettlementSeconds': 1800,
        'feeSource': 'BITCOIN_CORE',
        'quoteExpiresAt': '2026-07-12T15:02:00Z',
        'feeTiers': [
          {
            'priority': 'FAST',
            'feeRateSatPerVbyte': 25,
            'networkFeeSats': 4500,
            'targetBlocks': 2,
            'estimatedSeconds': 1200,
            'source': 'BITCOIN_CORE',
          },
          {
            'priority': 'STANDARD',
            'feeRateSatPerVbyte': 12,
            'networkFeeSats': 2160,
            'targetBlocks': 3,
            'estimatedSeconds': 1800,
            'source': 'BITCOIN_CORE',
          },
          {
            'priority': 'SLOW',
            'feeRateSatPerVbyte': 6,
            'networkFeeSats': 1080,
            'targetBlocks': 6,
            'estimatedSeconds': 3600,
            'source': 'BITCOIN_CORE',
          },
        ],
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
