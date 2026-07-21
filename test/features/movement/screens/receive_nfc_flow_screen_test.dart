import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_nfc_flow_screen.dart';

void main() {
  testWidgets('only reports success after the NFC request is written',
      (tester) async {
    VoidCallback? writtenCallback;
    await _pumpScreen(
      tester,
      writer: ({
        required String paymentRequestUri,
        required VoidCallback onWritten,
        required ValueChanged<String> onError,
      }) async {
        expect(
          paymentRequestUri,
          'kerosene://payment/pay/public-request-id',
        );
        writtenCallback = onWritten;
      },
    );

    expect(find.text('Gravar solicitação'), findsOneWidget);
    expect(find.text('Pedido NFC preparado'), findsNothing);

    writtenCallback!();
    await tester.pump();
    expect(find.text('Solicitação NFC gravada'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Pedido NFC preparado'), findsOneWidget);
    expect(find.text('Aguardando pagamento'), findsWidgets);
    expect(find.text('On-chain'), findsWidgets);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required NfcPaymentRequestWriter writer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: false).copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReceiveNfcFlowScreen(
        wallet: _wallet(),
        onChainWallet: false,
        amountBtc: 0.0042,
        paymentRequestUri: 'kerosene://payment/pay/public-request-id',
        paymentRail: 'ONCHAIN',
        supportsNfc: () async => true,
        startNfcWrite: writer,
      ),
    ),
  );
  await tester.pump();
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
