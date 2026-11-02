import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/movement/domain/entities/tx_status.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_execution_overlay.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';

Widget app(Widget child) => ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('user_receipt_fixture'),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          home: child,
        ));

void main() {
  testWidgets('receipt exposes exact fee alongside reduced display precision',
      (tester) async {
    await tester.pumpWidget(app(const SendPaymentReceiptScreen<bool>(
      result: true,
      data: SendPaymentReceiptData(
        title: 'Envio registrado',
        confirmed: false,
        amountLabel: '< 0,01 BTC',
        secondaryAmountLabel: '0,00150000 BTC',
        occurredAt: null,
        shareText: '',
        rows: [
          SendPaymentReceiptRowData(
              label: 'Taxa de rede',
              value: '< 0,01 BTC',
              secondaryValue: '0,00005000 BTC',
              numeric: true)
        ],
      ),
    )));
    await tester.pump();
    expect(find.text('0,00150000 BTC'), findsOneWidget);
    expect(find.text('0,00005000 BTC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a local recovery failure explains that this attempt was not sent',
      (tester) async {
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => SendPaymentExecutionOverlay.show<TxStatus>(
                        context, onExecute: () async {
                      throw const PaymentRecoveryException(
                          message: 'storage unavailable',
                          errorCode: 'ERR_PAYMENT_RECOVERY_STORAGE');
                    }),
                child: const Text('Enviar'))))));
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Esta tentativa não foi enviada'), findsOneWidget);
    expect(find.textContaining('Confira sua atividade'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('server total debit is authoritative and survives offline serialization',
      () {
    final operation = Transaction.fromJson({
      'id': 'operation',
      'rail': 'ONCHAIN',
      'direction': 'OUTBOUND',
      'status': 'SETTLED',
      'receiverAmountSats': 100000,
      'networkFeeSats': 1000,
      'keroseneFeeSats': 300,
      'totalDebitSats': 100000,
      'createdAt': '2026-10-09T12:00:00Z',
    });
    expect(operation.signedDisplaySatoshis, 100000);
    expect(
        Transaction.fromJson(operation.toJson()).signedDisplaySatoshis, 100000);
  });

  testWidgets(
      'receipt reconciles amounts, zero fees and share text without changing currency',
      (tester) async {
    Map<dynamic, dynamic>? shared;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'share') {
        shared = call.arguments as Map<dynamic, dynamic>;
      }
      return 'success';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(app(SendPaymentReceiptScreen<bool>(
        result: true,
        data: SendPaymentReceiptData(
          title: 'Envio registrado',
          subtitle: 'Aguardando confirmação',
          amountLabel: 'aprox. R\$ 500,00',
          occurredAt: null,
          updatedAt: DateTime.utc(2026, 10, 9, 12),
          confirmed: false,
          transactionId: 'operation',
          shareText: '',
          money: const MovementMoney(
              currency: Currency.brl, locale: Locale('pt'), btcBrl: 500000),
          rows: const [
            SendPaymentReceiptRowData(
                label: 'Taxa de rede',
                value: 'aprox. R\$ 9,00',
                kind: SendPaymentReceiptRowKind.networkFee),
            SendPaymentReceiptRowData(
                label: 'Taxa Kerosene',
                value: 'aprox. R\$ 8,00',
                kind: SendPaymentReceiptRowKind.platformFee),
            SendPaymentReceiptRowData(
                label: 'Total previsto',
                value: 'aprox. R\$ 517,00',
                kind: SendPaymentReceiptRowKind.total),
          ],
        ))));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SendPaymentReceiptScreen<bool>)));
    Transaction operation(TransactionStatus status,
            {required DateTime updatedAt, int fee = 1000}) =>
        Transaction(
          id: 'operation',
          fromAddress: 'alice',
          toAddress: 'maria',
          amountSatoshis: 200000,
          feeSatoshis: fee,
          totalDebitedSatoshis: 200000 + fee,
          hasNetworkFee: true,
          status: status,
          type: TransactionType.withdrawal,
          confirmations: 1,
          timestamp: DateTime.utc(2026, 10, 9, 12),
          updatedAt: updatedAt,
        );
    final history = container.read(lastTransactionHistoryProvider.notifier);
    history.set([
      operation(TransactionStatus.pending,
          updatedAt: DateTime.utc(2026, 10, 9, 12, 1))
    ]);
    await tester.pumpAndSettle();
    expect(find.text('0,00200000 BTC'), findsOneWidget);
    expect(find.text('0,00201000 BTC'), findsOneWidget);
    expect(find.text('0,00001000 BTC'), findsOneWidget);
    expect(find.text('aprox. R\$ 8,00'), findsNothing);
    history.set([
      operation(TransactionStatus.confirmed,
          updatedAt: DateTime.utc(2026, 10, 9, 12, 2), fee: 0)
    ]);
    await tester.pumpAndSettle();
    expect(find.text('0,00200000 BTC'), findsNWidgets(2));
    expect(find.text('0,00000000 BTC'), findsOneWidget);
    expect(find.text('Total debitado'), findsOneWidget);
    // An older cache/reconnect response cannot downgrade the settled receipt.
    history.set([
      operation(TransactionStatus.pending,
          updatedAt: DateTime.utc(2026, 10, 9, 12, 1))
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);
    await tester.tap(find.text('Compartilhar comprovante'));
    await tester.pumpAndSettle();
    expect(shared?['text'], contains('0,00200000 BTC'));
    expect(shared?['text'], isNot(contains('aprox.')));
    expect(shared?['text'], isNot(contains('517,00')));
    expect(shared?['subject'], 'Transferência concluída');
    history.set([
      operation(TransactionStatus.reconciling,
          updatedAt: DateTime.utc(2026, 10, 9, 12, 3))
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('não envie novamente'), findsOneWidget);
    expect(find.text('Concluída'), findsNothing);
    history.set([
      operation(TransactionStatus.cancelled,
          updatedAt: DateTime.utc(2026, 10, 9, 12, 4))
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Esta operação foi cancelada'), findsOneWidget);
    expect(find.text('Total previsto'), findsNothing);
    expect(find.text('Total debitado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('missing status never implies settlement; zero fees are authoritative',
      () {
    final status = TxStatus.fromJson({
      'id': 'operation',
      'receiverAmountSats': 0,
      'grossAmountSats': 1000,
      'networkFeeSats': 0,
      'keroseneFeeSats': 0,
      'platformFeeBtc': 1,
      'createdAt': '2026-10-08T12:00:00Z',
    });
    expect(status.isConfirmed, isFalse);
    expect(status.amountReceived, 0);
    expect(status.hasAmount, isTrue);
    expect(status.networkFeeBtc, 0);
    expect(status.platformFeeBtc, 0);
    expect(status.hasNetworkFee, isTrue);
    expect(status.transactionId, 'operation');
    expect(status.occurredAt, DateTime.utc(2026, 10, 8, 12));
  });

  test('chosen currency and quote are frozen; unavailable quote exposes BTC',
      () {
    const money = MovementMoney(
        currency: Currency.brl, locale: Locale('pt'), btcBrl: 500000);
    expect(money.primary(0.001), '0,00100000 BTC');
    expect(money.secondary(0.001), isEmpty);
    expect(const MovementMoney(currency: Currency.brl).primary(0.001),
        contains('BTC'));
  });

  test('bare KFE timestamps and timezone offsets refer to the same UTC clock',
      () {
    final bare = TxStatus.fromJson({
      'createdAt': '2026-10-09T12:00:00',
      'updatedAt': '2026-10-09T12:01:00'
    });
    final zoned = TxStatus.fromJson({
      'createdAt': '2026-10-09T09:00:00-03:00',
      'updatedAt': '2026-10-09T09:01:00-03:00'
    });
    expect(bare.occurredAt, DateTime.utc(2026, 10, 9, 12));
    expect(bare.updatedAt, zoned.updatedAt);
    expect(bare.occurredAt, zoned.occurredAt);
  });

  testWidgets('execution returns the operation, without claiming confirmation',
      (tester) async {
    const operation = TxStatus(
        txid: 'tx', status: 'EXECUTING', feeSatoshis: 0, amountReceived: 0.001);
    TxStatus? received;
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () async {
                    received = await SendPaymentExecutionOverlay.show<TxStatus>(
                        context,
                        onExecute: () async => operation);
                  },
                  child: const Text('Enviar')),
            ))));
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(identical(received, operation), isTrue);
    expect(received!.isConfirmed, isFalse);
    expect(find.text('Confirmada'), findsNothing);
  });

  testWidgets(
      'authorization refusal shows its cause without claiming uncertainty',
      (tester) async {
    await tester.pumpWidget(app(SendPaymentExecutionOverlay<bool>(
      onExecute: () async => throw const AuthException(
        message: 'Authorization refused',
        statusCode: 403,
        errorCode: 'ERR_AUTH_APP_PIN_INVALID',
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Authorization refused'), findsOneWidget);
    expect(find.text('Resultado em verificação'), findsNothing);
    expect(find.text('Não foi possível concluir esta etapa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'server unavailability preserves uncertainty and explains the cause',
      (tester) async {
    await tester.pumpWidget(app(SendPaymentExecutionOverlay<bool>(
      onExecute: () async => throw const ServerException(
        message: 'O serviço de envio está temporariamente indisponível.',
        statusCode: 503,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Resultado em verificação'), findsOneWidget);
    expect(find.text('O serviço de envio está temporariamente indisponível.'),
        findsOneWidget);
    expect(find.textContaining('Confira sua atividade'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reserve refusal explains the cause and keeps recovery guidance',
      (tester) async {
    var submissions = 0;
    await tester.pumpWidget(app(SendPaymentExecutionOverlay<bool>(
      onExecute: () async {
        submissions++;
        throw const ServerException(
          message:
              'KFE settlement gate rejected the transaction. Failed flags: [V_RESERVA_MAT]',
          statusCode: 409,
          errorCode: 'SYS_001',
        );
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('não conseguiu validar as reservas'),
        findsOneWidget);
    expect(find.textContaining('Confira sua atividade'), findsOneWidget);
    expect(find.textContaining('V_RESERVA_MAT'), findsNothing);
    expect(find.text('Voltar à revisão'), findsOneWidget);
    expect(submissions, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing before the first frame never starts the payment',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () {
                    unawaited(SendPaymentExecutionOverlay.show<TxStatus>(
                        context, onExecute: () async {
                      calls++;
                      return null;
                    }));
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.of(context).pop();
                    });
                  },
                  child: const Text('Enviar')),
            ))));
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(SendPaymentExecutionOverlay<TxStatus>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final cancelled in [true, false]) {
    testWidgets(
        '${cancelled ? 'cancelled' : 'accepted'} execution closes only its own route',
        (tester) async {
      final pending = Completer<TxStatus?>();
      TxStatus? result;
      var finished = false;
      late NavigatorState navigator;
      await tester.pumpWidget(app(Builder(builder: (context) {
        navigator = Navigator.of(context);
        return Scaffold(
            body: TextButton(
                onPressed: () async {
                  result = await SendPaymentExecutionOverlay.show<TxStatus>(
                      context,
                      onExecute: () => pending.future);
                  finished = true;
                },
                child: const Text('Enviar')));
      })));
      await tester.tap(find.text('Enviar'));
      await tester.pump(const Duration(milliseconds: 250));
      unawaited(navigator.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')))));
      await tester.pumpAndSettle();
      const accepted = TxStatus(
          txid: 'operation',
          status: 'EXECUTING',
          feeSatoshis: 0,
          amountReceived: 0.001);
      if (cancelled) {
        pending.completeError(const PaymentAuthorizationCancelledException());
      } else {
        pending.complete(accepted);
      }
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, cancelled ? isNull : same(accepted));
      expect(find.text('Outra tela'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Enviar'), findsOneWidget);
      expect(find.byType(SendPaymentExecutionOverlay<TxStatus>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uncertain execution cannot be replayed inside the overlay',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => SendPaymentExecutionOverlay.show<TxStatus>(
                          context, onExecute: () async {
                        calls++;
                        throw TimeoutException('response lost');
                      }),
                  child: const Text('Enviar')),
            ))));
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.textContaining('Confira sua atividade'), findsOneWidget);
    await tester.tap(find.text('Voltar à revisão'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('review reaches the existing receipt and never executes twice',
      (tester) async {
    var calls = 0;
    var completed = false;
    const operation = TxStatus(
        txid: 'tx', status: 'EXECUTING', feeSatoshis: 0, amountReceived: 0.001);
    await tester.pumpWidget(app(InternalTransferReviewScreen<TxStatus>(
      title: 'Revisar envio',
      amountBtcLabel: '0.001',
      fiatAmountLabel: 'aprox. R\$ 500,00',
      confirmLabel: 'Autorizar',
      rows: const [],
      card: const SendPaymentReviewCardData(
        recipientName: 'Maria',
        recipientAddress: '@maria',
        transferAmountLabel: 'aprox. R\$ 500,00',
        transferFiatLabel: 'BTC 0,00100000',
        totalAmountLabel: 'aprox. R\$ 500,00',
        totalFiatLabel: 'BTC 0,00100000',
        networkLabel: 'Entre contas Kerosene',
        isInternal: true,
      ),
      onConfirm: (_) async {
        calls++;
        return operation;
      },
      receiptBuilder: (_) => const SendPaymentReceiptData(
        title: 'Envio registrado',
        subtitle: 'Aguardando confirmação',
        amountLabel: 'aprox. R\$ 500,00',
        occurredAt: null,
        confirmed: false,
        rows: [],
        shareText: 'Envio registrado',
      ),
      onCompleted: (_) => completed = true,
    )));
    await tester.tap(find.text('Autorizar'));
    await tester.pumpAndSettle();
    expect(find.byType(SendPaymentReceiptScreen<TxStatus>), findsOneWidget);
    expect(find.text('Aguardando confirmação'), findsOneWidget);
    expect(find.text('aprox. R\$ 500,00'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(calls, 1);
  });

  testWidgets('open receipt follows confirmation and cancellation from history',
      (tester) async {
    await tester.pumpWidget(app(const SendPaymentReceiptScreen<bool>(
      result: true,
      data: SendPaymentReceiptData(
        title: 'Envio registrado',
        subtitle: 'Aguardando confirmação',
        amountLabel: 'BTC 0,00100000',
        occurredAt: null,
        confirmed: false,
        transactionId: 'operation',
        rows: [],
        shareText: '',
      ),
    )));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SendPaymentReceiptScreen<bool>)));
    Transaction operation(TransactionStatus status) => Transaction(
          id: 'operation',
          fromAddress: 'alice',
          toAddress: 'maria',
          amountSatoshis: 100000,
          feeSatoshis: 0,
          status: status,
          type: TransactionType.send,
          confirmations: 0,
          timestamp: DateTime.utc(2026, 10, 8, 12),
        );
    container
        .read(lastTransactionHistoryProvider.notifier)
        .set([operation(TransactionStatus.confirmed)]);
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);
    container
        .read(lastTransactionHistoryProvider.notifier)
        .set([operation(TransactionStatus.cancelled)]);
    await tester.pumpAndSettle();
    expect(find.text('Cancelada'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
