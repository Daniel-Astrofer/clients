import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_surface_provider.dart';
import 'dart:async';
import 'package:kerosene/app/security/payment_submission_store.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/core/logging/app_log.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';

import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'activity_actions.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_presentation.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    hide transactionRepositoryProvider;
import 'package:kerosene/features/movement/presentation/activity/blockchain_explorer.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_display.dart';
import 'package:kerosene/features/movement/presentation/activity/activity_glyph.dart';
import 'package:kerosene/features/movement/presentation/activity/home_activity_surface.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_party_display.dart';

/// Persistent transaction detail using the Home typography and exact amounts.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  /// Opens with the same circular-reveal family as the notification center.
  static Future<void> open(
    BuildContext context,
    Transaction transaction, {
    Rect? originRect,
  }) {
    final size = MediaQuery.sizeOf(context);
    final origin = originRect ??
        keroseneOriginRectFromContext(context) ??
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 48,
          height: 48,
        );
    return Navigator.of(context).push<void>(
      keroseneCircularRevealRoute<void>(
        page: TransactionDetailScreen(transaction: transaction),
        originRect: origin,
        transitionDuration:
            KeroseneMotion.duration(context, KeroseneMotion.pageIn),
        reverseTransitionDuration:
            KeroseneMotion.duration(context, KeroseneMotion.pageOut),
      ),
    );
  }

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen>
    with FinancialSurfaceMixin, SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late Transaction _tx;
  late final String? _ownerScope;
  bool _openingExplorer = false;
  String? _explorerError;

  bool get _owns =>
      mounted &&
      _ownerScope?.isNotEmpty == true &&
      ref.read(sessionStorageScopeProvider)?.trim() == _ownerScope;

  String? get _explorerNetwork =>
      BlockchainExplorer.networkFromAddresses([tx.fromAddress, tx.toAddress]);

  Future<void> _openExplorer() async {
    if (_openingExplorer || !_owns || !ref.read(appForegroundProvider)) return;
    final snapshot = tx;
    final network = _explorerNetwork;
    if (!snapshot.isOnChain ||
        BlockchainExplorer.txUri(snapshot.blockchainTxid,
                networkHint: network) ==
            null) {
      return;
    }
    final message = context.tr.transactionExplorerOpenFailed;
    setState(() {
      _openingExplorer = true;
      _explorerError = null;
    });
    final opened = await BlockchainExplorer.openTx(snapshot.blockchainTxid,
        networkHint: network,
        launcher: ref.read(blockchainExplorerLauncherProvider));
    if (!mounted) return;
    setState(() => _openingExplorer = false);
    if (!_owns || tx.id != snapshot.id || !ref.read(appForegroundProvider)) {
      return;
    }
    if (!opened) {
      setState(() => _explorerError = message);
      AppNotice.showError(context, message: message);
    }
  }

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _ownerScope = ref.read(sessionStorageScopeProvider)?.trim();
    if (PaymentSubmissionStore.validTransactionId(_tx.id)) {
      final scope = ref.read(sessionStorageScopeProvider);
      if (scope != null) {
        final store = ref.read(paymentSubmissionStoreProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || ref.read(sessionStorageScopeProvider) != scope) {
            return;
          }
          unawaited(store
              .acknowledgeTransaction(scope, _tx.id)
              .catchError((Object _) {
            appLog(
                'Payment details were viewed; the recovery acknowledgment could not be saved.');
          }));
        });
      }
    }
    _entrance = AnimationController(
      vsync: this,
      duration: KeroseneMotion.medium,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KeroseneMotion.reduceMotion(context)) _entrance.value = 1;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Transaction get tx => _tx;

  List<Wallet> get _wallets {
    final state = ref.watch(walletProvider);
    if (state is WalletLoaded) return state.wallets;
    return const [];
  }

  List<BitcoinAccount> get _accounts {
    return ref.watch(bitcoinAccountsProvider).asData?.value ??
        const <BitcoinAccount>[];
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(lastTransactionHistoryProvider);
    final current = latest.where((item) => item.id == _tx.id).firstOrNull;
    if (current != null &&
        current.effectiveUpdatedAt.compareTo(_tx.effectiveUpdatedAt) > 0) {
      _tx = current;
    }
    final money = ref.watch(moneyFormatConfigProvider);
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final presentation = TransactionPresentation.fromTransaction(
      context,
      tx,
      wallets: _wallets,
      accounts: _accounts,
      displayCurrency: money.currency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      appLocale: money.locale,
      btcDecimalPlaces: money.btcDecimalPlaces,
    );
    final actionTitle = presentation.detailTitle(context);
    final partyTitle = resolveTransactionPartyTitle(
      tx,
      subtitle: presentation.subtitle,
      defaultTitle: actionTitle,
    );
    final amountLabel = presentation.primaryAmountLabel;
    final btcLabel = MoneyDisplay.formatOperationAmount(
      satoshis: tx.isDebit ? -tx.amountSatoshis : tx.amountSatoshis,
      signed: true,
      appLocale: money.locale,
    );
    final copy = TransactionPresentationCopy.of(context);
    final network = copy.railShort(presentation.axes.rail);
    final statusLabel = presentation.statusLabel;
    final amountMeaning =
        tx.isDebit && (tx.showsNetworkFee || tx.showsServiceFee)
            ? (tx.isConfirmed
                ? copy.totalDebited
                : context.tr.movementOperationTotal)
            : copy.amountLabel;

    final statusIcon = switch (presentation.axes.lifecycle) {
      TxLifecycle.confirmed => KeroseneIcons.success,
      TxLifecycle.pending || TxLifecycle.confirming => KeroseneIcons.timer,
      TxLifecycle.cancelled => KeroseneIcons.closeCircle,
      TxLifecycle.failed => KeroseneIcons.error,
      TxLifecycle.reconciling ||
      TxLifecycle.unconfirmedExpired =>
        KeroseneIcons.review,
    };

    ref.watch(sessionStorageScopeProvider);
    final foreground = ref.watch(appForegroundProvider);
    final hasExplorerReference =
        tx.isOnChain && tx.blockchainTxid?.trim().isNotEmpty == true;
    final explorerUri = BlockchainExplorer.txUri(tx.blockchainTxid,
        networkHint: _explorerNetwork);
    final explorerUnavailable =
        !BlockchainExplorer.hasValidTxid(tx.blockchainTxid)
            ? context.tr.transactionExplorerInvalidHash
            : _explorerNetwork == 'regtest'
                ? context.tr.transactionExplorerLocalNetwork
                : context.tr.transactionExplorerUnknownNetwork;

    final targetConfirmations = tx.onchainConfirmationTarget.clamp(1, 6);
    final confCount = tx.confirmations.clamp(0, targetConfirmations);

    final primaryRows = <_DetailRowData>[
      _DetailRowData(
        copy.status,
        statusLabel,
        customWidget: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            KeroseneIcon(
              statusIcon,
              key: const ValueKey('transaction-detail-status-icon'),
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            Text(
              statusLabel,
              key: const ValueKey('transaction-detail-status-label'),
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tx.showsOnchainConfirmations)
              Text(
                '($confCount/$targetConfirmations)',
                style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      _DetailRowData(copy.network, network),
      _DetailRowData(
        copy.whenLabel,
        AppDateTime.formatFull(context, tx.timestamp),
      ),
    ];

    final fromField = presentation.expandedFields.firstWhere(
      (f) => f.key == 'from',
      orElse: () => const PresentationField(key: '', label: '', value: ''),
    );
    if (fromField.value.isNotEmpty && fromField.value != '—') {
      primaryRows.add(_DetailRowData(
        copy.fromPrefix,
        fromField.value,
        copyable: fromField.copyable,
      ));
    }

    final toField = presentation.expandedFields.firstWhere(
      (f) => f.key == 'to',
      orElse: () => const PresentationField(key: '', label: '', value: ''),
    );
    if (toField.value.isNotEmpty && toField.value != '—') {
      primaryRows.add(_DetailRowData(
        copy.toPrefix,
        toField.value,
        copyable: toField.copyable,
      ));
    }

    final amountField = presentation.expandedFields.firstWhere(
      (f) => f.key == 'amount',
      orElse: () => const PresentationField(key: '', label: '', value: ''),
    );
    if ((tx.showsNetworkFee || tx.showsServiceFee) &&
        amountField.value.isNotEmpty) {
      primaryRows.add(_DetailRowData(
        copy.amountLabel,
        amountField.value,
      ));
    }

    if (tx.showsNetworkFee) {
      primaryRows.add(_DetailRowData(
        copy.networkFee,
        formatSatsAsBtc(tx.feeSatoshis),
      ));
    }

    if (tx.showsServiceFee) {
      primaryRows.add(_DetailRowData(
        copy.serviceFee,
        formatSatsAsBtc(tx.serviceFeeSatoshis),
      ));
    }

    if (tx.isDebit && (tx.showsNetworkFee || tx.showsServiceFee)) {
      primaryRows.add(_DetailRowData(
        tx.isConfirmed ? copy.totalDebited : context.tr.movementOperationTotal,
        amountLabel,
      ));
    }

    final failureReason = resolveTransactionFailureLabel(context, tx);
    if (failureReason != null) {
      primaryRows.add(_DetailRowData(copy.reason, failureReason));
    }

    final description = tx.description?.trim();
    if (description != null &&
        description.isNotEmpty &&
        !isGenericNetworkWord(description) &&
        description != actionTitle &&
        description != partyTitle) {
      primaryRows.add(_DetailRowData(copy.description, description));
    }

    // Only add BTC when the chosen recorded fiat has replaced the principal.
    // Principal and total are distinct when fees apply; do not equate them.
    final showBtc = amountLabel != btcLabel &&
        !primaryRows.any((row) => row.value == btcLabel);

    final technicalFields = presentation.detailTechnicalFields(
      context,
      tx,
      appLocale: money.locale,
    );

    const excludedTechnicalKeys = {
      'wallet-id',
      'source-wallet-id',
      'destination-wallet-id',
      'internal-id',
      'external-status',
      'external-type',
      'from-address',
      'to-address',
      'description',
      'sender-name',
      'receiver-name',
    };

    final technicalRows = <_DetailRowData>[];
    for (final field in technicalFields) {
      if (excludedTechnicalKeys.contains(field.key)) continue;

      if (field.key == 'onchain-txid' && hasExplorerReference) {
        technicalRows.add(_DetailRowData(
          field.label,
          field.value,
          copyable: field.copyable,
          mono: field.technical,
          trailing: TextButton(
            key: const ValueKey('transaction-explorer-open'),
            onPressed: explorerUri != null &&
                    _owns &&
                    foreground &&
                    !_openingExplorer
                ? _openExplorer
                : null,
            child: Text(
              SendMoneyCopy.detailExplorer(context),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: explorerUri != null &&
                        _owns &&
                        foreground &&
                        !_openingExplorer
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
            ),
          ),
        ));
      } else {
        technicalRows.add(_DetailRowData(
          field.label,
          field.value,
          copyable: field.copyable,
          mono: field.technical,
        ));
      }
    }

    return FinancialSecureScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Semantics(
            label: '$partyTitle. $amountLabel. $network. $statusLabel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: KeroseneIcon(
                          KeroseneIcons.back,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                    children: [
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0,
                            0.35,
                            curve: KeroseneMotion.decelerated,
                          ),
                        ),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final style = HomeTypography.heroTitle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 28,
                          );
                          final measure = TextPainter(
                            text: TextSpan(text: partyTitle, style: style),
                            textScaler: MediaQuery.textScalerOf(context),
                            textDirection: Directionality.of(context),
                          )..layout();
                          final fitsBesideIcon =
                              measure.width <= constraints.maxWidth - 72;
                          measure.dispose();
                          final title = FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(partyTitle, style: style, maxLines: 1),
                          );
                          final glyph = ActivityGlyph.forAxes(presentation.axes,
                              size: 56);
                          if (!fitsBesideIcon) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                glyph,
                                const SizedBox(height: 12),
                                title
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              glyph,
                              const SizedBox(width: 16),
                              Expanded(child: title),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(amountMeaning,
                          style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 4),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0.08,
                            0.42,
                            curve: KeroseneMotion.decelerated,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            amountLabel,
                            softWrap: false,
                            style: AppTypography.amount.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      if (showBtc) ...[
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              0.12,
                              0.48,
                              curve: KeroseneMotion.decelerated,
                            ),
                          ),
                          child: Text(
                            btcLabel,
                            style: AppTypography.inter(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (hasExplorerReference && explorerUri == null)
                        SizedBox(
                          width: 0,
                          height: 0,
                          child: Text(
                            explorerUnavailable,
                            key: const ValueKey(
                                'transaction-explorer-unavailable'),
                            style: const TextStyle(fontSize: 0),
                          ),
                        ),
                      if (_explorerError != null && _owns) ...[
                        Text(_explorerError!,
                            key: const ValueKey('transaction-explorer-error'),
                            style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        const SizedBox(height: 16),
                      ],
                      for (var i = 0; i < primaryRows.length; i++)
                        _StaggeredDetailRow(
                          animation: _entrance,
                          index: i,
                          total: primaryRows.length,
                          row: primaryRows[i],
                        ),
                      if (technicalRows.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            SendMoneyCopy.detailTechnical(context),
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (var i = 0; i < technicalRows.length; i++)
                          _StaggeredDetailRow(
                            animation: _entrance,
                            index: i + primaryRows.length,
                            total: primaryRows.length + technicalRows.length,
                            row: technicalRows[i],
                          ),
                      ],
                      const SizedBox(height: 28),
                      ActivityActions(
                          key: ValueKey('activity-actions-${tx.id}'),
                          transaction: tx,
                          onChanged: (next) => setState(() => _tx = next)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRowData {
  final String label;
  final String value;
  final bool copyable;
  final bool mono;
  final Widget? customWidget;
  final Widget? trailing;

  const _DetailRowData(
    this.label,
    this.value, {
    this.copyable = false,
    this.mono = false,
    this.customWidget,
    this.trailing,
  });
}

class _StaggeredDetailRow extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final int total;
  final _DetailRowData row;

  const _StaggeredDetailRow({
    required this.animation,
    required this.index,
    required this.total,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final start = (0.18 + (index / (total + 4)) * 0.7).clamp(0.0, 0.9);
    final end = (start + 0.18).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: KeroseneMotion.standard),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.base),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: LayoutBuilder(builder: (context, constraints) {
                final stacked = row.copyable ||
                    row.mono ||
                    row.customWidget != null ||
                    constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) > 17;
                final label = Text(row.label,
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500));
                final value = Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: row.customWidget != null
                            ? Align(
                                alignment: stacked
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: row.customWidget!,
                              )
                            : SelectableText(row.value,
                                textAlign:
                                    stacked ? TextAlign.left : TextAlign.right,
                                style: row.mono
                                    ? AppTypography.technicalMono(
                                        color:
                                            Theme.of(context).colorScheme.onSurface,
                                        fontSize: 14,
                                        height: 1.35)
                                    : AppTypography.bodyMedium.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.onSurface,
                                        height: 1.35)),
                      ),
                      if (row.copyable) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: context.tr.copy,
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: row.value),
                              );
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(context.tr.copyDataFailed)),
                                );
                              }
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.maybeOf(context)
                              ?..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(context.tr.btcAccountsCopied),
                                  behavior: SnackBarBehavior.floating,
                                  duration: KeroseneMotion.detailClipboardHold,
                                ),
                              );
                          },
                          icon: KeroseneIcon(KeroseneIcons.copy,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                      if (row.trailing != null) ...[
                        const SizedBox(width: 8),
                        row.trailing!,
                      ],
                    ]);
                if (stacked) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [label, const SizedBox(height: 8), value]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: label),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: value),
                    ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
