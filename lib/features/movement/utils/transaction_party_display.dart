import 'package:flutter/widgets.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/utils/transaction_address_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_visuals.dart';

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
}) {
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

/// "De" — real wallet name used, never a mock "Minha carteira" / never a hash.
String resolveTransactionFromParty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
}) {
  final candidates = <String?>[
    tx.sourceWalletId,
    tx.isDebit ? tx.walletId : null,
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

  // Own wallet side of the movement.
  if (tx.isDebit) {
    return _primaryUserWalletName(wallets: wallets, accounts: accounts);
  }

  if (tx.isLightning) return 'Lightning';
  if (tx.isInternal) {
    return _primaryUserWalletName(wallets: wallets, accounts: accounts);
  }
  return 'Rede Bitcoin';
}

/// "Para" — username when available; on-chain address shown as hash.
String resolveTransactionToParty(
  Transaction tx, {
  List<Wallet> wallets = const [],
  List<BitcoinAccount> accounts = const [],
  bool compactHash = true,
}) {
  final receiverName = tx.receiverDisplayName?.trim() ?? '';
  if (receiverName.isNotEmpty && looksLikeUsername(receiverName)) {
    return receiverName;
  }

  final toWallet = resolveWalletDisplayName(
    tx.destinationWalletId,
    wallets: wallets,
    accounts: accounts,
  );
  if (toWallet.isNotEmpty) return toWallet;

  if (tx.isCredit) {
    final own = resolveWalletDisplayName(
      tx.walletId,
      wallets: wallets,
      accounts: accounts,
    );
    if (own.isNotEmpty) return own;
    return _primaryUserWalletName(wallets: wallets, accounts: accounts);
  }

  final candidates = <String?>[
    tx.toAddress,
    tx.externalReference,
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

  if (tx.isLightning) {
    final invoice = tx.lightningInvoice?.trim() ?? '';
    if (invoice.isNotEmpty) {
      return compactHash ? shortenHash(invoice, head: 12, tail: 8) : invoice;
    }
    return 'Invoice Lightning';
  }

  return 'Destino';
}

String resolveTransactionNetworkLabel(Transaction tx) {
  if (tx.isInternal) return 'Interna (Kerosene)';
  if (tx.isLightning) return 'Lightning';
  return 'Bitcoin on-chain';
}

/// Card / detail title by **action** (Envio/Recebimento + rail).
String resolveTransactionActionTitle(
  BuildContext context,
  Transaction tx,
) {
  final lang = Localizations.localeOf(context).languageCode;
  final visual = TransactionVisualSpec.fromTransaction(tx);

  // Keep specialized product rails (NFC/QR/link/fee/etc.) when available.
  final specialized = visual.family != TransactionVisualFamily.onChain &&
      visual.family != TransactionVisualFamily.internalTransfer &&
      visual.family != TransactionVisualFamily.deposit &&
      visual.family != TransactionVisualFamily.withdrawal &&
      visual.family != TransactionVisualFamily.cancelled &&
      visual.family != TransactionVisualFamily.failed;

  if (specialized) {
    return visual.localizedLabel(context);
  }

  if (tx.isCancelled || visual.family == TransactionVisualFamily.cancelled) {
    return visual.localizedLabel(context);
  }
  if (tx.status == TransactionStatus.failed ||
      visual.family == TransactionVisualFamily.failed) {
    return visual.localizedLabel(context);
  }

  final isSend = tx.isDebit;

  if (tx.isInternal) {
    return switch (lang) {
      'en' => isSend ? 'Internal send' : 'Internal receive',
      'es' => isSend ? 'Envío interno' : 'Recepción interna',
      _ => isSend ? 'Envio Interno' : 'Recebimento Interno',
    };
  }
  if (tx.isLightning) {
    return switch (lang) {
      'en' => isSend ? 'Lightning send' : 'Lightning receive',
      'es' => isSend ? 'Envío Lightning' : 'Recepción Lightning',
      _ => isSend ? 'Envio Lightning' : 'Recebimento Lightning',
    };
  }

  // On-chain (default rail).
  if (tx.type == TransactionType.deposit && !isSend) {
    return switch (lang) {
      'en' => 'Onchain deposit',
      'es' => 'Depósito onchain',
      _ => 'Depósito Onchain',
    };
  }
  if (tx.type == TransactionType.withdrawal ||
      (tx.type == TransactionType.send && isSend)) {
    return switch (lang) {
      'en' => 'Onchain send',
      'es' => 'Envío onchain',
      _ => 'Envio Onchain',
    };
  }
  if (tx.type == TransactionType.receive || !isSend) {
    return switch (lang) {
      'en' => 'Onchain receive',
      'es' => 'Recepción onchain',
      _ => 'Recebimento Onchain',
    };
  }
  return switch (lang) {
    'en' => isSend ? 'Onchain send' : 'Onchain receive',
    'es' => isSend ? 'Envío onchain' : 'Recepción onchain',
    _ => isSend ? 'Envio Onchain' : 'Recebimento Onchain',
  };
}

String formatSatsAsBtc(int sats) {
  if (sats == 0) return '0 BTC';
  final btc = sats / 100000000.0;
  var text = btc.toStringAsFixed(8);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return '$text BTC';
}
