import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/currency_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/utils/transaction_party_display.dart';
import 'package:kerosene/features/movement/widgets/transaction_palette.dart';

/// Full-screen transaction dossier — black canvas, Newsreader title, staggered
/// field reveal. Opened from compact card "ver detalhes".
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  static Future<void> open(BuildContext context, Transaction transaction) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: KeroseneMotion.medium,
        reverseTransitionDuration: KeroseneMotion.short,
        pageBuilder: (context, animation, secondaryAnimation) {
          return TransactionDetailScreen(transaction: transaction);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Transaction get tx => widget.transaction;

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
    final actionTitle = resolveTransactionActionTitle(context, tx);
    final selectedCurrency = ref.watch(currencyProvider);
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final amountLabel = MoneyDisplay.formatFrozenAmountFromBtc(
      btcAmount: tx.signedAmountBTC,
      currency: selectedCurrency,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      displayAmountUsd: tx.displayAmountUsd,
      displayAmountEur: tx.displayAmountEur,
      displayAmountBrl: tx.displayAmountBrl,
      displayBtcUsd: tx.displayBtcUsd,
      displayBtcEur: tx.displayBtcEur,
      displayBtcBrl: tx.displayBtcBrl,
      signed: true,
    );
    final btcLabel = MoneyDisplay.formatAmountFromBtc(
      btcAmount: tx.signedAmountBTC,
      currency: Currency.btc,
      btcUsd: btcUsd,
      btcEur: btcEur,
      btcBrl: btcBrl,
      signed: true,
    );

    final from = resolveTransactionFromParty(
      tx,
      wallets: _wallets,
      accounts: _accounts,
    );
    final to = resolveTransactionToParty(
      tx,
      wallets: _wallets,
      accounts: _accounts,
      compactHash: false,
    );
    final network = resolveTransactionNetworkLabel(tx);
    final when =
        DateFormat('dd MMM yyyy · HH:mm').format(tx.timestamp.toLocal());

    final rows = <_DetailRowData>[
      _DetailRowData('De', from, copyable: false),
      _DetailRowData('Para', to, copyable: looksLikeOnchainAddress(to)),
      _DetailRowData('Valor', amountLabel),
      _DetailRowData('Valor (BTC)', btcLabel),
      _DetailRowData(
        'Taxa de transação',
        tx.hasNetworkFee || tx.feeSatoshis > 0
            ? formatSatsAsBtc(tx.feeSatoshis)
            : '—',
      ),
      _DetailRowData(
        'Taxa de serviço',
        tx.hasServiceFee ? formatSatsAsBtc(tx.serviceFeeSatoshis) : '—',
      ),
      _DetailRowData('Rede', network),
      _DetailRowData('Status', _statusLabel(tx)),
      _DetailRowData('Tipo', actionTitle),
      _DetailRowData('Data e hora', when),
      if (tx.confirmations > 0)
        _DetailRowData('Confirmações', '${tx.confirmations}'),
      if ((tx.blockHeight ?? 0) > 0)
        _DetailRowData('Bloco', '#${tx.blockHeight}'),
      if ((tx.blockHash ?? '').trim().isNotEmpty)
        _DetailRowData('Hash do bloco', tx.blockHash!.trim(), copyable: true),
      if ((tx.blockchainTxid ?? '').trim().isNotEmpty)
        _DetailRowData(
          'TXID on-chain',
          tx.blockchainTxid!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.paymentHash ?? '').trim().isNotEmpty)
        _DetailRowData(
          'Payment hash',
          tx.paymentHash!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.invoiceId ?? '').trim().isNotEmpty)
        _DetailRowData('Invoice ID', tx.invoiceId!.trim(), copyable: true),
      if ((tx.lightningInvoice ?? '').trim().isNotEmpty)
        _DetailRowData(
          'Invoice Lightning',
          tx.lightningInvoice!.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.externalReference ?? '').trim().isNotEmpty)
        _DetailRowData(
          'Referência externa',
          tx.externalReference!.trim(),
          copyable: true,
        ),
      if ((tx.externalTransferId ?? '').trim().isNotEmpty)
        _DetailRowData(
          'ID transferência externa',
          tx.externalTransferId!.trim(),
          copyable: true,
        ),
      if ((tx.externalTransferStatus ?? '').trim().isNotEmpty)
        _DetailRowData('Status externo', tx.externalTransferStatus!.trim()),
      if ((tx.externalTransferType ?? '').trim().isNotEmpty)
        _DetailRowData('Tipo externo', tx.externalTransferType!.trim()),
      if ((tx.walletId ?? '').trim().isNotEmpty)
        _DetailRowData('Carteira', tx.walletId!.trim(), copyable: true),
      if ((tx.sourceWalletId ?? '').trim().isNotEmpty)
        _DetailRowData(
          'Carteira origem',
          tx.sourceWalletId!.trim(),
          copyable: true,
        ),
      if ((tx.destinationWalletId ?? '').trim().isNotEmpty)
        _DetailRowData(
          'Carteira destino',
          tx.destinationWalletId!.trim(),
          copyable: true,
        ),
      if ((tx.senderDisplayName ?? '').trim().isNotEmpty)
        _DetailRowData('Remetente', tx.senderDisplayName!.trim()),
      if ((tx.receiverDisplayName ?? '').trim().isNotEmpty)
        _DetailRowData('Destinatário', tx.receiverDisplayName!.trim()),
      if ((tx.fromAddress).trim().isNotEmpty)
        _DetailRowData(
          'Endereço origem',
          tx.fromAddress.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.toAddress).trim().isNotEmpty)
        _DetailRowData(
          'Endereço destino',
          tx.toAddress.trim(),
          copyable: true,
          mono: true,
        ),
      if ((tx.description ?? '').trim().isNotEmpty)
        _DetailRowData('Descrição', tx.description!.trim()),
      _DetailRowData('ID interno', tx.id, copyable: true, mono: true),
      if (tx.displayAmountUsd != null)
        _DetailRowData(
          'Valor USD (congelado)',
          MoneyDisplay.format(
            amount: tx.displayAmountUsd!,
            currency: Currency.usd,
          ),
        ),
      if (tx.displayAmountBrl != null)
        _DetailRowData(
          'Valor BRL (congelado)',
          MoneyDisplay.format(
            amount: tx.displayAmountBrl!,
            currency: Currency.brl,
          ),
        ),
      if (tx.displayAmountEur != null)
        _DetailRowData(
          'Valor EUR (congelado)',
          MoneyDisplay.format(
            amount: tx.displayAmountEur!,
            currency: Currency.eur,
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      KeroseneIcons.back,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _statusLabel(tx).toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: TransactionPalette.statusStrong(
                        TransactionPalette.toneFor(tx),
                      ),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
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
                      curve: const Interval(0, 0.35, curve: Curves.easeOut),
                    ),
                    child: Text(
                      actionTitle,
                      style: AppTypography.display.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entrance,
                      curve: const Interval(0.08, 0.42, curve: Curves.easeOut),
                    ),
                    child: Text(
                      amountLabel,
                      style: AppTypography.financial(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entrance,
                      curve: const Interval(0.12, 0.48, curve: Curves.easeOut),
                    ),
                    child: Text(
                      network,
                      style: AppTypography.bodyMedium.copyWith(
                        color: KeroseneBrandTokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (var i = 0; i < rows.length; i++)
                    _StaggeredDetailRow(
                      animation: _entrance,
                      index: i,
                      total: rows.length,
                      row: rows[i],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(Transaction tx) {
    return switch (tx.status) {
      TransactionStatus.confirmed => 'Confirmada',
      TransactionStatus.confirming => 'Confirmando',
      TransactionStatus.pending => 'Pendente',
      TransactionStatus.cancelled => 'Cancelada',
      TransactionStatus.failed => 'Falhou',
    };
  }
}

class _DetailRowData {
  final String label;
  final String value;
  final bool copyable;
  final bool mono;

  const _DetailRowData(
    this.label,
    this.value, {
    this.copyable = false,
    this.mono = false,
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
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.base),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1F1F1F)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: KeroseneBrandTokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: row.mono
                                ? AppTypography.technicalMono(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.35,
                                  )
                                : AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                          ),
                        ),
                        if (row.copyable) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await Clipboard.setData(
                                ClipboardData(text: row.value),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.maybeOf(context)
                                ?..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Copiado'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                            },
                            child: const Icon(
                              KeroseneIcons.copy,
                              size: 16,
                              color: Color(0xFF8A8A8E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
