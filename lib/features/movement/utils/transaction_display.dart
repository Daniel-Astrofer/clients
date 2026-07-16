import 'package:flutter/widgets.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';

/// Single presentation projection for cards + detail screens.
///
/// Raw [Transaction] stays in domain/storage; UI should prefer this facade so
/// titles, parties, network and failure copy stay consistent.
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
  }) {
    final network = resolveTransactionNetwork(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    final note = _userNote(tx);
    final failure = resolveTransactionFailureLabel(context, tx);
    final conf = _confirmationLabel(tx);
    final txid = (tx.blockchainTxid ?? '').trim();

    return TransactionDisplay(
      transaction: tx,
      network: network,
      actionTitle: resolveTransactionActionTitle(
        context,
        tx,
        wallets: wallets,
        accounts: accounts,
      ),
      networkLabel: resolveTransactionNetworkLabel(
        tx,
        wallets: wallets,
        accounts: accounts,
      ),
      ownWalletLabel: resolveOwnWalletLabel(
        tx,
        wallets: wallets,
        accounts: accounts,
      ),
      fromLabel: resolveTransactionFromParty(
        tx,
        wallets: wallets,
        accounts: accounts,
      ),
      toLabel: resolveTransactionToParty(
        tx,
        wallets: wallets,
        accounts: accounts,
        compactHash: true,
      ),
      routeSummary: resolveTransactionRouteSummary(
        tx,
        wallets: wallets,
        accounts: accounts,
        compactHash: true,
      ),
      statusLabel: resolveTransactionStatusLabel(context, tx),
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
  if (tx.confirmations <= 0) return 'Na mempool (0/6)';
  if (tx.confirmations >= tx.onchainConfirmationTarget) {
    return '${tx.confirmations}+';
  }
  return '${tx.confirmations}/${tx.onchainConfirmationTarget}';
}

String resolveTransactionStatusLabel(BuildContext context, Transaction tx) {
  final lang = Localizations.localeOf(context).languageCode;
  if (tx.isUnconfirmedExpired) {
    return switch (lang) {
      'en' => 'Unconfirmed',
      'es' => 'No confirmada',
      _ => 'Não confirmada',
    };
  }
  return switch (tx.displayStatus) {
    TransactionStatus.confirmed => switch (lang) {
        'en' => 'Confirmed',
        'es' => 'Confirmada',
        _ => 'Confirmada',
      },
    TransactionStatus.confirming => switch (lang) {
        'en' => 'Confirming',
        'es' => 'Confirmando',
        _ => 'Confirmando',
      },
    TransactionStatus.pending => switch (lang) {
        'en' => 'Pending',
        'es' => 'Pendiente',
        _ => 'Pendente',
      },
    TransactionStatus.cancelled => switch (lang) {
        'en' => 'Cancelled',
        'es' => 'Cancelada',
        _ => 'Cancelada',
      },
    TransactionStatus.failed => switch (lang) {
        'en' => 'Failed',
        'es' => 'Fallida',
        _ => 'Falhou',
      },
    TransactionStatus.reconciling => switch (lang) {
        'en' => 'Needs review',
        'es' => 'En revisión',
        _ => 'Em revisão',
      },
  };
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

  // Allowlist of known codes — never surface raw server text for unknown codes
  // that might contain internal detail.
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
