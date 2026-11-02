import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'dart:async';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/core/navigation/app_navigation.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/security/local_transaction_history_store.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart'
    show ledgerRepositoryProvider;
import 'package:kerosene/features/ledger/domain/local_ledger_sync.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/notification_translator.dart';

class NotificationNavigation {
  static Future<void> openFromContext(
    BuildContext context,
    SessionNotificationItem notification,
  ) {
    final navigator = AppNavigation.maybeNavigatorOf(context);
    if (navigator == null) {
      AppNotice.showError(context,
          title: context.tr.notifDialogOpenFailedTitle,
          message: context.tr.notifDialogOpenFailedMessage);
      return Future.value();
    }
    return openWithNavigator(notification, navigator);
  }

  static Future<void> openWithNavigator(
    SessionNotificationItem notification,
    NavigatorState navigator,
  ) async {
    final context = navigator.context;
    final container = ProviderScope.containerOf(context, listen: false);
    final ownerScope = container.read(sessionStorageScopeProvider);
    if (ownerScope == null) {
      return;
    }
    var valid = true;
    Route<dynamic>? dialogRoute;
    bool ownsSession() =>
        valid &&
        navigator.mounted &&
        context.mounted &&
        container.read(sessionStorageScopeProvider) == ownerScope;
    void closeLostDialog() {
      final route = dialogRoute;
      if (!valid && navigator.mounted && route != null && route.isActive) {
        navigator.removeRoute(route, false);
      }
    }

    final subscription =
        container.listen<String?>(sessionStorageScopeProvider, (_, next) {
      if (next != ownerScope) {
        valid = false;
        scheduleMicrotask(closeLostDialog);
      }
    });
    try {
      if (_isTransaction(notification)) {
        final tx = await _resolveTransactionFromNotification(
            context, notification,
            ownerScope: ownerScope, ownsSession: ownsSession);
        if (!context.mounted || !navigator.mounted || !ownsSession()) {
          return;
        }
        if (tx != null) {
          await TransactionDetailScreen.open(navigator.context, tx);
          return;
        }
      }
      final route = notification.deeplink?.trim();
      if (route == null ||
          route.isEmpty ||
          !context.mounted ||
          !ownsSession()) {
        return;
      }
      if (!_isTransaction(notification) &&
          _shouldShowProfessionalDialog(notification)) {
        final shouldOpen = await showDialog<bool>(
              context: context,
              useRootNavigator: false,
              barrierColor: Colors.black.withValues(alpha: 0.68),
              builder: (dialogContext) {
                dialogRoute = ModalRoute.of(dialogContext);
                if (!ownsSession()) {
                  scheduleMicrotask(closeLostDialog);
                  return const SizedBox.shrink();
                }
                return _ProfessionalNotificationDialog(
                    notification: notification,
                    routeLabel: _routeLabelFor(dialogContext, notification));
              },
            ) ??
            false;
        if (!shouldOpen || !ownsSession()) {
          return;
        }
      }
      if (!context.mounted || !navigator.mounted || !ownsSession()) {
        return;
      }
      try {
        await AppNavigation.push(context, route);
      } catch (error) {
        debugPrint(
            'Could not open notification deeplink (${error.runtimeType}).');
        if (context.mounted && ownsSession()) {
          AppNotice.showError(context,
              title: context.tr.notifDialogOpenFailedTitle,
              message: context.tr.notifDialogOpenFailedMessage);
        }
      }
    } finally {
      subscription.close();
    }
  }

  static Future<Transaction?> _resolveTransactionFromNotification(
    BuildContext context,
    SessionNotificationItem notification, {
    required String ownerScope,
    required bool Function() ownsSession,
  }) async {
    final entityId = notification.entityId?.trim() ?? '';
    final metaId = _firstMetadataValue(notification, const [
          'transactionId',
          'txId',
          'txid',
          'blockchainTxid',
          'paymentHash',
        ]) ??
        '';

    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final keys = <String>{
        if (entityId.isNotEmpty) entityId,
        if (metaId.isNotEmpty) metaId,
      };

      // 1) Local/remote projection already loaded.
      try {
        final history = await container.read(transactionHistoryProvider.future);
        if (!ownsSession()) {
          return null;
        }
        final hit = _matchInList(history, keys);
        if (hit != null) {
          return hit;
        }
      } catch (_) {}

      if (!ownsSession()) {
        return null;
      }
      // 2) Single-tx fetch by KFE UUID + merge into durable projection.
      if (entityId.isNotEmpty &&
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(entityId)) {
        final repo = container.read(ledgerRepositoryProvider);
        final result = await repo.getTransactionById(entityId);
        if (!ownsSession()) {
          return null;
        }
        final remote = result.fold((_) => null, (tx) => tx);
        if (remote != null) {
          final scope = ownerScope;
          if (scope.trim().isNotEmpty) {
            final store = container.read(localTransactionHistoryStoreProvider);
            final merged = await LocalLedgerSync(
              store,
            ).hydrateAndMerge(sessionScope: scope, remote: [remote]);
            if (!ownsSession()) {
              return null;
            }
            container.read(lastTransactionHistoryProvider.notifier).set(merged);
            container.invalidate(transactionHistoryProvider);
          }
          return remote;
        }
      }
    } catch (error) {
      debugPrint('Could not resolve notification transaction: $error');
    }

    // Prefer opening the extrato (deeplink) over a synthetic incomplete detail.
    return null;
  }

  static Transaction? _matchInList(
    List<Transaction> history,
    Set<String> keys,
  ) {
    for (final key in keys) {
      for (final tx in history) {
        if (tx.id == key ||
            (tx.blockchainTxid ?? '') == key ||
            (tx.paymentHash ?? '') == key ||
            (tx.externalTransferId ?? '') == key ||
            (tx.invoiceId ?? '') == key) {
          return tx;
        }
      }
    }
    return null;
  }

  static bool _shouldShowProfessionalDialog(
    SessionNotificationItem notification,
  ) {
    // Transaction kinds use TransactionDetailScreen — not the legacy dialog.
    return _isLoginOrSecurity(notification) ||
        _isPaymentLink(notification) ||
        _isRealBitcoinMarketAlert(notification) ||
        _isColdWalletNotification(notification);
  }

  static bool _isTransaction(SessionNotificationItem notification) {
    return const {
      SessionNotificationItem.kindTransferReceived,
      SessionNotificationItem.kindTransferSent,
      SessionNotificationItem.kindDepositDetected,
      SessionNotificationItem.kindDepositConfirmed,
      SessionNotificationItem.kindPaymentSent,
      SessionNotificationItem.kindPaymentProcessing,
      SessionNotificationItem.kindPaymentBroadcast,
      SessionNotificationItem.kindPaymentConfirmed,
      SessionNotificationItem.kindPaymentFailed,
      SessionNotificationItem.kindPaymentReconciliationRequired,
      SessionNotificationItem.kindDepositDropped,
      SessionNotificationItem.kindDepositReversed,
      SessionNotificationItem.kindPaymentRequestPaid,
      SessionNotificationItem.kindLightningInvoicePaid,
      SessionNotificationItem.kindLightningPaymentSent,
      SessionNotificationItem.kindLightningPaymentFailed,
    }.contains(notification.kind);
  }

  static bool _isLoginOrSecurity(SessionNotificationItem notification) {
    return notification.kind.startsWith('security_') ||
        notification.entityType == 'security' ||
        notification.entityType == 'login';
  }

  static bool _isPaymentLink(SessionNotificationItem notification) {
    return const {
          SessionNotificationItem.kindPaymentRequestCreated,
          SessionNotificationItem.kindPaymentRequestPaid,
        }.contains(notification.kind) ||
        notification.entityType == 'payment_link' ||
        notification.entityType == 'paymentRequest';
  }

  static bool _isRealBitcoinMarketAlert(SessionNotificationItem notification) {
    if (notification.kind != SessionNotificationItem.kindMarketAlert) {
      return false;
    }
    return _firstMetadataValue(notification, const [
          'priceUsd',
          'btcPriceUsd',
          'lastPriceUsd',
        ]) !=
        null;
  }

  static bool _isColdWalletNotification(SessionNotificationItem notification) {
    final haystack = [
      notification.kind,
      notification.entityType ?? '',
      notification.title,
      notification.body,
      ...notification.metadata.entries.map(
        (entry) => '${entry.key}:${entry.value}',
      ),
    ].join(' ').toLowerCase();

    return haystack.contains('cold_wallet') ||
        haystack.contains('cold wallet') ||
        haystack.contains('watch-only') ||
        haystack.contains('watch only') ||
        haystack.contains('xpub') ||
        haystack.contains('descriptor');
  }

  static String _routeLabelFor(
      BuildContext context, SessionNotificationItem notification) {
    if (_isLoginOrSecurity(notification)) {
      return context.tr.notifDialogOpenSecurity;
    }
    if (_isPaymentLink(notification)) {
      return context.tr.notifDialogOpenLink;
    }
    if (_isRealBitcoinMarketAlert(notification)) {
      return context.tr.notifDialogOpenMarket;
    }
    if (_isColdWalletNotification(notification)) {
      return context.tr.notifDialogOpenWallet;
    }
    return context.tr.notifBannerOpen;
  }

  static String? _firstMetadataValue(
    SessionNotificationItem notification,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = notification.metadata[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

class _ProfessionalNotificationDialog extends StatelessWidget {
  final SessionNotificationItem notification;
  final String routeLabel;

  const _ProfessionalNotificationDialog({
    required this.notification,
    required this.routeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KeroseneBrandTheme.of(context);
    final spec = _DialogSpec.from(context, notification);
    final height = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      backgroundColor: brand.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: brand.border)),
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: height * 0.85),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                KeroseneIcon(spec.icon,
                                    color: brand.textPrimary, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(spec.eyebrow,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                                color: brand.textSecondary)))
                              ]),
                              const SizedBox(height: 16),
                              Text(
                                  NotificationTranslator.resolveTitle(
                                      context, notification),
                                  style: AppTypography.playfairDisplay(
                                      fontSize: 24, color: brand.textPrimary)),
                              const SizedBox(height: 12),
                              Text(
                                  NotificationTranslator.resolveBody(
                                      context, notification),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: brand.textSecondary, height: 1.4)),
                              if (spec.rows.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                for (final row in spec.rows)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _DetailRow(
                                          label: _localizedDialogLabel(
                                              context, row.label),
                                          value: row.value)),
                              ],
                              if (spec.note != null) ...[
                                const SizedBox(height: 8),
                                Text(spec.note!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: brand.textSecondary))
                              ],
                            ]))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                              label: routeLabel,
                              onPressed: () => Navigator.of(context).pop(true),
                              expand: true),
                          const SizedBox(height: 8),
                          AppButton(
                              label: context.tr.close,
                              onPressed: () => Navigator.of(context).pop(false),
                              expand: true,
                              variant: AppButtonVariant.secondary),
                        ])),
              ])),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final brand = KeroseneBrandTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: brand.textSecondary)),
      const SizedBox(height: 4),
      SelectableText(value,
          style: AppTypography.technicalMono(
              fontSize: 13, color: brand.textPrimary)),
    ]);
  }
}

String _localizedDialogLabel(BuildContext context, String value) =>
    switch (value) {
      'Valor' => context.tr.notifDialogAmount,
      'Valor (BTC)' => context.tr.notifDialogBtcAmount,
      'Carteira' => context.tr.notifDialogWallet,
      'Origem' => context.tr.notifDialogFrom,
      'Destino' => context.tr.notifDialogTo,
      'Pagador' => context.tr.notifDialogPayer,
      'Link' => context.tr.notifDialogLink,
      'Dispositivo' => context.tr.notifDialogDevice,
      'Local' => context.tr.notifDialogLocation,
      'IP' => context.tr.notifDialogIp,
      'Horário' => context.tr.notifDialogTime,
      'Preço' => context.tr.notifDialogPrice,
      '24h' => context.tr.notifDialogChange,
      'Faixa' => context.tr.notifDialogThreshold,
      'Fonte' => context.tr.notifDialogSource,
      'Modo' => context.tr.notifDialogMode,
      'Rede' => context.tr.notifDialogNetwork,
      'Material' => context.tr.notifDialogMaterial,
      'ID' => context.tr.notifDialogReference,
      _ => value,
    };

class _DialogSpec {
  final String eyebrow;
  final IconData icon;
  final List<_DialogRow> rows;
  final String? note;

  const _DialogSpec({
    required this.eyebrow,
    required this.icon,
    this.rows = const [],
    this.note,
  });

  factory _DialogSpec.from(
      BuildContext context, SessionNotificationItem notification) {
    if (NotificationNavigation._isLoginOrSecurity(notification)) {
      return _DialogSpec(
        eyebrow: context.tr.notifCategorySecurity,
        icon: KeroseneIcons.shield,
        rows: _securityRows(notification),
        note: context.tr.notifDialogSecurityNote,
      );
    }

    if (NotificationNavigation._isPaymentLink(notification)) {
      return _DialogSpec(
        eyebrow: context.tr.notifCategoryPaymentLink,
        icon: KeroseneIcons.qr,
        rows: _paymentLinkRows(notification),
      );
    }

    if (NotificationNavigation._isRealBitcoinMarketAlert(notification)) {
      return _DialogSpec(
        eyebrow: context.tr.notifCategoryMarket,
        icon: KeroseneIcons.activity,
        rows: _marketRows(notification),
        note: context.tr.notifDialogMarketNote,
      );
    }

    if (NotificationNavigation._isColdWalletNotification(notification)) {
      return _DialogSpec(
        eyebrow: context.tr.notifDialogWatchedWallet,
        icon: KeroseneIcons.wallet,
        rows: _coldWalletRows(notification),
        note: context.tr.notifDialogWalletNote,
      );
    }

    return _DialogSpec(
      eyebrow: context.tr.notifCategorySystem,
      icon: _transactionIcon(notification),
      rows: _transactionRows(notification),
    );
  }

  static List<_DialogRow> _transactionRows(
    SessionNotificationItem notification,
  ) {
    return _compactRows([
      _rowFromKeys(notification, 'Valor', const [
        'amountBtc',
        'amount',
        'btcAmount',
      ]),
      _rowFromKeys(notification, 'Carteira', const [
        'walletName',
        'wallet',
        'accountName',
      ]),
      _rowFromKeys(notification, 'Origem', const [
        'sender',
        'from',
        'payerName',
      ]),
      _rowFromKeys(notification, 'Destino', const [
        'receiver',
        'to',
        'payeeName',
      ]),
      _entityRow(notification),
    ]);
  }

  static List<_DialogRow> _paymentLinkRows(
    SessionNotificationItem notification,
  ) {
    return _compactRows([
      _rowFromKeys(notification, 'Valor', const [
        'amountBtc',
        'amount',
        'btcAmount',
      ]),
      _rowFromKeys(notification, 'Pagador', const [
        'payerName',
        'payer',
        'sender',
      ]),
      _rowFromKeys(notification, 'Carteira', const [
        'walletName',
        'wallet',
        'accountName',
      ]),
      _rowFromKeys(notification, 'Link', const [
        'paymentLinkId',
        'paymentRequestId',
        'linkId',
      ]),
      _entityRow(notification),
    ]);
  }

  static List<_DialogRow> _securityRows(SessionNotificationItem notification) {
    return _compactRows([
      _rowFromKeys(notification, 'Dispositivo', const [
        'deviceName',
        'device',
        'userAgent',
      ]),
      _rowFromKeys(notification, 'Local', const [
        'location',
        'city',
        'region',
        'country',
      ]),
      _rowFromKeys(notification, 'IP', const [
        'ip',
        'ipAddress',
        'remoteAddress',
      ]),
      _rowFromKeys(notification, 'Horário', const ['occurredAt', 'createdAt']),
    ]);
  }

  static List<_DialogRow> _marketRows(SessionNotificationItem notification) {
    return _compactRows([
      _rowFromKeys(notification, 'Preço', const [
        'priceUsd',
        'btcPriceUsd',
        'lastPriceUsd',
      ]),
      _rowFromKeys(notification, '24h', const [
        'dailyChangePercent',
        'change24hPercent',
        'changePercent24h',
      ]),
      _rowFromKeys(notification, 'Faixa', const ['thresholdPercent']),
      _rowFromKeys(notification, 'Fonte', const ['source']),
    ]);
  }

  static List<_DialogRow> _coldWalletRows(
    SessionNotificationItem notification,
  ) {
    return _compactRows([
      _rowFromKeys(notification, 'Carteira', const [
        'walletName',
        'wallet',
        'accountName',
      ]),
      _rowFromKeys(notification, 'Modo', const [
        'walletMode',
        'walletKind',
        'custody',
        'type',
      ]),
      _rowFromKeys(notification, 'Rede', const ['network', 'bitcoinNetwork']),
      _rowFromKeys(notification, 'Material', const [
        'publicMaterialType',
        'descriptorType',
      ]),
      _entityRow(notification),
    ]);
  }

  static IconData _transactionIcon(SessionNotificationItem notification) {
    if (notification.kind == SessionNotificationItem.kindTransferReceived ||
        notification.kind == SessionNotificationItem.kindDepositDetected ||
        notification.kind == SessionNotificationItem.kindDepositConfirmed) {
      return KeroseneIcons.receive;
    }
    return KeroseneIcons.send;
  }

  static _DialogRow? _rowFromKeys(
    SessionNotificationItem notification,
    String label,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = notification.metadata[key]?.trim();
      if (value == null || value.isEmpty) continue;
      final btc =
          label == 'Valor' && (key == 'amountBtc' || key == 'btcAmount');
      return _DialogRow(btc ? 'Valor (BTC)' : label, value);
    }
    return null;
  }

  static _DialogRow? _entityRow(SessionNotificationItem notification) {
    final id = notification.entityId?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    return _DialogRow('ID', id);
  }

  static List<_DialogRow> _compactRows(List<_DialogRow?> rows) {
    final seen = <String>{};
    return rows.whereType<_DialogRow>().where((row) {
      final key = '${row.label}:${row.value}';
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList(growable: false);
  }
}

class _DialogRow {
  final String label;
  final String value;

  const _DialogRow(this.label, this.value);
}
