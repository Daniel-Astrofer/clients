import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';

void main() {
  final coldWallet = Wallet(
    id: 'cold-1',
    name: 'Electrum Cold',
    address: 'bcrt1qcold',
    walletMode: 'WATCH_ONLY',
    balance: 0.01,
    availableSats: 0,
    observedSats: 1000000,
    derivationPath: "m/84'/0'/0'",
    type: WalletType.nativeSegwit,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
    spendable: false,
  );

  final hotWallet = Wallet(
    id: 'hot-1',
    name: 'Money',
    address: 'bcrt1qhot',
    walletMode: 'CUSTODIAL_ONCHAIN',
    balance: 0.05,
    availableSats: 5000000,
    observedSats: 0,
    derivationPath: "m/84'/0'/0'",
    type: WalletType.nativeSegwit,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  );

  final wallets = [coldWallet, hotWallet];
  final accounts = [
    BitcoinAccount(
      id: 'acc-cold',
      type: 'WATCH_ONLY_COLD_WALLET',
      custody: 'WATCH_ONLY',
      status: 'ACTIVE',
      label: 'Electrum Cold',
      riskTier: 'BRONZE',
      coldWalletId: 'cold-1',
      observedBalanceSats: 1000000,
    ),
    BitcoinAccount(
      id: 'acc-hot',
      type: 'INTERNAL_CARD',
      custody: 'KEROSENE_CUSTODIAL',
      status: 'ACTIVE',
      label: 'Money',
      riskTier: 'BRONZE',
      balanceAvailableSats: 5000000,
    ),
  ];

  Transaction kfeTx({
    required String id,
    required TransactionType type,
    bool isInternal = false,
    bool isLightning = false,
    String? rail,
    String? provider,
    String? walletId,
    String? sourceWalletId,
    String? destinationWalletId,
    String from = '',
    String to = '',
    String? description,
  }) {
    return Transaction(
      id: id,
      fromAddress: from,
      toAddress: to,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      amountSatoshis: 10000,
      feeSatoshis: isInternal ? 0 : 200,
      status: TransactionStatus.confirmed,
      type: type,
      confirmations: isInternal || isLightning ? 0 : 3,
      timestamp: DateTime.utc(2025, 1, 1),
      description: description,
      isInternal: isInternal,
      isLightning: isLightning,
      rail: rail,
      provider: provider,
      hasNetworkFee: !isInternal && !isLightning,
    );
  }

  group('resolveTransactionNetwork', () {
    test('classifies internal ledger', () {
      final tx = kfeTx(
        id: 'i1',
        type: TransactionType.send,
        isInternal: true,
        rail: 'INTERNAL',
        sourceWalletId: 'hot-1',
        destinationWalletId: 'hot-2',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.internal,
      );
    });

    test('classifies cold via provider', () {
      final tx = kfeTx(
        id: 'c1',
        type: TransactionType.withdrawal,
        rail: 'ONCHAIN',
        provider: 'COLD_EXTERNAL_SPEND',
        walletId: 'cold-1',
        sourceWalletId: 'cold-1',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.cold,
      );
    });

    test('classifies cold via wallet id when provider missing', () {
      final tx = kfeTx(
        id: 'c2',
        type: TransactionType.deposit,
        rail: 'ONCHAIN',
        walletId: 'cold-1',
        destinationWalletId: 'cold-1',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.cold,
      );
    });

    test('classifies platform on-chain', () {
      final tx = kfeTx(
        id: 'o1',
        type: TransactionType.deposit,
        rail: 'ONCHAIN',
        provider: 'BITCOIN_CORE',
        walletId: 'hot-1',
        destinationWalletId: 'hot-1',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.onchain,
      );
    });

    test('classifies payment link on-chain', () {
      final tx = kfeTx(
        id: 'pl_abc',
        type: TransactionType.receive,
        rail: 'ONCHAIN',
        provider: 'PAYMENT_LINK',
        description: 'Link de pagamento (on-chain)',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.paymentLinkOnchain,
      );
    });

    test('classifies payment link internal', () {
      final tx = kfeTx(
        id: 'pl_def',
        type: TransactionType.receive,
        isInternal: true,
        rail: 'INTERNAL',
        provider: 'PAYMENT_LINK',
        description: 'Link de pagamento (interno)',
      );
      expect(
        resolveTransactionNetwork(tx, wallets: wallets, accounts: accounts),
        TransactionNetwork.paymentLinkInternal,
      );
    });
  });

  group('party labels', () {
    test('cold debit from resolves wallet name', () {
      final tx = kfeTx(
        id: 'c3',
        type: TransactionType.withdrawal,
        provider: 'COLD_EXTERNAL_SPEND',
        walletId: 'cold-1',
        sourceWalletId: 'cold-1',
        to: 'bcrt1qdestxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      );
      final from = resolveTransactionFromParty(
        tx,
        wallets: wallets,
        accounts: accounts,
      );
      expect(from, 'Electrum Cold');
      expect(
        resolveTransactionNetworkLabel(
          tx,
          wallets: wallets,
          accounts: accounts,
        ),
        contains('Cold'),
      );
    });

    test('credit to own hot wallet', () {
      final tx = kfeTx(
        id: 'o2',
        type: TransactionType.deposit,
        rail: 'ONCHAIN',
        walletId: 'hot-1',
        destinationWalletId: 'hot-1',
        from: 'Rede Bitcoin',
      );
      final to = resolveTransactionToParty(
        tx,
        wallets: wallets,
        accounts: accounts,
      );
      expect(to, 'Money');
    });
  });

  group('KFE json preserves rail/provider', () {
    test('fromJson keeps cold provider and rail', () {
      final tx = Transaction.fromJson({
        'id': 'uuid-1',
        'status': 'SETTLED',
        'rail': 'ONCHAIN',
        'direction': 'OUTBOUND',
        'walletId': 'cold-1',
        'sourceWalletId': 'cold-1',
        'grossAmountSats': 10000,
        'receiverAmountSats': 9800,
        'networkFeeSats': 200,
        'keroseneFeeSats': 0,
        'totalDebitSats': 10000,
        'provider': 'COLD_EXTERNAL_SPEND',
        'externalReference': 'bcrt1qdest',
        'blockchainTxid': 'abc123def456',
        'confirmations': 2,
        'createdAt': '2025-06-01T12:00:00Z',
      });
      expect(tx.provider, 'COLD_EXTERNAL_SPEND');
      expect(tx.rail, 'ONCHAIN');
      expect(tx.isColdProvider, isTrue);
      expect(tx.isDebit, isTrue);
    });
  });
}
