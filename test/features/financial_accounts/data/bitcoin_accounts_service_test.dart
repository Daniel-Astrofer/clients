import 'package:dio/dio.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/features/financial_accounts/data/bitcoin_accounts_service.dart';
import 'package:test/test.dart';

void main() {
  test(
      'public wallet import sends only public registration data and requests receiving address',
      () async {
    final client = _PublicImportClient();
    final result = await RemoteBitcoinAccountsService(client).importColdWallet(
        label: ' Hardware ',
        xpub: ' public-key ',
        fingerprint: ' 73c5da0a ',
        derivationPath: " m/84'/0'/0' ",
        scriptPolicy: ' wpkh(public-key/0/*) ');
    expect(client.path, AppConfig.kfeWallets);
    expect(client.payload, {
      'kind': 'WATCH_ONLY',
      'label': 'Hardware',
      'xpub': 'public-key',
      'fingerprint': '73c5da0a',
      'derivationPath': "m/84'/0'/0'",
      'descriptor': 'wpkh(public-key/0/*)',
      'issueInitialAddress': true
    });
    expect(result.id, 'server-wallet');
    expect(result.coldWalletId, 'server-wallet');
    expect(result.isWatchOnly, isTrue);
  });

  test('builds KFE create wallet payload with explicit label and custody', () {
    expect(
      RemoteBitcoinAccountsService.kfeCreateWalletPayload(
        label: 'Reserva familiar',
        custody: BitcoinAccountCustody.internal,
      ),
      {
        'kind': 'INTERNAL',
        'label': 'Reserva familiar',
        'issueInitialAddress': false,
      },
    );

    expect(
      RemoteBitcoinAccountsService.kfeCreateWalletPayload(
        label: 'Cofre on-chain',
        custody: BitcoinAccountCustody.custodialOnchain,
      ),
      {
        'kind': 'CUSTODIAL_ONCHAIN',
        'label': 'Cofre on-chain',
        'issueInitialAddress': false,
      },
    );
  });

  test('maps KFE dashboard active address to receive request', () {
    final requests =
        RemoteBitcoinAccountsService.receiveRequestsFromKfeDashboard(
      const {
        'wallets': [
          {
            'walletId': 'wallet-1',
            'activeAddress': ' bcrt1qactive0000000000000000000000000000000 ',
            'updatedAt': '2026-06-15T12:30:00Z',
          },
        ],
      },
      'wallet-1',
    );

    expect(requests, hasLength(1));
    expect(requests.single.id,
        'kfe:wallet-1:bcrt1qactive0000000000000000000000000000000');
    expect(requests.single.accountId, 'wallet-1');
    expect(
        requests.single.address, 'bcrt1qactive0000000000000000000000000000000');
    expect(requests.single.bip21,
        'bitcoin:bcrt1qactive0000000000000000000000000000000');
    expect(requests.single.createdAt, DateTime.parse('2026-06-15T12:30:00Z'));
  });

  test('returns no receive requests when KFE wallet has no active address', () {
    final requests =
        RemoteBitcoinAccountsService.receiveRequestsFromKfeDashboard(
      const {
        'wallets': [
          {'walletId': 'wallet-1', 'activeAddress': ''},
        ],
      },
      'wallet-1',
    );

    expect(requests, isEmpty);
  });

  test('maps KFE validating receive request status from settlement state', () {
    expect(
      RemoteBitcoinAccountsService.receiveRequestStatusFromKfe(
        const {'status': 'OPEN', 'settlementStatus': 'VALIDATING'},
      ),
      'MEMPOOL_SEEN',
    );

    expect(
      RemoteBitcoinAccountsService.receiveRequestStatusFromKfe(
        const {
          'status': 'OPEN',
          'settlementStatus': 'VALIDATING',
          'confirmations': 1,
        },
      ),
      'CONFIRMING',
    );
  });
}

class _PublicImportClient implements ApiClient {
  String? path;
  Map<String, dynamic>? payload;
  @override
  Future<Response> post(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers,
      Options? options}) async {
    this.path = path;
    payload = Map<String, dynamic>.from(data as Map);
    return Response(requestOptions: RequestOptions(path: path), data: {
      'id': 'server-wallet',
      'kind': 'WATCH_ONLY',
      'status': 'ACTIVE',
      'label': 'Hardware'
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
