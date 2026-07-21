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

    if (item.kind == SessionNotificationItem.kindAccountCreated)
      return tr.notifAccountCreatedTitle;
    if (item.kind == SessionNotificationItem.kindSecurityLoginDetected)
      return tr.notifSecurityLoginDetectedTitle;
    if (item.kind == SessionNotificationItem.kindSecurityAdminAccessAttempt)
      return tr.notifSecurityAdminAccessAttemptTitle;
    if (item.kind == SessionNotificationItem.kindSecurityRecoveryCompleted)
      return tr.notifSecurityRecoveryCompletedTitle;

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

    if (item.title == 'notification.transaction.cold.outbound.detected.title')
      return tr.notifTransactionSentTitle;
    if (item.title == 'notification.transaction.cold.outbound.confirmed.title')
      return tr.notifTransactionSentTitle;
    if (item.title == 'notification.transaction.cold.inbound.detected.title')
      return tr.notifTransactionReceivedTitle;

    return item.title;
  }

  static String resolveBody(
      BuildContext? context, SessionNotificationItem item) {
    final tr = context != null
        ? context.tr
        : lookupAppLocalizations(const Locale('pt'));

    final amount = item.metadata['amountBtc'] ?? item.metadata['amount'] ?? '';
    final wallet =
        item.metadata['walletId'] ?? item.metadata['wallet'] ?? 'Principal';
    var network =
        item.metadata['rail'] ?? item.metadata['network'] ?? 'Bitcoin';
    if (network.toUpperCase() == 'INTERNAL' ||
        network.toUpperCase() == 'KEROSENE') {
      network = 'Kerosene (Interna)';
    }
    final address = item.metadata['destination'] ??
        item.metadata['address'] ??
        'endereço externo';

    final currency =
        item.metadata['currency'] ?? item.metadata['ticker'] ?? 'BTC';

    if (item.kind == SessionNotificationItem.kindAccountCreated)
      return tr.notifAccountCreatedBody;
    if (item.kind == SessionNotificationItem.kindSecurityLoginDetected)
      return tr.notifSecurityLoginDetectedBody;
    if (item.kind == SessionNotificationItem.kindSecurityAdminAccessAttempt)
      return tr.notifSecurityAdminAccessAttemptBody;
    if (item.kind == SessionNotificationItem.kindSecurityRecoveryCompleted)
      return tr.notifSecurityRecoveryCompletedBody;

    if (item.kind == SessionNotificationItem.kindTransferReceived ||
        item.kind == SessionNotificationItem.kindDepositConfirmed) {
      return tr.notifTransactionReceivedBody(amount, currency, network, wallet);
    }

    if (item.kind == SessionNotificationItem.kindTransferSent ||
        item.kind == SessionNotificationItem.kindPaymentSent ||
        item.kind == SessionNotificationItem.kindLightningPaymentSent) {
      return tr.notifTransactionSentBody(network, amount, currency, address);
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestCreated) {
      return tr.notifTransactionInvoiceStatusBody(
          amount, currency, 'criado para $wallet');
    }

    if (item.kind == SessionNotificationItem.kindPaymentRequestPaid ||
        item.kind == SessionNotificationItem.kindLightningInvoicePaid) {
      return tr.notifTransactionInvoiceStatusBody(
          amount, currency, 'pago com sucesso');
    }

    if (item.kind == SessionNotificationItem.kindDepositDetected) {
      if (item.metadata.containsKey('confirmations') &&
          item.metadata['confirmations'] != '0') {
        return tr.notifTransactionStatusBody(
            amount, currency, network, 'confirmando');
      }
      return tr.notifTransactionStatusBody(
          amount, currency, network, 'pendente');
    }

    if (item.body == 'notification.transaction.cold.outbound.detected.body')
      return tr.notifTransactionSentBody(
          'Cold Wallet', amount, currency, address);
    if (item.body == 'notification.transaction.cold.outbound.confirmed.body')
      return tr.notifTransactionSentBody(
          'Cold Wallet', amount, currency, address);
    if (item.body == 'notification.transaction.cold.inbound.detected.body')
      return tr.notifTransactionReceivedBody(
          amount, currency, 'Cold Wallet', wallet);

    return item.body;
  }
}
