import 'package:flutter/widgets.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/utils/transaction_address_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_visuals.dart';

/// Platform network / rail for statement organization.
///
/// Separates funds movement so the user always knows whether money moved on
/// the internal ledger, hot on-chain, cold observe/spend, Lightning, or a
/// payment-link product rail.
enum TransactionNetwork {
  internal,
  cold,
  onchain,
  lightning,
  paymentLinkInternal,
  paymentLinkOnchain,
  unknown,
}

/// Presentation helpers for compact + full transaction detail UIs.
bool looksLikeOnchainAddress(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return false;
  final lower = value.toLowerCase();
  if (lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('bcrt1') ||
      lower.startsWith('lnbc') ||
      lower.startsWith('lntb') ||
      lower.startsWith('lnbcrt')) {
    return true;
  }
  if ((value.startsWith('1') ||
          value.startsWith('3') ||
          value.startsWith('2') ||
          value.startsWith('m') ||
          value.startsWith('n')) &&
      value.length >= 26 &&
      value.length <= 62) {
    return true;
  }
  if (RegExp(r'^[0-9a-fA-F]{40,}$').hasMatch(value)) {
    return true;
  }
  return false;
}

bool looksLikeUsername(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return false;
  if (looksLikeOnchainAddress(value)) return false;
  if (value.contains(' ')) return true;
  if (value.contains('@')) return true;
  if (_looksLikeUuid(value)) return false;
  return value.length <= 32;
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

bool _isGenericWalletPlaceholder(String? raw) {
  final lower = (raw ?? '').trim().toLowerCase();
  if (lower.isEmpty) return true;
  return lower == 'minha carteira' ||
      lower == 'my wallet' ||
      lower == 'wallet' ||
      lower == 'carteira' ||
      lower == 'carteira kerosene' ||
      lower == 'rede bitcoin' ||
      lower == 'bitcoin network' ||
      lower == 'destino' ||
      lower == 'origem';
}

String shortenHash(String value, {int head = 10, int tail = 8}) {
  final normalized = value.trim();
  if (normalized.length <= head + tail + 1) return normalized;
  return '${normalized.substring(0, head)}…${normalized.substring(normalized.length - tail)}';
}

/// Resolve a real wallet/account label from id or name.
String resolveWalletDisplayName(
  String? key, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
  String? apiLabel,
}) {
  // Prefer server-resolved label when present (survives offline after merge).
  final fromApi = apiLabel?.trim() ?? '';
  if (fromApi.isNotEmpty &&
      !_isGenericWalletPlaceholder(fromApi) &&
      !_looksLikeUuid(fromApi) &&
      !looksLikeOnchainAddress(fromApi)) {
    return fromApi;
  }

  final id = key?.trim() ?? '';
  if (id.isEmpty || looksLikeOnchainAddress(id)) return '';

  for (final wallet in wallets) {
    if (wallet.id == id || wallet.name == id) {
      final label = wallet.name.trim();
      if (label.isNotEmpty && !_isGenericWalletPlaceholder(label)) {
        return label;
      }
    }
  }

  for (final account in accounts) {
    if (account.id == id ||
        account.label == id ||
        (account.coldWalletId ?? '') == id) {
      final label = account.label.trim();
      if (label.isNotEmpty && !_isGenericWalletPlaceholder(label)) {
        return label;
      }
      // Fallback custody label only when user never set a custom name.
      final custody = account.custodyDisplayLabel.trim();
      if (custody.isNotEmpty) return custody;
    }
  }

  return '';
}

String _primaryUserWalletName({
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final namedAccounts = accounts
      .where((a) => a.isActive && a.label.trim().isNotEmpty)
      .toList(growable: false);
  if (namedAccounts.length == 1) {
    return namedAccounts.first.label.trim();
  }
  // Prefer internal "global" / assured account label when present.
  for (final account in namedAccounts) {
    if (account.isInternal) {
      return account.label.trim();
    }
  }
  final namedWallets =
      wallets.where((w) => w.name.trim().isNotEmpty).toList(growable: false);
  if (namedWallets.length == 1) {
    return namedWallets.first.name.trim();
  }
  if (namedAccounts.isNotEmpty) {
    return namedAccounts.first.label.trim();
  }
  if (namedWallets.isNotEmpty) {
    return namedWallets.first.name.trim();
  }
  return 'Carteira global';
}

bool isColdWalletKey(
  String? key, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final id = key?.trim() ?? '';
  if (id.isEmpty) return false;
  for (final wallet in wallets) {
    if ((wallet.id == id || wallet.name == id) && wallet.isColdWallet) {
      return true;
    }
  }
  for (final account in accounts) {
    final coldId = (account.coldWalletId ?? '').trim();
    if (coldId.isNotEmpty && coldId == id) return true;
    if (account.id == id && coldId.isNotEmpty) return true;
    if ((account.label == id || account.id == id) && account.isWatchOnly) {
      return true;
    }
  }
  return false;
}

/// Classify which platform network produced this ledger row.
TransactionNetwork resolveTransactionNetwork(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  if (tx.isPaymentLinkInternal) return TransactionNetwork.paymentLinkInternal;
  if (tx.isPaymentLinkOnchain) return TransactionNetwork.paymentLinkOnchain;
  if (tx.isPaymentLink) {
    return tx.isInternal
        ? TransactionNetwork.paymentLinkInternal
        : TransactionNetwork.paymentLinkOnchain;
  }
  if (tx.isLightning) return TransactionNetwork.lightning;
  if (tx.isInternal) return TransactionNetwork.internal;

  if (tx.isColdProvider) return TransactionNetwork.cold;

  final involved = <String?>[
    tx.walletId,
    tx.sourceWalletId,
    tx.destinationWalletId,
  ];
  for (final key in involved) {
    if (isColdWalletKey(key, wallets: wallets, accounts: accounts)) {
      return TransactionNetwork.cold;
    }
  }

  if (tx.isOnChain) return TransactionNetwork.onchain;
  return TransactionNetwork.unknown;
}

/// Own wallet label for this row (the user's side of the movement).
String resolveOwnWalletLabel(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final apiOwn = tx.isCredit
      ? (tx.destinationWalletLabel ?? tx.walletLabel)
      : (tx.sourceWalletLabel ?? tx.walletLabel);
  final fromApi = resolveWalletDisplayName(
    null,
    apiLabel: apiOwn,
  );
  if (fromApi.isNotEmpty) return fromApi;

  final keys = tx.isCredit
      ? <String?>[tx.destinationWalletId, tx.walletId, tx.sourceWalletId]
      : <String?>[tx.sourceWalletId, tx.walletId, tx.destinationWalletId];
  for (final key in keys) {
    final label = resolveWalletDisplayName(
      key,
      wallets: wallets,
      accounts: accounts,
    );
    if (label.isNotEmpty) return label;
  }
  return _primaryUserWalletName(wallets: wallets, accounts: accounts);
}

/// "De" — real wallet name used, never a mock "Minha carteira" / never a hash.
String resolveTransactionFromParty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final network = resolveTransactionNetwork(
    tx,
    wallets: wallets,
    accounts: accounts,
  );

  // Credit (receive): counterparty is external network / peer, not our receive address.
  if (tx.isCredit) {
    final apiCp = (tx.counterpartyLabel ?? '').trim();
    if (apiCp.isNotEmpty &&
        !_isGenericWalletPlaceholder(apiCp) &&
        !_looksLikeUuid(apiCp)) {
      return apiCp;
    }
    final senderName = tx.senderDisplayName?.trim() ?? '';
    if (senderName.isNotEmpty &&
        looksLikeUsername(senderName) &&
        !_isGenericWalletPlaceholder(senderName)) {
      return senderName;
    }

    // Internal peer wallet if resolvable.
    if (network == TransactionNetwork.internal ||
        network == TransactionNetwork.paymentLinkInternal) {
      final peer = resolveWalletDisplayName(
        tx.sourceWalletId,
        wallets: wallets,
        accounts: accounts,
        apiLabel: tx.sourceWalletLabel,
      );
      if (peer.isNotEmpty) return peer;
      if (network == TransactionNetwork.paymentLinkInternal) {
        return 'Pagador (link interno)';
      }
      return 'Kerosene (interno)';
    }

    if (network == TransactionNetwork.lightning) return 'Lightning';
    if (network == TransactionNetwork.paymentLinkOnchain) {
      return 'Pagador (link on-chain)';
    }
    if (network == TransactionNetwork.cold) return 'Rede Bitcoin (cold)';
    return 'Rede Bitcoin (on-chain)';
  }

  // Debit (send): our source wallet — prefer named cold/custodial account.
  final own = resolveWalletDisplayName(
    tx.sourceWalletId ?? tx.walletId,
    wallets: wallets,
    accounts: accounts,
    apiLabel: tx.sourceWalletLabel ?? tx.walletLabel,
  );
  if (own.isNotEmpty) return own;
  final candidates = <String?>[
    tx.sourceWalletId,
    tx.walletId,
  ];
  for (final key in candidates) {
    final label = resolveWalletDisplayName(
      key,
      wallets: wallets,
      accounts: accounts,
    );
    if (label.isNotEmpty) return label;
  }

  final senderName = tx.senderDisplayName?.trim() ?? '';
  if (senderName.isNotEmpty &&
      !looksLikeOnchainAddress(senderName) &&
      !_isGenericWalletPlaceholder(senderName) &&
      !_looksLikeUuid(senderName)) {
    return senderName;
  }

  final from = tx.fromAddress.trim();
  if (from.isNotEmpty &&
      !looksLikeOnchainAddress(from) &&
      !_isGenericWalletPlaceholder(from) &&
      !_looksLikeUuid(from)) {
    return from;
  }

  return resolveOwnWalletLabel(tx, wallets: wallets, accounts: accounts);
}

/// "Para" — username when available; on-chain address shown as hash.
String resolveTransactionToParty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
  bool compactHash = true,
}) {
  final network = resolveTransactionNetwork(
    tx,
    wallets: wallets,
    accounts: accounts,
  );

  // Credit (receive): our destination wallet.
  if (tx.isCredit) {
    final own = resolveWalletDisplayName(
      tx.destinationWalletId ?? tx.walletId,
      wallets: wallets,
      accounts: accounts,
      apiLabel: tx.destinationWalletLabel ?? tx.walletLabel,
    );
    if (own.isNotEmpty) return own;
    return resolveOwnWalletLabel(tx, wallets: wallets, accounts: accounts);
  }

  // Debit (send): external peer / on-chain address / internal destination.
  final apiCp = (tx.counterpartyLabel ?? '').trim();
  if (apiCp.isNotEmpty &&
      !_isGenericWalletPlaceholder(apiCp) &&
      !_looksLikeUuid(apiCp)) {
    if (looksLikeOnchainAddress(apiCp)) {
      return compactHash ? shortenHash(apiCp) : apiCp;
    }
    return apiCp;
  }

  final receiverName = tx.receiverDisplayName?.trim() ?? '';
  if (receiverName.isNotEmpty && looksLikeUsername(receiverName)) {
    return receiverName;
  }

  final toWallet = resolveWalletDisplayName(
    tx.destinationWalletId,
    wallets: wallets,
    accounts: accounts,
    apiLabel: tx.destinationWalletLabel,
  );
  if (toWallet.isNotEmpty) return toWallet;

  if (network == TransactionNetwork.paymentLinkInternal) {
    return 'Destinatário (link interno)';
  }
  if (network == TransactionNetwork.paymentLinkOnchain) {
    final addr = (tx.externalReference ?? tx.toAddress).trim();
    if (addr.isNotEmpty && looksLikeOnchainAddress(addr)) {
      return compactHash ? shortenHash(addr) : addr;
    }
    return 'Endereço do link on-chain';
  }

  final candidates = <String?>[
    tx.externalReference,
    tx.toAddress,
    receiverName,
    resolveTransactionRecipient(tx),
  ];

  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isEmpty || _isGenericWalletPlaceholder(value)) continue;
    if (looksLikeOnchainAddress(value)) {
      return compactHash ? shortenHash(value) : value;
    }
    if (looksLikeUsername(value)) {
      return value;
    }
  }

  if (network == TransactionNetwork.lightning || tx.isLightning) {
    final invoice = tx.lightningInvoice?.trim() ?? '';
    if (invoice.isNotEmpty) {
      return compactHash ? shortenHash(invoice, head: 12, tail: 8) : invoice;
    }
    return 'Invoice Lightning';
  }

  if (network == TransactionNetwork.internal) {
    return 'Carteira Kerosene';
  }

  // Cold / Electrum spend without decoded destination — never show raw txid as "who".
  final memo = (tx.description ?? '').toLowerCase();
  final isColdExternal = memo.contains('electrum') ||
      memo.contains('carteira fria') ||
      memo.contains('detectado');
  if (isColdExternal) {
    return compactHash ? 'Envio off-app' : 'Envio on-chain (fora do app)';
  }

  final txid = tx.blockchainTxid?.trim() ?? '';
  if (txid.isNotEmpty && txid.length >= 16) {
    return compactHash
        ? 'On-chain ${shortenHash(txid)}'
        : 'On-chain · ${shortenHash(txid)}';
  }

  return 'Endereço externo';
}

String resolveTransactionNetworkLabel(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final network = resolveTransactionNetwork(
    tx,
    wallets: wallets,
    accounts: accounts,
  );
  return switch (network) {
    TransactionNetwork.internal => 'Interna (ledger Kerosene)',
    TransactionNetwork.cold => 'Cold wallet (on-chain observada)',
    TransactionNetwork.onchain => 'On-chain (carteira plataforma)',
    TransactionNetwork.lightning => 'Lightning',
    TransactionNetwork.paymentLinkInternal => 'Link de pagamento · interno',
    TransactionNetwork.paymentLinkOnchain => 'Link de pagamento · on-chain',
    TransactionNetwork.unknown => 'Rede desconhecida',
  };
}

/// Compact route line: "Money → tb1q… · Cold" so origin/destination is obvious.
String resolveTransactionRouteSummary(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
  bool compactHash = true,
}) {
  final from = resolveTransactionFromParty(
    tx,
    wallets: wallets,
    accounts: accounts,
  );
  final to = resolveTransactionToParty(
    tx,
    wallets: wallets,
    accounts: accounts,
    compactHash: compactHash,
  );
  final network = resolveTransactionNetworkLabel(
    tx,
    wallets: wallets,
    accounts: accounts,
  );
  if (tx.isCredit) {
    return 'De $from → $to · $network';
  }
  return 'De $from → $to · $network';
}

/// Card / detail title by **action** (Envio/Recebimento + rail/network).
String resolveTransactionActionTitle(
  BuildContext context,
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final tr = context.tr;
  final visual = TransactionVisualSpec.fromTransaction(tx);
  final network = resolveTransactionNetwork(
    tx,
    wallets: wallets,
    accounts: accounts,
  );

  if (tx.isCancelled || visual.family == TransactionVisualFamily.cancelled) {
    return visual.localizedLabel(context);
  }
  if (tx.status == TransactionStatus.failed ||
      visual.family == TransactionVisualFamily.failed) {
    return visual.localizedLabel(context);
  }
  if (tx.status == TransactionStatus.reconciling) {
    return tr.txActionNeedsReview;
  }

  if (tx.isUnconfirmedExpired) {
    return tr.txActionUnconfirmed;
  }

  final isSend = tx.isDebit;

  // Payment link — always explicit about rail (on-chain vs internal).
  if (network == TransactionNetwork.paymentLinkInternal) {
    return isSend
        ? tr.txActionPaymentLinkSendInternal
        : tr.txActionPaymentLinkReceiveInternal;
  }
  if (network == TransactionNetwork.paymentLinkOnchain) {
    return isSend
        ? tr.txActionPaymentLinkSendOnchain
        : tr.txActionPaymentLinkReceiveOnchain;
  }

  // Keep NFC/QR specialized product rails when not payment-link/cold/internal.
  final specialized = visual.family == TransactionVisualFamily.nfc ||
      visual.family == TransactionVisualFamily.qrCode ||
      visual.family == TransactionVisualFamily.fee ||
      visual.family == TransactionVisualFamily.refund ||
      visual.family == TransactionVisualFamily.swap;
  if (specialized) {
    return visual.localizedLabel(context);
  }

  if (network == TransactionNetwork.internal) {
    return isSend ? tr.txActionInternalSend : tr.txActionInternalReceive;
  }
  if (network == TransactionNetwork.lightning) {
    return isSend ? tr.txActionLightningSend : tr.txActionLightningReceive;
  }
  if (network == TransactionNetwork.cold) {
    return isSend ? tr.txActionColdSend : tr.txActionColdReceive;
  }

  // Hot / platform on-chain (custodial). Never label as "Depósito".
  return isSend ? tr.txActionOnchainSend : tr.txActionOnchainReceive;
}

String formatSatsAsBtc(int sats) {
  if (sats == 0) return '0 BTC';
  final btc = sats / 100000000.0;
  var text = btc.toStringAsFixed(8);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return '$text BTC';
}
