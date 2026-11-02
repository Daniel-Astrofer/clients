import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/movement/data/entities/deposit.dart';
import 'package:kerosene/features/movement/data/entities/external_transfer.dart';
import 'package:kerosene/features/movement/data/entities/fee_estimate.dart';
import 'package:kerosene/features/movement/data/entities/onchain_address_allocation.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/data/entities/tx_status.dart';
import 'package:kerosene/features/movement/data/entities/wallet_network_address.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_amount_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_availability_provider.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_flow_screen.dart';

void main() {
  late SharedPreferences preferences;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'app_locale': 'pt',
      'app_currency': 'BRL',
    });
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('shows payment link configuration before generating link',
      (tester) async {
    final repository = _ReceiveAmountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          transactionRepositoryProvider.overrideWithValue(repository),
          latestBtcPriceProvider.overrideWith((ref) => 65000),
          btcEurPriceProvider.overrideWith((ref) => 60000),
          btcBrlPriceProvider.overrideWith((ref) => 350000),
          paymentLinksProvider.overrideWith((ref) async => const []),
          transactionHistoryProvider.overrideWith((ref) async => const []),
          externalTransfersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MovementAmountScreen(
            wallet: _wallet(),
            method: ReceiveAmountMethod.paymentLink,
            onChainWallet: false,
          ),
        ),
      ),
    );

    expect(find.text('Link de pagamento'), findsOneWidget);
    expect(find.text('15 Minutos'), findsOneWidget);
    expect(find.text('1 Hora'), findsOneWidget);
    expect(find.text('24 Horas'), findsOneWidget);
    expect(find.text('Gerar link de pagamento'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('movement-amount-input')),
      '1',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gerar link de pagamento'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('transaction-value-entry-cta-hit-target')),
    );
    await tester.pump(const Duration(milliseconds: 360));

    expect(repository.createPaymentLinkCalls, 1);
    expect(repository.lastExpiresInMinutes, 15);
  });

  testWidgets('creates a backend payment link before opening QR receive flow',
      (tester) async {
    final repository = _ReceiveAmountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          transactionRepositoryProvider.overrideWithValue(repository),
          latestBtcPriceProvider.overrideWith((ref) => 65000),
          btcEurPriceProvider.overrideWith((ref) => 60000),
          btcBrlPriceProvider.overrideWith((ref) => 350000),
          paymentLinksProvider.overrideWith((ref) async => const []),
          transactionHistoryProvider.overrideWith((ref) async => const []),
          externalTransfersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MovementAmountScreen(
            wallet: _wallet(),
            method: ReceiveAmountMethod.qrCode,
            onChainWallet: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('movement-amount-input')),
      '1',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amount-currency-switch')));
    await tester.pump();

    expect(find.text('1,00000000 BTC'), findsOneWidget);

    final continueButton =
        find.byKey(const ValueKey('transaction-value-entry-cta-hit-target'));
    await tester.ensureVisible(continueButton);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));

    expect(repository.createPaymentLinkCalls, 1);
    expect(repository.lastAmount, 1);
    expect(repository.lastMetadata?['rail'], 'ONCHAIN');
    expect(repository.lastMetadata?['method'], 'qrCode');
    expect(find.byType(ReceiveRequestFlowScreen), findsOneWidget);
  });

  testWidgets('creates a public request before starting NFC write',
      (tester) async {
    final repository = _ReceiveAmountRepository();
    String? writtenUri;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          transactionRepositoryProvider.overrideWithValue(repository),
          latestBtcPriceProvider.overrideWith((ref) => 65000),
          btcEurPriceProvider.overrideWith((ref) => 60000),
          btcBrlPriceProvider.overrideWith((ref) => 350000),
          paymentLinksProvider.overrideWith((ref) async => const []),
          transactionHistoryProvider.overrideWith((ref) async => const []),
          externalTransfersProvider.overrideWith((ref) async => const []),
          receiveNfcCompatibilityProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MovementAmountScreen(
            wallet: _wallet(),
            method: ReceiveAmountMethod.nfc,
            onChainWallet: false,
            nfcWriter: ({
              required String paymentRequestUri,
              required VoidCallback onWritten,
              required ValueChanged<String> onError,
            }) async {
              writtenUri = paymentRequestUri;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('movement-amount-input')),
      '1',
    );
    await tester.pump();
    final continueButton =
        find.byKey(const ValueKey('transaction-value-entry-cta'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.createPaymentLinkCalls, 1);
    expect(repository.lastMetadata?['method'], 'nfc');
    expect(writtenUri, 'kerosene://payment/pay/receive-link-1');
    expect(find.text('Gravar solicitação'), findsOneWidget);
  });
  testWidgets(
      'NFC keeps captured precision and exact amount during request creation',
      (tester) async {
    final pendingRequest = Completer<void>();
    final repository = _ReceiveAmountRepository(createGate: pendingRequest);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      transactionRepositoryProvider.overrideWithValue(repository),
      moneyFormatConfigProvider
          .overrideWith((ref) => ref.watch(_precisionProvider)),
      latestBtcPriceProvider.overrideWith((ref) => 65000),
      btcEurPriceProvider.overrideWith((ref) => 60000),
      btcBrlPriceProvider.overrideWith((ref) => 350000),
      paymentLinksProvider.overrideWith((ref) async => const []),
      transactionHistoryProvider.overrideWith((ref) async => const []),
      externalTransfersProvider.overrideWith((ref) async => const []),
      receiveNfcCompatibilityProvider.overrideWith((ref) async => true),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MovementAmountScreen(
          wallet: _wallet(),
          method: ReceiveAmountMethod.nfc,
          onChainWallet: false,
          nfcWriter: (
              {required String paymentRequestUri,
              required VoidCallback onWritten,
              required ValueChanged<String> onError}) async {},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
        find.byKey(const ValueKey('movement-amount-input')), '0.12345678');
    await tester.pump();
    final button = find.byKey(const ValueKey('transaction-value-entry-cta'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    container.read(_precisionProvider.notifier).setPrecision(8);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(repository.createPaymentLinkCalls, 1);
    pendingRequest.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.createPaymentLinkCalls, 1);
    expect(repository.lastAmount, 0.12345678);
    final screen =
        tester.widget<ReceiveNfcFlowScreen>(find.byType(ReceiveNfcFlowScreen));
    expect(screen.money!.btcDecimalPlaces, 2);
    expect(screen.money!.primary(screen.amountBtc), '0,12345678 BTC');
    expect(screen.money!.secondary(screen.amountBtc), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final _precisionProvider =
    NotifierProvider<_PrecisionPreference, MoneyFormatConfig>(
        _PrecisionPreference.new);

class _PrecisionPreference extends Notifier<MoneyFormatConfig> {
  @override
  MoneyFormatConfig build() => const MoneyFormatConfig(
      currency: Currency.btc, locale: Locale('pt'), btcDecimalPlaces: 2);
  void setPrecision(int value) => state = MoneyFormatConfig(
      currency: Currency.btc,
      locale: const Locale('pt'),
      btcDecimalPlaces: value);
}

Wallet _wallet() {
  return Wallet(
    id: 'wallet-1',
    name: 'Carteira Global',
    address: 'kerosene:wallet-1',
    walletMode: 'KEROSENE',
    balance: 0.1,
    derivationPath: "m/84'/0'/0'/0/0",
    type: WalletType.nativeSegwit,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

class _ReceiveAmountRepository implements TransactionRepository {
  final Completer<void>? createGate;
  _ReceiveAmountRepository({this.createGate});
  int createPaymentLinkCalls = 0;
  double? lastAmount;
  Map<String, String>? lastMetadata;
  int? lastExpiresInMinutes;

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
    createPaymentLinkCalls++;
    lastAmount = amount;
    lastMetadata = metadata;
    lastExpiresInMinutes = expiresInMinutes;
    if (createGate != null) await createGate!.future;
    final rail = metadata?['rail'] ?? 'INTERNAL';
    final onChain = rail == 'ONCHAIN';
    return PaymentLink(
      id: 'receive-link-1',
      userId: 1,
      amountBtc: amount,
      description: description ?? '',
      depositAddress: onChain
          ? 'tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x'
          : 'kerosene:wallet-1',
      paymentUri: onChain
          ? 'bitcoin:tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x'
              '?amount=${amount.toStringAsFixed(8)}'
          : 'https://kerosene.test/pay/receive-link-1',
      status: 'pending',
      paymentRail: rail,
      createdAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<PaymentLink> getPaymentLink(String linkId) async {
    final rail = lastMetadata?['rail'] ?? 'INTERNAL';
    final onChain = rail == 'ONCHAIN';
    return PaymentLink(
      id: linkId,
      userId: 1,
      amountBtc: lastAmount ?? 1,
      description: 'Recebimento Carteira Global',
      depositAddress: onChain
          ? 'tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x'
          : 'kerosene:wallet-1',
      paymentUri: onChain
          ? 'bitcoin:tb1q52vwlegjq4duevxfwkjxc07huencvuv3hygt4x'
              '?amount=${(lastAmount ?? 1).toStringAsFixed(8)}'
          : 'https://kerosene.test/pay/$linkId',
      status: 'pending',
      paymentRail: rail,
      createdAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<FeeEstimate> estimateFee(double amount) => throw UnimplementedError();

  @override
  Future<TxStatus> getTransactionStatus(String txid) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, String>> getDepositAddress() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Map<String, String>>> getOnrampUrls() =>
      throw UnimplementedError();

  @override
  Future<List<Deposit>> getDeposits() => throw UnimplementedError();

  @override
  Future<double> getDepositBalance() => throw UnimplementedError();

  @override
  Future<Deposit> getDeposit(String txid) => throw UnimplementedError();

  @override
  Future<List<PaymentLink>> getPaymentLinks() => throw UnimplementedError();

  @override
  Future<Transaction> cancelTransaction(String transactionId) async {
    throw UnimplementedError();
  }

  @override
  Future<PaymentLink> cancelPaymentRequest(String requestId) async {
    throw UnimplementedError();
  }

  @override
  Future<PaymentLink?> lookupPlatformLightningInvoice(
          String invoiceOrHash) async =>
      null;

  @override
  Future<WalletNetworkAddress> getWalletNetworkProfile({
    required String walletName,
  }) =>
      throw UnimplementedError();

  @override
  Future<OnchainAddressAllocation> issueOnchainAddress({
    required String walletName,
    required double expectedAmountBtc,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<ExternalTransfer>> getExternalTransfers() =>
      throw UnimplementedError();

  @override
  Future<ExternalTransfer> getExternalTransfer(String transferId) =>
      throw UnimplementedError();

  @override
  Future<TxStatus> withdraw({
    required String fromWalletName,
    String? toAddress,
    String? paymentRequest,
    required double amount,
    String? totpCode,
    bool isLightning = false,
    double networkFeeBtc = 0,
    int? networkFeeSats,
    int? feeRateSatPerVbyte,
    int? feeTargetBlocks,
    double maxRoutingFeeBtc = 0.000001,
    String? description,
    String? confirmationPassphrase,
    String? passkeyAssertionJson,
    String? idempotencyKey,
    String? appPin,
  }) =>
      throw UnimplementedError();
}
