import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/app/network/payment_submission_interceptor.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/security/secure_storage_service.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:flutter/material.dart' show Locale;

class MemorySubmissionStorage extends SecureStorageService {
  final data = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? readGate;
  Completer<void>? readStarted;
  @override
  Future<String?> readStrict({required String key}) async {
    if (readStarted != null && !readStarted!.isCompleted) {
      readStarted!.complete();
    }
    await readGate?.future;
    if (failRead) throw StateError('read unavailable');
    return data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrite) throw StateError('write unavailable');
    data[key] = value;
  }
}

Map<String, dynamic> payment(String key,
        {int fee = 100, String destination = 'recipient'}) =>
    {
      'idempotencyKey': key,
      'rail': 'INTERNAL',
      'direction': 'INTERNAL',
      'sourceWalletId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'destinationWalletId': destination,
      'amountSats': 100000,
      'networkFeeSats': fee,
      'memo': 'Pagamento',
      'appPin': 'sensitive-pin',
      'totpCode': 'sensitive-totp',
      'confirmationPassphrase': 'sensitive-passphrase',
      'passkeyAssertionJson': 'sensitive-assertion',
    };

class SubmissionAdapter implements HttpClientAdapter {
  int requests = 0;
  bool loseResponse = false;
  void Function()? onFetch;
  final seenKeys = <String>[];
  static const operationId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    onFetch?.call();
    seenKeys.add((options.data as Map)['idempotencyKey'] as String);
    if (loseResponse) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    }
    return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {'id': operationId, 'status': 'EXECUTING'}
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'an acknowledged result allows a new identical payment; an unseen result must be checked first',
      () async {
    final store = PaymentSubmissionStore(MemorySubmissionStorage());
    await store.begin('user_42', payment('original'));
    await store.accepted('user_42', 'original', SubmissionAdapter.operationId);
    await expectLater(store.begin('user_42', payment('new')),
        throwsA(isA<PaymentRecoveryException>()));
    await store.acknowledgeTransaction(
        'user_42', SubmissionAdapter.operationId);
    expect((await store.begin('user_42', payment('new'))).key, 'new');
    await expectLater(store.acknowledge('user_42', 'new'), throwsStateError);
  });

  test(
      'a session switch during asynchronous token attachment is rejected before HTTP',
      () async {
    var scope = 'user_42';
    final adapter = SubmissionAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(PaymentSubmissionAccountInterceptor(() => scope));
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      await Future<void>.delayed(Duration.zero);
      scope = 'user_7';
      handler.next(options);
    }));
    final store = PaymentSubmissionStore(MemorySubmissionStorage());
    dio.interceptors.add(
        PaymentSubmissionInterceptor(store: store, currentScope: () => scope));
    await expectLater(dio.post('/kfe/transactions', data: payment('original')),
        throwsA(isA<DioException>()));
    expect(adapter.requests, 0);
    expect(await store.load('user_7'), isEmpty);
    dio.close();
  });

  test(
      'a recreated store retains the key and chosen currency, without authorization material',
      () async {
    final storage = MemorySubmissionStorage();
    final first = PaymentSubmissionStore(storage);
    first.rememberDisplay(
        'original',
        const MovementMoney(
                currency: Currency.brl,
                locale: Locale('pt'),
                btcBrl: 500000,
                btcDecimalPlaces: 4)
            .toJournal());
    await first.begin('user_42', payment('original'));
    final next = PaymentSubmissionStore(storage);
    final records = await next.load('user_42');
    expect(records.single.key, 'original');
    final restored = MovementMoney.fromJournal(records.single.display);
    expect(restored.currency, Currency.brl);
    expect(restored.btcDecimalPlaces, 4);
    // A remembered market rate is not a fiat amount registered for this send.
    expect(
        restored.primarySatoshis(records.single.amountSats), '0,00100000 BTC');
    expect(restored.secondary(0.001), isEmpty);
    final retry = await next.begin('user_42', payment('new-review-key'));
    expect(retry.key, 'original');
    expect((await next.load('user_42')), hasLength(1));
    for (final secret in [
      'appPin',
      'totpCode',
      'confirmationPassphrase',
      'passkeyAssertionJson',
      'sensitive-'
    ]) {
      expect(storage.data.values.single, isNot(contains(secret)));
    }
    expect(records.single.toString(), isNot(contains('original')));
  });

  test('storage failures and corruption never overwrite unresolved identities',
      () async {
    final storage = MemorySubmissionStorage();
    final store = PaymentSubmissionStore(storage);
    await store.begin('user_42', payment('original'));
    final previous = storage.data.values.single;
    storage.failRead = true;
    await expectLater(
        store.begin('user_42', payment('other', destination: 'someone-else')),
        throwsStateError);
    expect(storage.data.values.single, previous);
    storage.failRead = false;
    storage.data[storage.data.keys.single] = '{corrupt';
    await expectLater(
        store.begin('user_42', payment('other')), throwsFormatException);
    expect(storage.data.values.single, '{corrupt');
    storage.data[storage.data.keys.single] = previous;
    storage.failWrite = true;
    await expectLater(
        store.begin('user_42', payment('other', destination: 'someone-else')),
        throwsStateError);
    expect(storage.data.values.single, previous);
    storage.failWrite = false;
    expect((await store.load('user_42')).single.key, 'original');
  });

  test('records and concurrent response updates remain isolated by account',
      () async {
    final store = PaymentSubmissionStore(MemorySubmissionStorage());
    await Future.wait([
      store.begin('user_42', payment('a')),
      store.begin('user_42', payment('b', destination: 'other')),
      store.begin('user_7', payment('a'))
    ]);
    await Future.wait([
      store.accepted('user_42', 'a', SubmissionAdapter.operationId),
      store.accepted('user_42', 'b', 'cccccccc-cccc-cccc-cccc-cccccccccccc')
    ]);
    expect(await store.load('user_42'), hasLength(2));
    expect(
        (await store.load('user_42'))
            .every((item) => item.transactionId != null),
        isTrue);
    expect((await store.load('user_7')).single.transactionId, isNull);
    await expectLater(store.acknowledge('user_7', 'a'), throwsStateError);
    await store.acknowledge('user_42', 'a');
    expect((await store.load('user_42')).single.key, 'b');
    expect(await store.load('user_7'), hasLength(1));
  });

  test('changing an unresolved quote cannot create a different payment',
      () async {
    final store = PaymentSubmissionStore(MemorySubmissionStorage());
    await store.begin('user_42', payment('original'));
    await expectLater(
        store.begin('user_42', payment('new', fee: 200)),
        throwsA(isA<PaymentRecoveryException>()
            .having((e) => e.outcomeUncertain, 'uncertain', true)));
    expect(
        (await store.load('user_42')).single.financial['networkFeeSats'], 100);
  });

  test('unsafe display fields and duplicate recovery identities fail closed',
      () async {
    final storage = MemorySubmissionStorage();
    final store = PaymentSubmissionStore(storage);
    expect(() => store.rememberDisplay('original', {'appPin': 'secret'}),
        throwsFormatException);
    await store.begin('user_42', payment('original'));
    final content =
        jsonDecode(storage.data.values.single) as Map<String, dynamic>;
    (content['submissions'] as List)
        .add((content['submissions'] as List).first);
    storage.data[storage.data.keys.single] = jsonEncode(content);
    await expectLater(store.load('user_42'), throwsFormatException);
  });

  test('display precision accepts only the supported integer settings', () {
    for (final precision in [2, 4, 8]) {
      expect(
          PaymentSubmissionStore.displayFacts({'btcDecimalPlaces': precision}),
          {'btcDecimalPlaces': precision});
    }
    for (final precision in [0, -1, 3, 99, 8.0, '2', true]) {
      expect(
          () => PaymentSubmissionStore.displayFacts(
              {'btcDecimalPlaces': precision}),
          throwsFormatException);
    }
  });

  test(
      'lost response and a later explicitly authorized retry transmit the same key',
      () async {
    final storage = MemorySubmissionStorage();
    final adapter = SubmissionAdapter()..loseResponse = true;
    final first = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    first.interceptors.add(PaymentSubmissionInterceptor(
        store: PaymentSubmissionStore(storage), currentScope: () => 'user_42'));
    await expectLater(
        first.post('/kfe/transactions', data: payment('original')),
        throwsA(isA<DioException>()));
    expect(adapter.requests, 1); // the journal itself never resubmits
    first.close();
    adapter.loseResponse = false;
    final nextStore = PaymentSubmissionStore(storage);
    final next = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    next.interceptors.add(PaymentSubmissionInterceptor(
        store: nextStore, currentScope: () => 'user_42'));
    await next.post('/kfe/transactions', data: payment('new-review-key'));
    expect(adapter.seenKeys, ['original', 'original']);
    expect((await nextStore.load('user_42')).single.transactionId,
        SubmissionAdapter.operationId);
    next.close();
  });

  test('a journal write failure prevents all HTTP transmission', () async {
    final adapter = SubmissionAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(PaymentSubmissionInterceptor(
        store:
            PaymentSubmissionStore(MemorySubmissionStorage()..failWrite = true),
        currentScope: () => 'user_42'));
    await expectLater(
        dio.post('/kfe/transactions', data: payment('original')),
        throwsA(isA<DioException>().having(
            (e) => e.error, 'local error', isA<PaymentRecoveryException>())));
    expect(adapter.requests, 0);
    dio.close();
  });

  test(
      'an account change while saving blocks transmission; a late success stays in the original account',
      () async {
    String? scope = 'user_42';
    final storage = MemorySubmissionStorage()
      ..readGate = Completer<void>()
      ..readStarted = Completer<void>();
    final store = PaymentSubmissionStore(storage);
    final adapter = SubmissionAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
        PaymentSubmissionInterceptor(store: store, currentScope: () => scope));
    final request = dio.post('/kfe/transactions', data: payment('original'));
    final expectation = expectLater(request, throwsA(isA<DioException>()));
    await storage.readStarted!.future;
    scope = 'user_7';
    storage.readGate!.complete();
    await expectation;
    expect(adapter.requests, 0);
    scope = 'user_42';
    adapter.onFetch = () => scope = 'user_7';
    await expectLater(
        dio.post('/kfe/transactions', data: payment('original')),
        throwsA(isA<DioException>().having(
            (e) => (e.error as PaymentRecoveryException).outcomeUncertain,
            'late outcome',
            true)));
    expect((await store.load('user_42')).single.transactionId,
        SubmissionAdapter.operationId);
    expect(await store.load('user_7'), isEmpty);
    dio.close();
  });
}
