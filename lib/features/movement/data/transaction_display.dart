import 'package:flutter/widgets.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/data/transaction_party_display.dart';

/// Single presentation projection for cards + detail screens.
///
/// Delegates title/network/route/status to [TransactionPresentation] so Home,
/// Extrato and legacy list paths stay aligned.
class TransactionDisplay {
  final Transaction transaction;
  final TransactionNetwork network;
  final String actionTitle;
  final String networkLabel;
  final String ownWalletLabel;
  final String fromLabel;
  final String toLabel;
  final String routeSummary;
  final String statusLabel;
  final String? confirmationLabel;
  final String? noteLabel;
  final String? failureLabel;
  final bool canCopyTxid;
  final String? blockchainTxid;

  const TransactionDisplay({
    required this.transaction,
    required this.network,
    required this.actionTitle,
    required this.networkLabel,
    required this.ownWalletLabel,
    required this.fromLabel,
    required this.toLabel,
    required this.routeSummary,
    required this.statusLabel,
    this.confirmationLabel,
    this.noteLabel,
    this.failureLabel,
    required this.canCopyTxid,
    this.blockchainTxid,
  });

  factory TransactionDisplay.resolve(
    BuildContext context,
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
    Currency displayCurrency = Currency.btc,
    double? btcUsd,
    double? btcEur,
    double? btcBrl,
    Locale? appLocale,
  }) {
    final presentation = TransactionPresentation.fromTransaction(
      context,
      tx,
      wallets: wallets,
      accounts: accounts,
      displayCurrency: displayCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: appLocale,
    );
    final network = resolveTransactionNetwork(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    final note = _userNote(tx);
    final failure = resolveTransactionFailureLabel(context, tx);
    final conf = _confirmationLabel(tx);
    final txid = (tx.blockchainTxid ?? '').trim();
    final lang = Localizations.localeOf(context).languageCode;

    return TransactionDisplay(
      transaction: tx,
      network: network,
      actionTitle: presentation.title,
      networkLabel: TransactionPresentationCopy.of(context)
          .railShort(presentation.axes.rail),
      ownWalletLabel: resolveOwnWalletLabel(
        tx,
        wallets: wallets,
        accounts: accounts,
        languageCode: lang,
      ),
      fromLabel: resolveTransactionFromParty(
        tx,
        wallets: wallets,
        accounts: accounts,
        languageCode: lang,
      ),
      toLabel: resolveTransactionToParty(
        tx,
        wallets: wallets,
        accounts: accounts,
        compactHash: true,
        languageCode: lang,
      ),
      // Prefer short counterparty line over "De A → B · long network".
      routeSummary: presentation.subtitle,
      statusLabel: presentation.statusLabel,
      confirmationLabel: conf,
      noteLabel: note,
      failureLabel: failure,
      canCopyTxid: txid.length >= 16,
      blockchainTxid: txid.isEmpty ? null : txid,
    );
  }
}

String? _userNote(Transaction tx) {
  final d = (tx.description ?? '').trim();
  if (d.isEmpty) return null;
  final lower = d.toLowerCase();
  // System-generated placeholders — not user notes.
  if (lower.contains('mempool') ||
      lower.contains('aguardando confirma') ||
      lower.contains('detectada') ||
      lower.contains('link de pagamento') ||
      lower.contains('payment link') ||
      lower == 'transfer' ||
      lower == 'transferência' ||
      lower == 'transferencia') {
    return null;
  }
  return d;
}

String? _confirmationLabel(Transaction tx) {
  if (!tx.showsOnchainConfirmations) return null;
  if (tx.confirmations <= 0) return '0/${tx.onchainConfirmationTarget}';
  if (tx.confirmations >= tx.onchainConfirmationTarget) {
    return '${tx.confirmations}+';
  }
  return '${tx.confirmations}/${tx.onchainConfirmationTarget}';
}

String resolveTransactionStatusLabel(BuildContext context, Transaction tx) {
  final axes = TransactionAxes.classify(tx);
  return TransactionPresentationCopy.of(context).lifecycleLabel(axes.lifecycle);
}

/// Maps backend [failureCode] / status to a safe localized message.
/// Never returns raw stack traces or file paths.
String? resolveTransactionFailureLabel(BuildContext context, Transaction tx) {
  final lang = Localizations.localeOf(context).languageCode;
  final code = (tx.failureCode ?? '').trim().toUpperCase();
  if (code.isEmpty &&
      tx.status != TransactionStatus.failed &&
      !tx.isUnconfirmedExpired) {
    return null;
  }

  if (tx.isUnconfirmedExpired) {
    return switch (lang) {
      'en' => 'Not confirmed on-chain within 24 hours.',
      'es' => 'No confirmada en la red en 24 horas.',
      _ => 'Não confirmada na rede em 24 horas.',
    };
  }

  if (code.isEmpty) {
    return switch (lang) {
      'en' => 'This movement could not be completed.',
      'es' => 'No se pudo completar este movimiento.',
      _ => 'Não foi possível concluir esta movimentação.',
    };
  }

  return switch (code) {
    'LEDGER_001' ||
    'INSUFFICIENT_FUNDS' ||
    'ERR_INSUFFICIENT_BALANCE' =>
      switch (lang) {
        'en' => 'Insufficient balance.',
        'es' => 'Saldo insuficiente.',
        _ => 'Saldo insuficiente.',
      },
    'LEDGER_009' || 'SELF_PAY' => switch (lang) {
        'en' => 'You cannot pay your own payment link.',
        'es' => 'No puedes pagar tu propio enlace.',
        _ => 'Você não pode pagar o próprio link de pagamento.',
      },
    'EXPIRED' || 'LINK_EXPIRED' => switch (lang) {
        'en' => 'This payment request expired.',
        'es' => 'Esta solicitud de pago expiró.',
        _ => 'Esta solicitação de pagamento expirou.',
      },
    'CANCELLED' || 'CANCELED' => switch (lang) {
        'en' => 'This movement was cancelled.',
        'es' => 'Este movimiento fue cancelado.',
        _ => 'Esta movimentação foi cancelada.',
      },
    'NETWORK' || 'BROADCAST_FAILED' || 'RPC_ERROR' => switch (lang) {
        'en' => 'Network error while broadcasting the transaction.',
        'es' => 'Error de red al transmitir la transacción.',
        _ => 'Erro de rede ao transmitir a transação.',
      },
    'REQUIRES_RECONCILIATION' => switch (lang) {
        'en' => 'This movement needs manual review.',
        'es' => 'Este movimiento necesita revisión manual.',
        _ => 'Esta movimentação precisa de revisão manual.',
      },
    _ => switch (lang) {
        'en' => 'This movement could not be completed ($code).',
        'es' => 'No se pudo completar este movimiento ($code).',
        _ => 'Não foi possível concluir esta movimentação ($code).',
      },
  };
}
