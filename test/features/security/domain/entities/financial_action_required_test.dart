import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/security/financial_payment_challenge.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/security/domain/entities/passkey_action_required.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _challenge() => Map<String, dynamic>.from(
      (jsonDecode(
          File('../contracts/test-vectors/financial-payment-approval-v1.json')
              .readAsStringSync()) as Map)['challenge'] as Map,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'send signs the financial challenge and keeps its operation key on retry',
      () async {
    final prefix = keroseneSecurePrefix();
    SharedPreferences.setMockInitialValues({
      'device_install_id_${keroseneProfileTag()}': 'install-test',
    });
    FlutterSecureStorage.setMockInitialValues({
      '${prefix}device_key_active_credential.YWxpY2U': 'credential-test',
      '${prefix}device_key_seed.YWxpY2U.credential-test':
          base64.encode(List<int>.generate(32, (i) => i)),
      '${prefix}device_key_counter.YWxpY2U.credential-test': '6',
    });
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final repository = _RejectedSendRepository({
      'action': FinancialPaymentChallenge.action,
      'financialChallenge': {
        ..._challenge(),
        'issuedAtEpochSeconds': now - 1,
        'expiresAtEpochSeconds': now + 90,
      },
    });
    final container = ProviderContainer(overrides: [
      transactionRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(_AuthenticatedController.new),
    ]);
    addTearDown(container.dispose);
    // The fake server returns the same challenge twice; bounded retry must stop.
    final result = await container.read(sendTransactionProvider.notifier).send(
          toAddress: 'test-address',
          amount: 0.001,
          feeSatoshis: 10,
          appPin: '1234',
        );
    expect(result, isNull);
    expect(repository.calls, 2);
    expect(repository.keys.first, isNotEmpty);
    expect(repository.keys.toSet().length, 1);
    expect(repository.assertions.first, isNull);
    final proof = jsonDecode(repository.assertions.last!) as Map;
    expect(proof['type'], 'FINANCIAL_DEVICE_KEY');
    final payload = jsonDecode(proof['signedPayload'] as String) as Map;
    expect(payload['challengeId'], _challenge()['challengeId']);
    expect(payload['bindingHash'], _challenge()['bindingHash']);
    expect(payload['counter'], 7);
    expect(container.read(sendTransactionProvider).isLoading, isFalse);
  });

  test('financial challenge remains financial inside a mixed legacy envelope',
      () {
    final action = PasskeyActionRequired.fromErrorPayload({
      'challenge': 'login-challenge',
      'data': {
        'action': FinancialPaymentChallenge.action,
        'financialChallenge': _challenge(),
        'challenge': 'legacy',
        'acceptedFactors': ['PASSKEY', 'DEVICE_KEY'],
      },
    })!;
    expect(action.isFinancialApproval, isTrue);
    expect(action.hasUsableStepUp, isTrue);
    expect(action.financialChallenge?.challengeId, _challenge()['challengeId']);
    expect(action.challengeFor('DEVICE_KEY'), isNull);
    expect(action.legacyOrPasskeyChallenge, isNull);
    expect(action.acceptedFactors, isEmpty);
  });

  final malformed = <String, Map<String, dynamic>>{
    'missing challenge': {'action': FinancialPaymentChallenge.action},
    'unknown version': {
      'action': FinancialPaymentChallenge.action,
      'financialChallenge': {..._challenge(), 'version': 2},
    },
    'generic purpose': {
      'action': FinancialPaymentChallenge.action,
      'financialChallenge': {..._challenge(), 'purpose': 'AUTH_DEVICE_KEY'},
    },
    'unknown action': {
      'action': 'ASSERT_PASSKEY',
      'financialChallenge': _challenge()
    },
    'code only': {'errorCode': FinancialPaymentChallenge.errorCode},
    'null challenge': {'financialChallenge': null},
  };
  for (final entry in malformed.entries) {
    test('${entry.key} cannot downgrade to generic authentication', () {
      final action = PasskeyActionRequired.fromErrorPayload({
        'challenge': 'outer-login',
        'data': {...entry.value, 'challenge': 'inner-login'},
      })!;
      expect(action.isFinancialApproval, isTrue);
      expect(action.hasUsableStepUp, isFalse);
      expect(action.financialChallenge, isNull);
      expect(action.legacyOrPasskeyChallenge, isNull);
    });
  }

  for (final data in [
    null,
    {'action': FinancialPaymentChallenge.action}
  ]) {
    test(
        'send stops on malformed financial challenge without login fallback: $data',
        () async {
      final repository = _RejectedSendRepository(data);
      final container = ProviderContainer(overrides: [
        transactionRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(_AuthenticatedController.new),
      ]);
      addTearDown(container.dispose);
      final result =
          await container.read(sendTransactionProvider.notifier).send(
                toAddress: 'test-address',
                amount: 0.001,
                feeSatoshis: 10,
                appPin: '1234',
                idempotencyKey: ' operation-key ',
              );
      expect(result, isNull);
      expect(repository.calls, 1);
      expect(repository.key, ' operation-key ');
      final state = container.read(sendTransactionProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('ERR_KFE_PAYMENT_CHALLENGE_INVALID'));
      expect(state.error, isNot(contains('login-challenge')));
    });
  }
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(User(
        id: '41',
        username: 'alice',
        createdAt: DateTime(2026, 1, 1),
      ));
}

class _RejectedSendRepository implements TransactionRepository {
  final Object? data;
  int calls = 0;
  String? key;
  final keys = <String?>[];
  final assertions = <String?>[];
  _RejectedSendRepository(this.data);

  @override
  Future<TxStatus> sendTransaction({
    required String toAddress,
    required double amount,
    required int feeSatoshis,
    String? fromWalletId,
    String? fromAddress,
    String? context,
    String? passkeyAssertionJson,
    String? confirmationPassphrase,
    String? totpCode,
    String? idempotencyKey,
    int? requestTimestamp,
    String? appPin,
  }) async {
    calls++;
    key = idempotencyKey;
    keys.add(idempotencyKey);
    assertions.add(passkeyAssertionJson);
    throw ServerException(
      message: 'PASSKEY_CHALLENGE_REQUIRED:login-challenge',
      statusCode: 428,
      errorCode: FinancialPaymentChallenge.errorCode,
      data: data,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
