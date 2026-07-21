import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/core/utils/api_display_text.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/core/utils/safe_display_text.dart';
import 'package:kerosene/features/movement/data/transaction_address_display.dart';
import 'package:kerosene/features/movement/data/entities/payment_link.dart';
import 'package:kerosene/features/movement/presentation/shared/financial_status_badge.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_visuals.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

String _financialCopy(
  BuildContext context, {
  required String pt,
  required String en,
  required String es,
}) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return en;
    case 'es':
      return es;
    default:
      return pt;
  }
}

class FinancialActivityDetailsSheet extends ConsumerWidget {
  final Transaction? transaction;
  final PaymentLink? paymentLink;

  const FinancialActivityDetailsSheet({
    super.key,
    this.transaction,
    this.paymentLink,
  }) : assert(transaction != null || paymentLink != null);

  static Future<void> show(
    BuildContext context, {
    Transaction? transaction,
    PaymentLink? paymentLink,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => FinancialActivityDetailsSheet(
        transaction: transaction,
        paymentLink: paymentLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateTitle = _financialCopy(
      context,
      pt: 'Data',
      en: 'Date',
      es: 'Fecha',
    );
    final advancedDetailsTitle = _financialCopy(
      context,
      pt: 'Dados do pagamento',
      en: 'Payment details',
      es: 'Datos del pago',
    );
    final contextTitle = _financialCopy(
      context,
      pt: 'Contexto',
      en: 'Context',
      es: 'Contexto',
    );
    final statusMeta = paymentLink != null
        ? FinancialStatusBadge.paymentLink(context, paymentLink!.displayStatus)
        : FinancialStatusBadge.transaction(context, transaction!.status);
    final amountBtc = paymentLink?.amountBtc ?? transaction!.signedAmountBTC;
    final money = ref.watch(moneyFormatConfigProvider);
    final selectedCurrency = money.currency;
    final btcUsd = ref.watch(latestBtcPriceProvider);
    final btcEur = ref.watch(btcEurPriceProvider);
    final btcBrl = ref.watch(btcBrlPriceProvider);
    final primaryAmount = transaction != null
        ? money.formatFrozenAmountFromBtc(
            btcAmount: amountBtc,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
            displayAmountUsd: transaction!.displayAmountUsd,
            displayAmountEur: transaction!.displayAmountEur,
            displayAmountBrl: transaction!.displayAmountBrl,
            displayBtcUsd: transaction!.displayBtcUsd,
            displayBtcEur: transaction!.displayBtcEur,
            displayBtcBrl: transaction!.displayBtcBrl,
            signed: true,
          )
        : money.formatAmountFromBtc(
            btcAmount: amountBtc,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
          );
    final secondaryAmount = selectedCurrency == Currency.btc
        ? null
        : money.formatAmountFromBtc(
            btcAmount: amountBtc,
            currency: Currency.btc,
            btcUsd: btcUsd,
            btcEur: btcEur,
            btcBrl: btcBrl,
            signed: transaction != null,
          );
    final createdAt =
        paymentLink?.createdAt ?? paymentLink?.paidAt ?? transaction?.timestamp;
    final hasAdvancedDetails = (_secondaryAddress != null &&
            _secondaryAddress!.trim().isNotEmpty) ||
        (_referenceId != null && _referenceId!.trim().isNotEmpty) ||
        (_invoiceId != null && _invoiceId!.trim().isNotEmpty) ||
        (_paymentHash != null && _paymentHash!.trim().isNotEmpty) ||
        (_lightningInvoice != null && _lightningInvoice!.trim().isNotEmpty) ||
        (_description != null && _description!.trim().isNotEmpty);
    final leadingIcon = paymentLink != null
        ? KeroseneIcons.onchain
        : TransactionVisualSpec.fromTransaction(transaction!).icon;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: monochromePanelDecoration(
          color: monoSurfaceColor,
          borderColor: monoBorderStrongColor,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 1,
                  color: monoBorderStrongColor,
                ),
              ),
              const SizedBox(height: 20),
              _SummaryHero(
                statusMeta: statusMeta,
                leadingIcon: leadingIcon,
                headline: _headline(context),
                contextLabel: _contextLabel(context),
                supportingText: _summaryMessage,
                primaryAmount: primaryAmount,
                secondaryAmount: secondaryAmount,
                createdAt: createdAt,
              ),
              const SizedBox(height: 20),
              _ReceiptSection(
                children: [
                  if (createdAt != null)
                    _ReceiptRow(
                      label: dateTitle,
                      value: AppDateTime.formatRelativeWithClock(
                        context,
                        createdAt,
                      ),
                    ),
                  if (transaction != null) ...[
                    _ReceiptRow(
                      label: _financialCopy(context,
                          pt: 'Valor base',
                          en: 'Base amount',
                          es: 'Monto base'),
                      value: money.formatAmountFromBtc(
                        btcAmount: transaction!.amountBTC,
                        currency: Currency.btc,
                        btcUsd: btcUsd,
                        btcEur: btcEur,
                        btcBrl: btcBrl,
                        signed: false,
                      ),
                      isTechnical: true,
                    ),
                    if (transaction!.showsNetworkFee)
                      _ReceiptRow(
                        label: _financialCopy(context,
                            pt: context.tr.sendReviewNetworkFee,
                            en: 'Network fee',
                            es: 'Tarifa de red'),
                        value: money.formatAmountFromBtc(
                          btcAmount: transaction!.feeBTC,
                          currency: Currency.btc,
                          btcUsd: btcUsd,
                          btcEur: btcEur,
                          btcBrl: btcBrl,
                          signed: false,
                        ),
                        isTechnical: true,
                      ),
                    if (transaction!.showsServiceFee)
                      _ReceiptRow(
                        label: _financialCopy(context,
                            pt: 'Taxa de serviço',
                            en: 'Service fee',
                            es: 'Tarifa de servicio'),
                        value: money.formatAmountFromBtc(
                          btcAmount: transaction!.serviceFeeBTC,
                          currency: Currency.btc,
                          btcUsd: btcUsd,
                          btcEur: btcEur,
                          btcBrl: btcBrl,
                          signed: false,
                        ),
                        isTechnical: true,
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: monoBorderStrongColor, height: 1),
                    ),
                    _ReceiptRow(
                      label: _financialCopy(context,
                          pt: 'Valor total',
                          en: 'Total amount',
                          es: 'Monto total'),
                      value: money.formatAmountFromBtc(
                        btcAmount: (transaction!.amountSatoshis +
                                (transaction!.showsNetworkFee
                                    ? transaction!.feeSatoshis
                                    : 0) +
                                (transaction!.showsServiceFee
                                    ? transaction!.serviceFeeSatoshis
                                    : 0)) /
                            100000000.0,
                        currency: Currency.btc,
                        btcUsd: btcUsd,
                        btcEur: btcEur,
                        btcBrl: btcBrl,
                        signed: false,
                      ),
                      isTechnical: true,
                      isHighlight: true,
                    ),
                  ],
                ],
              ),
              if (transaction != null &&
                  (transaction!.showsOnchainConfirmations ||
                      transaction!.isLightningEffective)) ...[
                const SizedBox(height: 12),
                _ReceiptSection(
                  children: [
                    _ReceiptRow(
                      label: _financialCopy(context,
                          pt: 'Rede', en: 'Network', es: 'Red'),
                      value: transaction!.isLightningEffective
                          ? 'Lightning Network'
                          : 'Bitcoin On-chain',
                    ),
                    // Lightning: status only — never mempool / N/6 confirmations.
                    if (transaction!.isLightningEffective)
                      _ReceiptRow(
                        label: _financialCopy(
                          context,
                          pt: 'Liquidação',
                          en: 'Settlement',
                          es: 'Liquidación',
                        ),
                        value: transaction!.displayStatus ==
                                TransactionStatus.confirmed
                            ? _financialCopy(
                                context,
                                pt: 'Instantânea (HTLC)',
                                en: 'Instant (HTLC)',
                                es: 'Instantánea (HTLC)',
                              )
                            : _financialCopy(
                                context,
                                pt: 'Em processamento',
                                en: 'In progress',
                                es: 'En proceso',
                              ),
                        isHighlight: transaction!.displayStatus ==
                            TransactionStatus.confirmed,
                      ),
                    if (transaction!.showsOnchainConfirmations)
                      _ReceiptRow(
                        label: _financialCopy(context,
                            pt: 'Confirmações',
                            en: 'Confirmations',
                            es: 'Confirmaciones'),
                        value: () {
                          final target = transaction!.onchainConfirmationTarget
                              .clamp(1, 6);
                          final conf =
                              transaction!.confirmations.clamp(0, target);
                          if (conf <= 0) return 'Na mempool (0/$target)';
                          if (conf >= target) return '$conf/$target';
                          return '$conf/$target';
                        }(),
                        isHighlight: transaction!.confirmations >=
                            transaction!.onchainConfirmationTarget,
                      ),
                    if (transaction!.showsOnchainConfirmations &&
                        transaction!.blockHeight != null &&
                        transaction!.blockHeight! > 0)
                      _ReceiptRow(
                        label: _financialCopy(context,
                            pt: 'Bloco', en: 'Block', es: 'Bloque'),
                        value: '#${transaction!.blockHeight}',
                        isTechnical: true,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (_primaryAddress != null)
                _CopyablePanel(
                  title: _primaryAddressLabel,
                  value: _primaryAddress!,
                ),
              if (hasAdvancedDetails) ...[
                const SizedBox(height: 12),
                _DisclosurePanel(
                  title: advancedDetailsTitle,
                  children: [
                    if (_secondaryAddress != null) ...[
                      _CopyablePanel(
                        title: _secondaryAddressLabel,
                        value: _secondaryAddress!,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_referenceId != null) ...[
                      _CopyablePanel(
                        title: _referenceLabel,
                        value: _referenceId!,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_invoiceId != null) ...[
                      _CopyablePanel(
                        title: _financialCopy(
                          context,
                          pt: 'Código do pedido',
                          en: 'Request code',
                          es: 'Código del pedido',
                        ),
                        value: _invoiceId!,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_paymentHash != null) ...[
                      _CopyablePanel(
                        title: _financialCopy(
                          context,
                          pt: 'Código de confirmação',
                          en: 'Confirmation code',
                          es: 'Código de confirmación',
                        ),
                        value: _paymentHash!,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_lightningInvoice != null) ...[
                      _CopyablePanel(
                        title: _financialCopy(
                          context,
                          pt: 'Código Lightning',
                          en: 'Lightning code',
                          es: 'Código Lightning',
                        ),
                        value: _lightningInvoice!,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_description != null && _description!.trim().isNotEmpty)
                      _DetailPanel(
                        title: contextTitle,
                        compact: true,
                        child: Text(
                          ApiDisplayText.message(context, _description),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: monoTextColor, height: 1.45),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _headline(BuildContext context) {
    if (paymentLink != null) {
      return _financialCopy(
        context,
        pt: 'Pagamento por link',
        en: 'Payment link',
        es: 'Pago por enlace',
      );
    }

    return TransactionVisualSpec.fromTransaction(transaction!)
        .localizedLabel(context);
  }

  String _contextLabel(BuildContext context) {
    if (paymentLink != null) {
      return _financialCopy(
        context,
        pt: 'Pagamento por link',
        en: 'Payment link',
        es: 'Pago por enlace',
      );
    }
    if (transaction!.type == TransactionType.withdrawal) {
      return _financialCopy(
        context,
        pt: 'Saque externo',
        en: 'External withdrawal',
        es: 'Retiro externo',
      );
    }
    return transaction!.isInternal
        ? _financialCopy(
            context,
            pt: 'Movimentação Kerosene',
            en: 'Kerosene activity',
            es: 'Movimiento Kerosene',
          )
        : _financialCopy(
            context,
            pt: 'Rede Bitcoin',
            en: 'Bitcoin network',
            es: 'Red Bitcoin',
          );
  }

  String? get _primaryAddress {
    if (paymentLink != null) {
      return paymentLink!.depositAddress;
    }
    final value = resolvePrimaryTransactionAddress(transaction!).trim();
    return value.isEmpty ? null : value;
  }

  String get _primaryAddressLabel {
    if (paymentLink != null) {
      return 'Endereço de depósito';
    }
    return resolvePrimaryTransactionAddressLabel(transaction!);
  }

  String? get _secondaryAddress {
    if (paymentLink != null) {
      return null;
    }
    return resolveSecondaryTransactionAddress(transaction!);
  }

  String get _secondaryAddressLabel {
    return resolveSecondaryTransactionAddressLabel(transaction!);
  }

  String? get _referenceId {
    if (paymentLink != null) {
      return paymentLink!.txid ?? paymentLink!.id;
    }
    return transaction!.blockchainTxid ??
        transaction!.externalReference ??
        transaction!.id;
  }

  String get _referenceLabel {
    if (paymentLink?.txid != null || transaction?.blockchainTxid != null) {
      return 'Código da transação';
    }
    return 'Referência';
  }

  String? get _invoiceId {
    if (paymentLink != null) {
      return null;
    }
    final value = transaction!.invoiceId?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _paymentHash {
    if (paymentLink != null) {
      return null;
    }
    final value = transaction!.paymentHash?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _lightningInvoice {
    if (paymentLink != null) {
      return null;
    }
    final value = transaction!.lightningInvoice?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _description {
    if (paymentLink != null) {
      return paymentLink!.description;
    }
    return transaction!.description;
  }

  String get _summaryMessage {
    if (paymentLink != null) {
      if (paymentLink!.isVerifyingOnboarding) {
        return 'Estamos conferindo este pagamento para liberar a próxima etapa automaticamente.';
      }
      if (paymentLink!.hasObservedOnchainPayment && !paymentLink!.isPaid) {
        return 'A transação foi criada e está sendo validada na rede.';
      }
      if (paymentLink!.isPaid || paymentLink!.isCompleted) {
        return 'Pagamento recebido. Se houver uma próxima etapa, ela já pode ser liberada.';
      }
      if (paymentLink!.isExpired) {
        return 'Este link expirou e não aceita novos pagamentos.';
      }
      return 'Compartilhe o endereço abaixo quando quiser receber sem sair desta tela.';
    }

    switch (transaction!.status) {
      case TransactionStatus.pending:
      case TransactionStatus.confirming:
        return 'Esta movimentação ainda está em andamento. O status muda automaticamente assim que houver atualização.';
      case TransactionStatus.confirmed:
        return 'Movimentação concluída com sucesso e pronta para conferência.';
      case TransactionStatus.cancelled:
        return 'Esta movimentação foi cancelada ou expirou e não alterou o saldo.';
      case TransactionStatus.failed:
        return 'Não foi possível concluir esta movimentação. Revise os detalhes antes de tentar novamente.';
      case TransactionStatus.reconciling:
        return 'Esta movimentação precisa de revisão. O saldo pode ainda não refletir o resultado final.';
    }
  }
}

class _ContextChip extends StatelessWidget {
  final String label;

  const _ContextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: monoBorderStrongColor,
        showShadow: false,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: monoTextColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final bool compact;

  const _DetailPanel({
    required this.title,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: monoBorderStrongColor,
        showShadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: monoMutedTextColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CopyablePanel extends StatelessWidget {
  final String title;
  final String value;
  final bool compact;

  const _CopyablePanel({
    required this.title,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleValue = SafeDisplayText.displayIdentifier(
      context,
      value,
      leading: compact ? 8 : 10,
      trailing: compact ? 6 : 8,
    );
    return _DetailPanel(
      title: title,
      compact: compact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              visibleValue,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: monoTextColor,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              await HapticFeedback.selectionClick();
              if (!context.mounted) {
                return;
              }
              AppNotice.showSuccess(
                context,
                message: context.tr.apiDisplayCopied,
              );
            },
            icon: const Icon(KeroseneIcons.copy),
            color: monoTextColor,
            style: IconButton.styleFrom(
              backgroundColor: monoSurfaceRaisedColor,
              side: const BorderSide(color: monoBorderStrongColor),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final FinancialStatusMeta statusMeta;
  final IconData leadingIcon;
  final String headline;
  final String contextLabel;
  final String supportingText;
  final String primaryAmount;
  final String? secondaryAmount;
  final DateTime? createdAt;

  const _SummaryHero({
    required this.statusMeta,
    required this.leadingIcon,
    required this.headline,
    required this.contextLabel,
    required this.supportingText,
    required this.primaryAmount,
    required this.secondaryAmount,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: monoBorderStrongColor,
        showShadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: monochromePanelDecoration(
              color: monoSurfaceRaisedColor,
              borderColor: monoBorderStrongColor,
              showShadow: false,
            ),
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: monoTextColor, size: 24),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FinancialStatusBadge(meta: statusMeta),
              _ContextChip(label: contextLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: monoTextColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            supportingText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: monoMutedTextColor,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            primaryAmount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: monoTextColor,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          if (secondaryAmount != null) ...[
            const SizedBox(height: 8),
            Text(
              secondaryAmount!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: monoMutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 10),
            Text(
              AppDateTime.formatRelativeWithClock(context, createdAt!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: monoMutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclosurePanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DisclosurePanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: monoBorderStrongColor,
        showShadow: false,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: monoTextColor,
          collapsedIconColor: monoTextColor,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: monoTextColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  final List<Widget> children;

  const _ReceiptSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: monochromePanelDecoration(
        color: monoSurfaceAltColor,
        borderColor: monoBorderStrongColor,
        showShadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTechnical;
  final bool isHighlight;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isTechnical = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: monoMutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Text(
                '.' * (constraints.maxWidth / 3).floor(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: monoBorderStrongColor.withValues(alpha: 0.3),
                  letterSpacing: 2,
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: isTechnical
                      ? AppTypography.monoFontFamily
                      : AppTypography.fontFamily,
                  color: isHighlight ? monoTextColor : monoMutedTextColor,
                  fontWeight: isHighlight
                      ? FontWeight.w800
                      : (isTechnical ? FontWeight.w600 : FontWeight.w700),
                ),
          ),
        ],
      ),
    );
  }
}
