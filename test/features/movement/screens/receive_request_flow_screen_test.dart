import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.text('0.001500 BTC'), findsOneWidget);
    expect(find.text('Endereço'), findsOneWidget);
    expect(find.text('PARTILHAR'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
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

  _PollingReceiveRepository({required this.updates});

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
    return _paymentLink(confirmations: 0, status: 'pending');
  }

  @override
  Future<PaymentLink> getPaymentLink(String requestId) async {
    final index = getPaymentLinkCalls;
    getPaymentLinkCalls++;
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
    throw UnimplementedError();
  }
}
