import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_components.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('terminal unpaid requests do not start periodic polling',
      (tester) async {
    _setMobileViewport(tester);
    final link = PaymentLink.fromJson(
        {'id': 'closed-request', 'status': 'EXPIRED', 'amountSats': 150000});
    final repo = _PollingReceiveRepository(updates: [link]);
    await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
    await tester.pump(const Duration(seconds: 6));
    expect(repo.getPaymentLinkCalls, 0);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'session change hides data, stops polling and rejects a late reply even after returning',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final pending = Completer<PaymentLink>();
    final repo = _PollingReceiveRepository(updates: [link], pending: pending);
    await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(link.depositAddress), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    pending.complete(PaymentLink.fromJson({
      'id': link.id,
      'status': 'PAID',
      'settlementStatus': 'SETTLED',
      'amountSats': 150000
    }));
    await tester.pump();
    container.read(_receiveActionOwnerProvider.notifier).change('alice');
    await tester.pump(const Duration(seconds: 6));
    expect(repo.getPaymentLinkCalls, 1);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('a route opened for a different owner never creates a request',
      (tester) async {
    _setMobileViewport(tester);
    final repo = _PollingReceiveRepository(updates: []);
    await tester.pumpWidget(_receiveApp(null,
        repository: repo, owned: true, ownerScope: 'previous-owner'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.createCalls, 0);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('late creation cannot populate a different session',
      (tester) async {
    _setMobileViewport(tester);
    final gate = Completer<PaymentLink>();
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final repo = _PollingReceiveRepository(updates: [link], createGate: gate);
    await tester.pumpWidget(_receiveApp(null, repository: repo, owned: true));
    await tester.pump();
    expect(repo.createCalls, 1);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    gate.complete(link);
    await tester.pump(const Duration(seconds: 3));
    expect(repo.getPaymentLinkCalls, 0);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(link.depositAddress), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('background hides the request and resume retains same-owner data',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    await tester.pumpWidget(_receiveApp(link, owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(link.depositAddress), findsNothing);
    expect(find.textContaining('segundo plano'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(link.depositAddress), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'cancellation dialog blocks duplicate entry and old-account approval',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final repo = _PollingReceiveRepository(updates: [link]);
    await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    final callback = tester
        .widget<IconButton>(
            find.byKey(const ValueKey('receive-cancel-request')))
        .onPressed!;
    callback();
    callback();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(link.id), findsOneWidget);
    final approve = tester
        .widget<TextButton>(
            find.widgetWithText(TextButton, 'Confirmar cancelamento'))
        .onPressed!;
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Confirmar cancelamento'))
            .onPressed,
        isNull);
    approve();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.cancelCalls, 0);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('late cancellation never announces success for another account',
      (tester) async {
    _setMobileViewport(tester);
    final gate = Completer<PaymentLink>();
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final repo = _PollingReceiveRepository(updates: [link], cancelGate: gate);
    await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('receive-cancel-request')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar cancelamento'));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    gate.complete(PaymentLink.fromJson(
        {'id': link.id, 'status': 'CANCELED', 'amountSats': 150000}));
    await tester.pump(const Duration(seconds: 3));
    expect(repo.cancelCalls, 1);
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  for (final sameId in [false, true]) {
    testWidgets(
        'unrecognized cancellation acknowledgement cannot complete: sameId=$sameId',
        (tester) async {
      _setMobileViewport(tester);
      final link = _paymentLink(confirmations: 0, status: 'pending');
      final pending = Completer<PaymentLink>();
      final repo = _PollingReceiveRepository(
          updates: [link],
          pending: pending,
          cancelResult: PaymentLink.fromJson({
            'id': sameId ? link.id : 'different-request',
            'status': 'PAID',
            'settlementStatus': 'SETTLED',
            'amountSats': 150000
          }));
      await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
      await tester.pump(const Duration(milliseconds: 600));
      final callback = tester
          .widget<IconButton>(
              find.byKey(const ValueKey('receive-cancel-request')))
          .onPressed!;
      callback();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Confirmar cancelamento'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.cancelCalls, 1);
      expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.info);
      expect(find.text('Pagamento identificado'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      callback();
      await tester.pump();
      expect(repo.cancelCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      pending.complete(link);
      await tester.pump();
      AppScreenFeedbackBus.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'a status reply for another request is unavailable, not a receipt',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final repo = _PollingReceiveRepository(updates: [
      PaymentLink.fromJson({
        'id': 'different-request',
        'status': 'PAID',
        'settlementStatus': 'SETTLED',
        'amountSats': 150000
      })
    ]);
    await tester.pumpWidget(_receiveApp(link, repository: repo, owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Pagamento identificado'), findsNothing);
    final tr = AppLocalizations.of(
        tester.element(find.byType(ReceiveRequestFlowScreen)))!;
    expect(find.text(tr.receiveStatusUnavailable), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'copy blocks duplicates and ignores a late result after account change',
      (tester) async {
    _setMobileViewport(tester);
    final pending = Completer<void>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        calls++;
        await pending.future;
      }
      return null;
    });
    await tester.pumpWidget(_receiveApp(
        _paymentLink(confirmations: 0, status: 'pending'),
        owned: true));
    await tester.pump(const Duration(milliseconds: 600));
    final button = find.byKey(const ValueKey('receive-address-pill-copy'));
    final callback = tester.widget<IconButton>(button).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(calls, 1);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    pending.complete();
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value, isNull);
    callback();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  for (final status in ShareResultStatus.values) {
    testWidgets('request sharing reflects the platform result: $status',
        (tester) async {
      _setMobileViewport(tester);
      ShareParams? params;
      await tester.pumpWidget(
          _receiveApp(_paymentLink(confirmations: 0, status: 'pending'),
              shareRequest: (value) async {
        params = value;
        return ShareResult('public', status);
      }));
      await tester.pump(const Duration(milliseconds: 600));
      final button = tester.widget<ReceiveActionButton>(
          find.widgetWithText(ReceiveActionButton, 'PARTILHAR'));
      button.onTap!();
      await tester.pumpAndSettle();
      expect(params?.text, isNotEmpty);
      expect(params?.sharePositionOrigin, isNotNull);
      expect(
          AppScreenFeedbackBus.current.value?.type,
          status == ShareResultStatus.dismissed
              ? null
              : status == ShareResultStatus.success
                  ? AppNoticeType.success
                  : AppNoticeType.info);
      AppScreenFeedbackBus.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'receipt sharing uses exact credited money and full identifiers, not a payment URI',
      (tester) async {
    _setMobileViewport(tester);
    final link = PaymentLink.fromJson({
      'id': 'full-receipt-request-123456789',
      'status': 'PAID',
      'settlementStatus': 'SETTLED',
      'amountSats': 150000,
      'receiverAmountSats': 140001,
      'depositAddress': _wallet().address,
      'paymentUri': 'bitcoin:${_wallet().address}?amount=0.0015',
      'txid': 'full-chain-hash-123456789',
      'expiresAt': '2020-01-01T00:00:00Z'
    });
    ShareParams? params;
    await tester.pumpWidget(_receiveApp(link,
        money: const MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2),
        shareRequest: (value) async {
      params = value;
      return const ShareResult('', ShareResultStatus.success);
    }));
    await tester.pump(const Duration(milliseconds: 600));
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'PARTILHAR'));
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(params?.text, contains('Comprovante de recebimento'));
    expect(params?.text, contains('0,00140001 BTC'));
    expect(params?.text, contains('Data do recebimento não informada'));
    expect(params?.text, contains(link.id));
    expect(params?.text, contains(link.txid!));
    expect(params?.text, contains(_wallet().address));
    expect(params?.text, isNot(contains('bitcoin:')));
    AppScreenFeedbackBus.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('sharing exceptions have safe feedback and deliberate retry',
      (tester) async {
    _setMobileViewport(tester);
    var calls = 0;
    await tester.pumpWidget(
        _receiveApp(_paymentLink(confirmations: 0, status: 'pending'),
            shareRequest: (_) async {
      calls++;
      throw StateError('PRIVATE-SHARE');
    }));
    await tester.pump(const Duration(milliseconds: 600));
    final button = find.widgetWithText(ReceiveActionButton, 'PARTILHAR');
    tester.widget<ReceiveActionButton>(button).onTap!();
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
    expect(AppScreenFeedbackBus.current.value?.message,
        isNot(contains('PRIVATE-SHARE')));
    tester.widget<ReceiveActionButton>(button).onTap!();
    await tester.pumpAndSettle();
    expect(calls, 2);
    AppScreenFeedbackBus.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'sharing blocks duplicates and ignores results after an account change',
      (tester) async {
    _setMobileViewport(tester);
    final pending = Completer<ShareResult>();
    var calls = 0;
    await tester.pumpWidget(_receiveApp(
        _paymentLink(confirmations: 0, status: 'pending'),
        owned: true, shareRequest: (_) {
      calls++;
      return pending.future;
    }));
    await tester.pump(const Duration(milliseconds: 600));
    final callback = tester
        .widget<ReceiveActionButton>(
            find.widgetWithText(ReceiveActionButton, 'PARTILHAR'))
        .onTap!;
    callback();
    callback();
    await tester.pump();
    expect(calls, 1);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiveRequestFlowScreen)));
    container.read(_receiveActionOwnerProvider.notifier).change('bob');
    pending.complete(const ShareResult('', ShareResultStatus.success));
    await tester.pumpAndSettle();
    callback();
    expect(calls, 1);
    expect(AppScreenFeedbackBus.current.value, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  for (final useHistory in [false, true]) {
    testWidgets('receipt keeps large integer sats exact: history=$useHistory',
        (tester) async {
      _setMobileViewport(tester);
      final link = PaymentLink.fromJson({
        'id': 'exact-credit',
        'status': useHistory ? 'PENDING' : 'PAID',
        'settlementStatus': useHistory ? 'QUOTED' : 'SETTLED',
        'amountSats': 9007199254740993,
        'receiverAmountSats': 9007199254740993,
      });
      final credit = Transaction(
          id: 'exact-receipt',
          fromAddress: 'Bitcoin',
          toAddress: '',
          amountSatoshis: 9007199254740993,
          feeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.receive,
          confirmations: 6,
          timestamp: DateTime.now(),
          paymentRequestId: link.id);
      await tester.pumpWidget(_receiveApp(link,
          money: const MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2),
          history: useHistory ? [credit] : []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('90071992,54740993 BTC'), findsOneWidget);
      expect(find.textContaining('54741000'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('reduced precision keeps requested and observed BTC exact',
      (tester) async {
    _setMobileViewport(tester);
    final link = PaymentLink.fromJson({
      'id': 'closed-small-request',
      'amountSats': 150000,
      'status': 'EXPIRED',
      'settlementStatus': 'EXPIRED',
      'partialPaymentReceived': 10000,
      'paymentRail': 'ONCHAIN',
    });
    await tester.pumpWidget(_receiveApp(link,
        money: const MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('aprox'), findsNothing);
    expect(find.textContaining('< '), findsNothing);
    expect(find.text('0,00150000 BTC'), findsOneWidget);
    expect(find.text('0,00010000 BTC'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          clipboardText = arguments['text']?.toString();
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final status in ['EXPIRED', 'CANCELED', 'FAILED']) {
    testWidgets(
        '$status request closes without QR or share despite block count',
        (tester) async {
      _setMobileViewport(tester);
      final link = PaymentLink.fromJson({
        'id': 'closed',
        'status': status,
        'terminal': true,
        'amountSats': 150000,
        'confirmations': 6,
        'partialPaymentReceived': 10000,
      });
      await tester.pumpWidget(_receiveApp(link));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('PARTILHAR'), findsNothing);
      expect(find.text('Valor identificado pelo servidor'), findsOneWidget);
      expect(find.textContaining('não comprova'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('six blocks while validating do not produce a receipt',
      (tester) async {
    _setMobileViewport(tester);
    final link = PaymentLink.fromJson({
      'id': 'observed',
      'status': 'PAID',
      'settlementStatus': 'VALIDATING',
      'amountSats': 150000,
      'blockchainTxid': 'txid-1',
      'confirmations': 6,
    });
    await tester.pumpWidget(_receiveApp(link));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Aguardando confirmações (3/3)'), findsOneWidget);
    expect(find.text('Pagamento identificado'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('slow status query never overlaps and pauses in background',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final pending = Completer<PaymentLink>();
    final repository =
        _PollingReceiveRepository(updates: [link], pending: pending);
    await tester.pumpWidget(_receiveApp(link, repository: repository));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(repository.getPaymentLinkCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    pending.complete(link);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(repository.getPaymentLinkCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.getPaymentLinkCalls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  for (final knownAck in [false, true]) {
    testWidgets(
        'confirmed credit survives cancellation reconciliation: $knownAck',
        (tester) async {
      _setMobileViewport(tester);
      final link = _paymentLink(confirmations: 0, status: 'pending');
      final gate = Completer<PaymentLink>();
      final history = Completer<List<Transaction>>();
      final cancelled = PaymentLink.fromJson(
          {'id': link.id, 'status': 'CANCELED', 'amountSats': 150000});
      final repository = _PollingReceiveRepository(
          updates: [link, cancelled], cancelGate: gate);
      await tester.pumpWidget(_receiveApp(link,
          repository: repository, owned: true, historyGate: history));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('receive-cancel-request')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Confirmar cancelamento'));
      await tester.pump();
      history.complete([
        Transaction(
            id: 'received-credit',
            fromAddress: 'Bitcoin',
            toAddress: link.depositAddress,
            amountSatoshis: 140000,
            feeSatoshis: 0,
            status: TransactionStatus.confirmed,
            type: TransactionType.receive,
            confirmations: 6,
            timestamp: DateTime.now(),
            paymentRequestId: link.id)
      ]);
      await tester.pump(const Duration(milliseconds: 600));
      gate.complete(knownAck
          ? cancelled
          : PaymentLink.fromJson({'id': 'wrong-id', 'status': 'CANCELED'}));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('0.00140000 BTC'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Estado do pedido'), findsOneWidget);
      expect(repository.getPaymentLinkCalls, knownAck ? 1 : 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('a late poll cannot reopen a request after cancellation',
      (tester) async {
    _setMobileViewport(tester);
    final link = _paymentLink(confirmations: 0, status: 'pending');
    final pending = Completer<PaymentLink>();
    final repository = _PollingReceiveRepository(
        updates: [link],
        pending: pending,
        cancelResult: PaymentLink.fromJson(
            {'id': link.id, 'status': 'CANCELED', 'amountSats': 150000}));
    await tester.pumpWidget(_receiveApp(link, repository: repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('receive-cancel-request')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar cancelamento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    pending.complete(link);
    await tester.pump();
    expect(find.text('Cobrança cancelada'), findsWidgets);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final confirmed in [false, true]) {
    testWidgets(
        'history only completes an explicitly confirmed credit: $confirmed',
        (tester) async {
      _setMobileViewport(tester);
      final link = _paymentLink(confirmations: 0, status: 'pending');
      final transaction = Transaction(
          id: 'actual-credit',
          fromAddress: 'Bitcoin',
          toAddress: link.depositAddress,
          amountSatoshis: 140000,
          feeSatoshis: 0,
          status: confirmed
              ? TransactionStatus.confirmed
              : TransactionStatus.confirming,
          type: TransactionType.receive,
          confirmations: 6,
          timestamp: DateTime.now(),
          paymentRequestId: link.id,
          blockchainTxid: 'chain-1');
      await tester.pumpWidget(_receiveApp(link, history: [transaction]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      if (confirmed) {
        expect(find.text('0.00140000 BTC'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
      } else {
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Confirmações atingidas; validando crédito'),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final netSats in [0, 140000]) {
    testWidgets(
        'receipt uses actual net amount in both chosen unit and BTC: $netSats',
        (tester) async {
      _setMobileViewport(tester);
      final link = PaymentLink.fromJson({
        'id': 'paid',
        'status': 'PAID',
        'settlementStatus': 'SETTLED',
        'amountSats': 150000,
        'receiverAmountSats': netSats
      });
      await tester.pumpWidget(_receiveApp(link,
          money: const MovementMoney(
              currency: Currency.brl, locale: Locale('pt'), btcBrl: 100000)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(netSats == 0 ? '0,00000000 BTC' : '0,00140000 BTC'),
          findsOneWidget);
      expect(find.text('0.00150000 BTC'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'expired observed payment keeps tracking without payment QR or sharing',
      (tester) async {
    _setMobileViewport(tester);
    final link = PaymentLink.fromJson({
      'id': 'late',
      'status': 'PENDING',
      'settlementStatus': 'VALIDATING',
      'amountSats': 150000,
      'blockchainTxid': 'chain-1',
      'expiresAt': '2020-01-01T00:00:00Z'
    });
    await tester.pumpWidget(_receiveApp(link));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('continua em acompanhamento'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('PARTILHAR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network failure retains confirmation state with visible warning',
      (tester) async {
    _setMobileViewport(tester);
    final link =
        _paymentLink(confirmations: 1, status: 'pending', txid: 'txid-1');
    final repository = _PollingReceiveRepository(updates: [link], fail: true);
    await tester.pumpWidget(_receiveApp(link, repository: repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('último estado foi mantido'), findsOneWidget);
    expect(find.text('Aguardando confirmações (1/3)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'updates on-chain receive confirmation progress while polling',
    (tester) async {
      _setMobileViewport(tester);
      final repository = _PollingReceiveRepository(
        updates: [
          _paymentLink(confirmations: 1, status: 'paid', txid: 'txid-1'),
          _paymentLink(confirmations: 2, status: 'paid', txid: 'txid-1'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageScopeProvider.overrideWithValue(null),
            transactionRepositoryProvider.overrideWithValue(repository),
            transactionHistoryProvider.overrideWith((ref) async => const []),
            externalTransfersProvider.overrideWith((ref) async => const []),
            paymentLinksProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReceiveRequestFlowScreen(
              wallet: _wallet(),
              onChainWallet: true,
              amountBtc: 0.0015,
              method: ReceiveAmountMethod.qrCode,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Aguardando confirmações (1/3)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Aguardando confirmações (2/3)'), findsOneWidget);
      expect(repository.getPaymentLinkCalls, greaterThanOrEqualTo(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('copies raw receive address from the QR address pill', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final wallet = _wallet();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue(null),
          transactionHistoryProvider.overrideWith((ref) async => const []),
          externalTransfersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReceiveRequestFlowScreen(
            wallet: wallet,
            onChainWallet: true,
            amountBtc: 0.0015,
            method: ReceiveAmountMethod.qrCode,
            enableStatusPolling: false,
            initialAddress: wallet.address,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final copyPill = find.byKey(const ValueKey('receive-address-pill-copy'));
    final fullAddress = find.widgetWithText(SelectableText, wallet.address);
    expect(fullAddress, findsOneWidget);
    expect(tester.widget<SelectableText>(fullAddress).maxLines, isNull);
    await tester.ensureVisible(copyPill);
    await tester.tap(copyPill);
    await tester.pump();

    final clipboardData = await Clipboard.getData('text/plain');
    expect(clipboardData?.text, wallet.address);

    // App notice success toast uses a 3s timer — drain before dispose.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows payment details before sharing the receive request', (
    tester,
  ) async {
    _setMobileViewport(tester);
    final wallet = _wallet();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue(null),
          transactionHistoryProvider.overrideWith((ref) async => const []),
          externalTransfersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReceiveRequestFlowScreen(
            wallet: wallet,
            onChainWallet: true,
            amountBtc: 0.0015,
            method: ReceiveAmountMethod.qrCode,
            enableStatusPolling: false,
            initialAddress: wallet.address,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Aponte a câmera do celular'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text(wallet.name), findsOneWidget);
    expect(find.text('Rede'), findsOneWidget);
    expect(find.text('Solicitado'), findsOneWidget);
    expect(find.text('0.00150000 BTC'), findsNWidgets(2));
    expect(find.text('Endereço'), findsOneWidget);
    expect(find.text('PARTILHAR'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('clipboard failure keeps the request and never reports success',
      (tester) async {
    _setMobileViewport(tester);
    AppScreenFeedbackBus.clear();
    addTearDown(AppScreenFeedbackBus.clear);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final link = _paymentLink(confirmations: 0, status: 'pending');
    await tester.pumpWidget(_receiveApp(link));
    await tester.pump(const Duration(milliseconds: 600));
    final copy = find.byKey(const ValueKey('receive-address-pill-copy'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(AppScreenFeedbackBus.current.value?.type, AppNoticeType.error);
    expect(AppScreenFeedbackBus.current.value?.message,
        'Não foi possível copiar estes dados. Tente novamente.');
    expect(
        find.widgetWithText(SelectableText, _wallet().address), findsOneWidget);
    expect(tester.takeException(), isNull);
    AppScreenFeedbackBus.clear();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Wallet _wallet() {
  return Wallet(
    id: 'wallet-1',
    name: 'Reserva principal',
    address: 'bc1qreceiveflow000000000000000000000000000000',
    walletMode: 'SELF_CUSTODY',
    balance: 0.05,
    derivationPath: "m/84'/0'/0'/0/0",
    type: WalletType.nativeSegwit,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

PaymentLink _paymentLink({
  required int confirmations,
  required String status,
  String? txid,
}) {
  return PaymentLink(
    id: 'receive-link-1',
    userId: 1,
    amountBtc: 0.0015,
    description: 'Recebimento via QR',
    depositAddress: 'bc1qreceiveflow000000000000000000000000000000',
    status: status,
    txid: txid,
    paymentRail: 'ONCHAIN',
    confirmations: confirmations,
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    createdAt: DateTime.now(),
  );
}

class _PollingReceiveRepository implements TransactionRepository {
  final List<PaymentLink> updates;
  int getPaymentLinkCalls = 0;
  final Completer<PaymentLink>? pending;
  final bool fail;
  final PaymentLink? cancelResult;
  final Completer<PaymentLink>? createGate;
  final Completer<PaymentLink>? cancelGate;
  int createCalls = 0;
  int cancelCalls = 0;

  _PollingReceiveRepository(
      {required this.updates,
      this.pending,
      this.fail = false,
      this.cancelResult,
      this.createGate,
      this.cancelGate});

  @override
  Future<PaymentLink> createPaymentLink({
    required double amount,
    String? description,
    int? expiresInMinutes,
    String? visibility,
    String? confirmationMode,
    bool amountLocked = true,
    String? referenceLabel,
    Map<String, String>? metadata,
  }) async {
    createCalls++;
    if (createGate != null) return createGate!.future;
    return _paymentLink(confirmations: 0, status: 'pending');
  }

  @override
  Future<PaymentLink> getPaymentLink(String requestId) async {
    final index = getPaymentLinkCalls;
    getPaymentLinkCalls++;
    if (fail) throw StateError('Fixture connection unavailable');
    if (pending != null && index == 0) return pending!.future;
    if (index >= updates.length) {
      return updates.last;
    }
    return updates[index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Transaction> cancelTransaction(String transactionId) async {
    throw UnimplementedError();
  }

  @override
  Future<PaymentLink> cancelPaymentRequest(String requestId) async {
    cancelCalls++;
    if (cancelGate != null) return cancelGate!.future;
    if (cancelResult != null) return cancelResult!;
    throw UnimplementedError();
  }
}

Widget _receiveApp(PaymentLink? link,
        {_PollingReceiveRepository? repository,
        MovementMoney? money,
        bool owned = false,
        String? ownerScope,
        Future<ShareResult> Function(ShareParams)? shareRequest,
        List<Transaction> history = const [],
        Completer<List<Transaction>>? historyGate}) =>
    ProviderScope(
      overrides: [
        sessionStorageScopeProvider.overrideWith(
            (ref) => owned ? ref.watch(_receiveActionOwnerProvider) : null),
        if (shareRequest != null)
          receiveRequestShareProvider.overrideWithValue(shareRequest),
        if (repository != null)
          transactionRepositoryProvider.overrideWithValue(repository),
        transactionHistoryProvider.overrideWith((ref) async =>
            historyGate == null ? history : await historyGate.future),
        externalTransfersProvider.overrideWith((ref) async => const []),
        paymentLinksProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: SnackbarHelper.scaffoldMessengerKey,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReceiveRequestFlowScreen(
            ownerScope: ownerScope,
            wallet: _wallet(),
            onChainWallet: true,
            amountBtc: 0.0015,
            money: money,
            method: ReceiveAmountMethod.qrCode,
            initialPaymentLink: link,
            enableStatusPolling: repository != null),
      ),
    );

final _receiveActionOwnerProvider =
    NotifierProvider<_ReceiveActionOwner, String>(_ReceiveActionOwner.new);

class _ReceiveActionOwner extends Notifier<String> {
  @override
  String build() => 'alice';
  void change(String value) => state = value;
}
