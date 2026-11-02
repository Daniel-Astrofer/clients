import 'package:kerosene/features/security/presentation/widgets/recovery_codes_sheet.dart';
import 'package:kerosene/features/security/presentation/screens/security_totp_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_screen.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_success_scene.dart';
import 'package:kerosene/features/auth/presentation/screens/login_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_wallets_pane.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_details.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/watch_only_import_screen.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show
        sessionStorageScopeProvider,
        AuthOnboardingOutcomeUnknown,
        authControllerProvider;
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_request_flow_screen.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/storybook/storybook_mocks.dart'
    show mockWallets, MockAuthController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:kerosene/features/movement/presentation/send/send_payment_review_args.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/features/movement/presentation/recovery/payment_recovery_panel.dart';
import 'package:kerosene/features/movement/providers/payment_submission_recovery_provider.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/security/presentation/screens/notification_settings_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_display_pane.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/cold_wallet_success_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/wallet_setup_hub_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/seed_word_entry_screen.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  testGoldens(
      'reduced BTC precision keeps amount and fee exact on compact phone',
      (tester) async {
    const money = MovementMoney(locale: Locale('pt'), btcDecimalPlaces: 2);
    await pumpFullScreenGolden(
        tester,
        SendPaymentReceiptScreen<bool>(
          result: true,
          data: SendPaymentReceiptData(
            title: 'Envio registrado',
            subtitle: 'Aguardando confirmação',
            amountLabel: money.primary(0.0015),
            secondaryAmountLabel: money.secondary(0.0015),
            occurredAt: null,
            confirmed: false,
            shareText: '',
            money: money,
            rows: [
              SendPaymentReceiptRowData(
                  label: 'Taxa de rede',
                  value: money.primary(0.00005),
                  secondaryValue: money.secondary(0.00005),
                  numeric: true)
            ],
          ),
        ),
        size: const Size(320, 740));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_receipt_precision_compact');
  });
  testGoldens(
      'security recovery codes keep their action reachable with large text',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(1.7)),
            child: const Scaffold(
                body: RecoveryCodesSheet(ownerScope: 'golden-session', codes: [
              'PUB-0001',
              'PUB-0002',
              'PUB-0003',
              'PUB-0004',
              'PUB-0005',
              'PUB-0006',
              'PUB-0007',
              'PUB-0008',
              'PUB-0009',
              'PUB-0010'
            ]))),
        size: const Size(320, 568));
    await tester.ensureVisible(find.text('Copiar todos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_security_codes_large_text');
  });
  testGoldens('security authenticator preserves its design on a compact screen',
      (tester) async {
    await pumpFullScreenGolden(tester, const SecurityTotpScreen(),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_security_totp_compact');
  });
  testGoldens('unknown signup completion offers login rather than success',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        ProviderScope(overrides: [
          authControllerProvider.overrideWith(() => MockAuthController(
              initialOverride: const AuthOnboardingOutcomeUnknown('alice'))),
        ], child: const SignupFlowScreen()),
        size: const Size(320, 568));
    expect(find.text('Resultado ainda não confirmado'), findsOneWidget);
    expect(find.text('Verificar pelo login'), findsOneWidget);
    expect(find.byType(SignupSuccessScene), findsNothing);
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_signup_unknown_compact');
  });
  testGoldens('auth login stays legible on a compact screen', (tester) async {
    await pumpFullScreenGolden(tester, const LoginScreen(username: 'alice'),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_login_compact');
  });
  testGoldens(
      'auth success scrolls with enlarged text while keeping its action',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.7),
                disableAnimations: true),
            child: Scaffold(
                body: SignupSuccessScene(
                    appTitle: 'Kerosene',
                    title: 'Conta criada',
                    subtitle:
                        'Sua conta foi confirmada. Confira o próximo passo para usar o aplicativo.',
                    actionLabel: 'Continuar',
                    onContinue: () {}))),
        size: const Size(320, 568));
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_signup_success_large_text');
  });

  testGoldens('wallet settings retain known data with a visible sync failure',
      (tester) async {
    final account = BitcoinAccount.fromJson({
      'id': 'wallet-fixture',
      'type': 'INTERNAL_CARD',
      'custody': 'INTERNAL',
      'status': 'ACTIVE',
      'label': 'Reserva principal'
    });
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              bitcoinAccountsProvider.overrideWithValue(AsyncData([account])),
              bitcoinAccountsSyncProvider
                  .overrideWith(_GoldenWalletSyncFailure.new),
            ],
            child: const Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: SettingsWalletsPane()))),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(
        tester, 'financial_wallet_settings_stale_compact');
  });
  testGoldens(
      'wallet name dialog keeps its action reachable on a compact screen',
      (tester) async {
    await pumpFullScreenGolden(
        tester, const WalletNameDialog(initialName: 'Reserva principal'),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_rename_dialog_compact');
  });
  testGoldens('archive dialog identifies wallet and custodial funds guard',
      (tester) async {
    final account = BitcoinAccount.fromJson({
      'id': 'wallet-fixture',
      'type': 'INTERNAL_CARD',
      'custody': 'INTERNAL',
      'status': 'ACTIVE',
      'label': 'Reserva principal',
      'balanceAvailableSats': 1000
    });
    await pumpFullScreenGolden(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => confirmWalletArchive(context, account),
                    child: const Text('Open archive')))),
        size: const Size(320, 568));
    await tester.tap(find.text('Open archive'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_archive_guard_compact');
  });

  for (final closed in [false, true]) {
    testGoldens('receive shows server state on compact screen: $closed',
        (tester) async {
      final link = PaymentLink.fromJson({
        'id': 'visual-request',
        'amountSats': 150000,
        'status': closed ? 'EXPIRED' : 'PAID',
        'settlementStatus': closed ? 'EXPIRED' : 'VALIDATING',
        'blockchainTxid': closed ? null : 'public-test-reference',
        'confirmations': closed ? 0 : 6,
        'partialPaymentReceived': closed ? 10000 : null,
        'address': 'bc1qexample',
        'paymentRail': 'ONCHAIN',
      });
      await pumpFullScreenGolden(
          tester,
          ProviderScope(
              overrides: [
                sessionStorageScopeProvider.overrideWithValue(null),
                transactionHistoryProvider
                    .overrideWith((ref) async => const []),
              ],
              child: ReceiveRequestFlowScreen(
                  wallet: mockWallets.first,
                  onChainWallet: true,
                  amountBtc: 0.0015,
                  method: ReceiveAmountMethod.qrCode,
                  initialPaymentLink: link,
                  enableStatusPolling: false)),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester,
          closed
              ? 'financial_receive_closed_compact'
              : 'financial_receive_validating_compact');
    });
  }

  testGoldens(
      'public wallet form retains complete labels and a reachable action',
      (tester) async {
    await pumpFullScreenGolden(tester, const WatchOnlyImportScreen(),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_public_import_top_compact');
    await tester.ensureVisible(find.text('Importar para consulta'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_public_import_bottom_compact');
  });
  testGoldens(
      'public wallet success is deliberate monitoring without a seed failure warning',
      (tester) async {
    final result = RegisterColdWalletResult(
        walletId: 'public-fixture',
        account: BitcoinAccount.fromJson(
            {'id': 'public-fixture', 'type': 'WATCH_ONLY'}),
        material: const ColdWalletPublicMaterial(
            xpub: 'public-fixture', fingerprint: '73c5da0a'),
        seedStored: false,
        publicOnly: true);
    await pumpFullScreenGolden(tester,
        ColdWalletSuccessScreen(result: result, walletLabel: 'Hardware wallet'),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(
        tester, 'financial_public_wallet_success_compact');
  });
  testGoldens('wallet hub has coherent cards in two columns', (tester) async {
    await pumpFullScreenGolden(tester, const WalletSetupHubScreen(),
        size: const Size(800, 600));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_setup_wide');
  });

  testGoldens('wallet setup keeps complete labels on a compact screen',
      (tester) async {
    await pumpFullScreenGolden(tester, const WalletSetupHubScreen(),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_setup_compact');
  });

  testGoldens('recovery phrase paste screen fits a compact screen',
      (tester) async {
    await pumpFullScreenGolden(tester, const SeedWordEntryScreen(),
        size: const Size(320, 568));
    await tester.tap(find.text('Colar frase'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_seed_paste_compact');
  });

  for (final resolved in [false, true]) {
    testGoldens(
        'recovery keeps the chosen unit and a factual status: $resolved',
        (tester) async {
      final id = resolved ? 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' : null;
      final record = PaymentSubmission(
          key: 'original',
          financial: const {
            'sourceWalletId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'rail': 'INTERNAL',
            'direction': 'INTERNAL',
            'destinationWalletId': 'recipient',
            'amountSats': 100000,
          },
          display: const MovementMoney(
                  currency: Currency.brl, locale: Locale('pt'), btcBrl: 500000)
              .toJournal(),
          createdAt: DateTime.utc(2026, 10, 9, 12),
          transactionId: id);
      await pumpFullScreenGolden(
          tester,
          ProviderScope(
              overrides: [
                pendingPaymentSubmissionsProvider('golden-session')
                    .overrideWith((_) async => [record]),
                paymentSubmissionLookupProvider(
                        ('golden-session', 'original', id))
                    .overrideWith((_) async => resolved
                        ? Transaction(
                            id: id!,
                            fromAddress: 'Alice',
                            toAddress: 'Maria',
                            amountSatoshis: 100000,
                            feeSatoshis: 0,
                            status: TransactionStatus.confirmed,
                            type: TransactionType.send,
                            confirmations: 0,
                            isInternal: true,
                            timestamp: DateTime.utc(2026, 10, 9, 12))
                        : null),
              ],
              child: const Scaffold(
                  body: SafeArea(
                      child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: PaymentRecoveryPanel())))),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await screenMatchesGolden(
          tester,
          resolved
              ? 'financial_recovery_resolved_compact'
              : 'financial_recovery_pending_compact');
    });
  }

  testGoldens('reconciliation explains uncertainty on a small phone',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        ProviderScope(
            overrides: [
              lastTransactionHistoryProvider.overrideWith(_ReceiptHistory.new)
            ],
            child: SendPaymentReceiptScreen<bool>(
                result: true,
                data: SendPaymentReceiptData(
                  title: 'Envio registrado',
                  subtitle: 'Aguardando confirmação',
                  amountLabel: '0,00100000 BTC',
                  occurredAt: null,
                  confirmed: false,
                  transactionId: 'operation',
                  rows: const [],
                  shareText: '',
                  money: const MovementMoney(
                      currency: Currency.brl,
                      locale: Locale('pt'),
                      btcBrl: 500000),
                ))),
        size: const Size(320, 568));
    expect(find.textContaining('não envie novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(
        tester, 'financial_receipt_reconciliation_compact');
  });

  testGoldens('standalone notifications keeps all preferences in one pane',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        ProviderScope(overrides: [
          activeDeviceTokensProvider.overrideWith((_) async => [])
        ], child: const NotificationSettingsScreen()),
        size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(
        tester, 'financial_notification_settings_compact');
  });

  testGoldens('financial review shows exact BTC without a recorded fiat amount',
      (tester) async {
    await pumpFullScreenGolden(
        tester,
        InternalTransferReviewScreen<bool>(
          amountBtcLabel: '0,00100000',
          fiatAmountLabel: '0,00100000 BTC',
          title: 'Revisar envio',
          rows: const [],
          onConfirm: (_) async => null,
          card: const SendPaymentReviewCardData(
            recipientName: 'Maria',
            recipientAddress: '@maria',
            transferAmountLabel: '0,00100000 BTC',
            transferFiatLabel: '',
            totalAmountLabel: '0,00100000 BTC',
            totalFiatLabel: '',
            networkLabel: 'Entre contas Kerosene',
            isInternal: true,
          ),
        ),
        size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_review_brl_compact');
  });

  testGoldens('pending receipt does not use a success mark', (tester) async {
    await pumpFullScreenGolden(
        tester,
        const SendPaymentReceiptScreen<bool>(
          result: true,
          data: SendPaymentReceiptData(
            title: 'Envio registrado',
            subtitle: 'Aguardando confirmação',
            amountLabel: '0,00100000 BTC',
            confirmed: false,
            occurredAt: null,
            shareText: '',
            rows: [
              SendPaymentReceiptRowData(label: 'Destinatário', value: 'Maria'),
              SendPaymentReceiptRowData(
                  label: 'Método', value: 'Bitcoin — rede'),
              SendPaymentReceiptRowData(
                  label: 'Total previsto',
                  value: '0,00100400 BTC',
                  numeric: true),
            ],
          ),
        ),
        size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_receipt_pending_compact');
  });

  testGoldens('display settings preserve the existing design', (tester) async {
    await pumpFullScreenGolden(
        tester,
        const Scaffold(
            body: SafeArea(
          child: SingleChildScrollView(
              padding: EdgeInsets.all(24), child: SettingsDisplayPane()),
        )),
        size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_display_settings_compact');
  });

  testGoldens('wallet without stored seed remains view-only on a small phone',
      (tester) async {
    final result = RegisterColdWalletResult(
      account: BitcoinAccount.fromJson(
          {'id': 'wallet', 'label': 'Minha reserva', 'type': 'WATCH_ONLY'}),
      walletId: 'wallet',
      material: const ColdWalletPublicMaterial(
          xpub: 'public-test', fingerprint: 'test'),
      seedStored: false,
    );
    await pumpFullScreenGolden(tester,
        ColdWalletSuccessScreen(result: result, walletLabel: 'Minha reserva'),
        size: const Size(320, 568));
    expect(find.text('Enviar'), findsNothing);
    expect(find.text('Carteira somente para consulta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenMatchesGolden(tester, 'financial_wallet_view_only_compact');
  });
}

class _ReceiptHistory extends LastTransactionHistoryNotifier {
  @override
  List<Transaction> build() => [
        Transaction(
          id: 'operation',
          fromAddress: 'Minha conta',
          toAddress: 'Maria',
          amountSatoshis: 100000,
          feeSatoshis: 1000,
          serviceFeeSatoshis: 100,
          totalDebitedSatoshis: 101100,
          status: TransactionStatus.reconciling,
          type: TransactionType.withdrawal,
          confirmations: 0,
          timestamp: DateTime.utc(2026, 10, 9, 12),
        )
      ];
}

class _GoldenWalletSyncFailure extends BitcoinAccountsSyncNotifier {
  @override
  AsyncValue<void> build() =>
      const AsyncError(NetworkException(), StackTrace.empty);
}
