import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';

class NotificationTranslator {
  static String resolveTitle(
      BuildContext? context, SessionNotificationItem item) {
    final tr = context != null
        ? context.tr
        : lookupAppLocalizations(const Locale('pt'));
    if (item.title.trim().isNotEmpty && !_isResourceKey(item.title)) {
      return item.title;
    }

    if (item.kind == SessionNotificationItem.kindAccountCreated) {
      return tr.notifAccountCreatedTitle;
    }
    if (item.kind == SessionNotificationItem.kindSecurityLoginDetected) {
      return tr.notifSecurityLoginDetectedTitle;
    }
    if (item.kind == SessionNotificationItem.kindSecurityAdminAccessAttempt) {
      return tr.notifSecurityAdminAccessAttemptTitle;
    }
    if (item.kind == SessionNotificationItem.kindSecurityRecoveryCompleted) {
      return tr.notifSecurityRecoveryCompletedTitle;
    }

    if (item.kind == SessionNotificationItem.kindTransferReceived ||
        item.kind == SessionNotificationItem.kindDepositConfirmed) {
      return tr.notifTransactionReceivedTitle;
    }

    if (item.kind == SessionNotificationItem.kindTransferSent ||
        item.kind == SessionNotificationItem.kindPaymentSent ||
        item.kind == SessionNotificationItem.kindLightningPaymentSent) {
      return tr.notifTransactionSentTitle;
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestCreated) {
      return tr.notifTransactionInvoiceStatusTitle('criado');
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestPaid ||
        item.kind == SessionNotificationItem.kindLightningInvoicePaid) {
      return tr.notifTransactionInvoiceStatusTitle('pago');
    }

    if (item.kind == SessionNotificationItem.kindDepositDetected) {
      if (item.metadata.containsKey('confirmations') &&
          item.metadata['confirmations'] != '0') {
        return tr.notifTransactionStatusTitle('em confirmação');
      }
      return tr.notifTransactionStatusTitle('pendente');
    }

    if (item.title == 'notification.transaction.cold.outbound.detected.title') {
      return tr.notifTransactionSentTitle;
    }
    if (item.title ==
        'notification.transaction.cold.outbound.confirmed.title') {
      return tr.notifTransactionSentTitle;
    }
    if (item.title == 'notification.transaction.cold.inbound.detected.title') {
      return tr.notifTransactionReceivedTitle;
    }

    return item.title.trim().isEmpty || _isResourceKey(item.title)
        ? tr.notifUntitledNotice
        : item.title;
  }

  static String resolveBody(
      BuildContext? context, SessionNotificationItem item) {
    final tr = context != null
        ? context.tr
        : lookupAppLocalizations(const Locale('pt'));
    if (item.body.trim().isNotEmpty && !_isResourceKey(item.body)) {
      return item.body;
    }

    String field(List<String> names) {
      for (final name in names) {
        final value = item.metadata[name]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }

    final btc = field(['amountBtc']);
    final genericAmount = field(['amount']);
    final genericCurrency = field(['currency', 'ticker']);
    final hasGenericAmount =
        genericAmount.isNotEmpty && genericCurrency.isNotEmpty;
    final sats =
        field(['amountSats', 'creditedSats', 'amount_sats', 'credited_sats']);
    final amount = btc.isNotEmpty
        ? btc
        : hasGenericAmount
            ? genericAmount
            : sats;
    final currency = btc.isNotEmpty
        ? 'BTC'
        : hasGenericAmount
            ? genericCurrency
            : sats.isNotEmpty
                ? 'sats'
                : '';
    final wallet = field(['walletName', 'wallet', 'walletId']);
    var network = field(['rail', 'network']);
    if (network.toUpperCase() == 'INTERNAL' ||
        network.toUpperCase() == 'KEROSENE') {
      network = 'Kerosene (Interna)';
    }
    final address = field(['destination', 'address']);

    String incomplete() =>
        amount.trim().isNotEmpty && currency.trim().isNotEmpty
            ? tr.notifOperationAmountNotice(amount, currency)
            : tr.notifOperationDataIncomplete;

    if (item.kind == SessionNotificationItem.kindAccountCreated) {
      return tr.notifAccountCreatedBody;
    }
    if (item.kind == SessionNotificationItem.kindSecurityLoginDetected) {
      return tr.notifSecurityLoginDetectedBody;
    }
    if (item.kind == SessionNotificationItem.kindSecurityAdminAccessAttempt) {
      return tr.notifSecurityAdminAccessAttemptBody;
    }
    if (item.kind == SessionNotificationItem.kindSecurityRecoveryCompleted) {
      return tr.notifSecurityRecoveryCompletedBody;
    }

    if (item.kind == SessionNotificationItem.kindTransferReceived ||
        item.kind == SessionNotificationItem.kindDepositConfirmed) {
      if ([amount, currency, network, wallet]
          .any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionReceivedBody(amount, currency, network, wallet);
    }

    if (item.kind == SessionNotificationItem.kindTransferSent ||
        item.kind == SessionNotificationItem.kindPaymentSent ||
        item.kind == SessionNotificationItem.kindLightningPaymentSent) {
      if ([amount, currency, network, address]
          .any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionSentBody(network, amount, currency, address);
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestCreated) {
      if ([amount, currency, wallet].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionInvoiceStatusBody(
          amount, currency, 'criado para $wallet');
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestPaid ||
        item.kind == SessionNotificationItem.kindLightningInvoicePaid) {
      if ([amount, currency].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionInvoiceStatusBody(
          amount, currency, 'pago com sucesso');
    }

    if (item.kind == SessionNotificationItem.kindDepositDetected) {
      if ([amount, currency, network].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      if (item.metadata.containsKey('confirmations') &&
          item.metadata['confirmations'] != '0') {
        return tr.notifTransactionStatusBody(
            amount, currency, network, 'confirmando');
      }
      return tr.notifTransactionStatusBody(
          amount, currency, network, 'pendente');
    }

    if (item.body == 'notification.transaction.cold.outbound.detected.body') {
      if ([amount, currency, address].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionSentBody(
          'Cold Wallet', amount, currency, address);
    }
    if (item.body == 'notification.transaction.cold.outbound.confirmed.body') {
      if ([amount, currency, address].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionSentBody(
          'Cold Wallet', amount, currency, address);
    }
    if (item.body == 'notification.transaction.cold.inbound.detected.body') {
      if ([amount, currency, wallet].any((value) => value.trim().isEmpty)) {
        return incomplete();
      }
      return tr.notifTransactionReceivedBody(
          amount, currency, 'Cold Wallet', wallet);
    }

    return _isResourceKey(item.body) || item.body.trim().isEmpty
        ? incomplete()
        : item.body;
  }

  static bool _isResourceKey(String text) =>
      RegExp(r'^notification\.[a-zA-Z0-9_.]+\.(title|body)$')
          .hasMatch(text.trim());
}
