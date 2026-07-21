// ignore_for_file: use_key_in_widget_constructors, unused_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/features/presentation/widgets/bitcoin_address_blocks.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/movement/data/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/statement_transaction_card.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'bitcoin_accounts_provider.dart';
import 'bitcoin_widgets/bottom_sheets.dart';
import 'bitcoin_accounts_internal_sections.dart';
import 'bitcoin_accounts_advanced_sections.dart';
import 'bitcoin_screens/internal_account_creation_screen.dart';

import 'bitcoin_accounts_screen.dart';

class _BitcoinAccountsDetailsCopy {
  const _BitcoinAccountsDetailsCopy._();

  static const renameWallet = 'Trocar nome';
  static const filter = 'Filtrar';
}

class ReceiveMaterialDetails extends StatelessWidget {
  final BitcoinAccount account;
  final AsyncValue<List<ReceivingRequestView>> requestsAsync;
  final ReceivingRequestView? receiveAddressOverride;
  final VoidCallback? onRotate;
  final bool rotating;

  const ReceiveMaterialDetails({
    required this.account,
    required this.requestsAsync,
    required this.receiveAddressOverride,
    this.onRotate,
    this.rotating = false,
  });

  @override
  Widget build(BuildContext context) {
    if (account.isWatchOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountDetailRows(
            rows: [
              AccountDetail(
                'Fingerprint',
                bitcoinAccountDisplayValue(account.xpubFingerprint),
                copyable: (account.xpubFingerprint ?? '').trim().isNotEmpty,
              ),
              AccountDetail(
                'Cold wallet',
                coldWalletIdForAccount(account),
                copyable: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const AccountOptionNote(
            text: 'Carteiras watch-only não emitem endereço pelo app.',
          ),
        ],
      );
    }

    return requestsAsync.when(
      loading: () => const InlineLoadingState(),
      error: (_, __) => MiniEmptyState(
        text: context.tr.bitcoinReceiveRequestsLoadErrorMessage,
      ),
      data: (requests) {
        final request = receiveAddressOverride ??
            (requests.isEmpty ? null : requests.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountDetailRows(
              rows: [
                AccountDetail(
                  'Endereço',
                  bitcoinAccountDisplayValue(request?.address),
                  copyable: (request?.address ?? '').trim().isNotEmpty,
                ),
                AccountDetail(
                  'BIP21',
                  bitcoinAccountDisplayValue(request?.bip21),
                  copyable: (request?.bip21 ?? '').trim().isNotEmpty,
                ),
                if (request?.amountSats != null)
                  AccountDetail('Valor', formatSats(request!.amountSats!)),
                if (request != null)
                  AccountDetail(
                    'Expiração',
                    request.expiry.isEmpty
                        ? context.tr.bitcoinReceiveRequestsNoExpiry
                        : request.expiry,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AccountOptionActionButton(
              label: context.tr.btcAccountsRotateAddress,
              icon: KeroseneIcons.refresh,
              busy: rotating,
              onPressed: onRotate,
            ),
          ],
        );
      },
    );
  }
}

class AccountOptionActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool destructive;

  const AccountOptionActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);
    return OutlinedButton.icon(
      style: colors.outlinedButtonStyle(
        minHeight: 42,
        foregroundColor: destructive
            ? KeroseneBrandTokens.error
            : KeroseneBrandTokens.textPrimary,
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const CupertinoActivityIndicator(radius: 7.5)
          : Icon(icon, size: 15),
      label: Text(label),
    );
  }
}

class AccountOptionNote extends StatelessWidget {
  final String text;

  const AccountOptionNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.inter(
        color: KeroseneBrandTokens.textMuted,
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0,
      ),
    );
  }
}

Future<String?> askWalletName(
  BuildContext context,
  BitcoinAccount account,
) async {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return WalletNameDialog(initialName: account.label.trim());
    },
  );
}

class WalletNameDialog extends StatefulWidget {
  final String initialName;

  const WalletNameDialog({required this.initialName});

  @override
  State<WalletNameDialog> createState() => WalletNameDialogState();
}

class WalletNameDialogState extends State<WalletNameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(_BitcoinAccountsDetailsCopy.renameWallet),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 96,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: context.tr.coldCreateWalletName),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr.cancel),
        ),
        FilledButton(
          onPressed: submit,
          child: Text(context.tr.save),
        ),
      ],
    );
  }
}

Future<bool> confirmWalletArchive(
  BuildContext context,
  BitcoinAccount account,
) async {
  final title = account.isWatchOnly
      ? 'Arquivar acompanhamento'
      : account.isCustodialOnchain
          ? 'Bloquear carteira'
          : 'Bloquear cartão';
  final message = account.isWatchOnly
      ? 'Esta carteira deixará de aparecer como acompanhamento ativo.'
      : 'Esta carteira deixará de aparecer como ativa para movimentação.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr.confirm),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

class AccountExpansionItem extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const AccountExpansionItem({
    required this.title,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);

    return AnimatedContainer(
      duration: KeroseneMotion.medium,
      curve: KeroseneMotion.standard,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(
                      accountOptionIcon(title),
                      color: colors.text,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          color: colors.text.withValues(alpha: 0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: KeroseneMotion.medium,
                      turns: expanded ? 0.5 : 0,
                      child: Icon(
                        KeroseneIcons.chevronDown,
                        color: colors.mutedText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: KeroseneMotion.medium,
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

IconData accountOptionIcon(String title) {
  // Match labels regardless of locale (compare against known ARB values).
  final normalized = title.trim().toUpperCase();
  if (normalized.contains('STATUS')) return KeroseneIcons.security;
  if (normalized.contains('RECEB') || normalized.contains('RECEIVE') || normalized.contains('RECEPCI')) {
    return KeroseneIcons.download;
  }
  if (normalized.contains('NOME') || normalized.contains('NAME') || normalized.contains('NOMBRE')) {
    return KeroseneIcons.user;
  }
  if (normalized.contains('PÚBLICO') || normalized.contains('PUBLIC') || normalized.contains('MATERIAL')) {
    return KeroseneIcons.settings;
  }
  if (normalized.contains('UTXO')) return KeroseneIcons.database;
  if (normalized.contains('PSBT')) return KeroseneIcons.document;
  return KeroseneIcons.settings;
}

class AccountDetail {
  final String label;
  final String value;
  final bool copyable;

  const AccountDetail(
    this.label,
    this.value, {
    this.copyable = false,
  });
}

class AccountDetailRows extends StatelessWidget {
  final List<AccountDetail> rows;

  const AccountDetailRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++)
          AccountDetailRow(
            row: rows[index],
            showDivider: index != rows.length - 1,
          ),
      ],
    );
  }
}

class AccountDetailRow extends StatelessWidget {
  final AccountDetail row;
  final bool showDivider;

  const AccountDetailRow({
    required this.row,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: KeroseneBrandTokens.borderSubtle,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              maxLines: row.copyable ? 5 : 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: AppTypography.technicalMono(
                textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: KeroseneBrandTokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ),
          if (row.copyable) ...[
            const SizedBox(width: 4),
            InlineCopyButton(
              value: row.value,
              semanticLabel: 'Copiar ${row.label}',
            ),
          ],
        ],
      ),
    );
  }
}

class InlineLoadingState extends StatelessWidget {
  const InlineLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(
        child: CupertinoActivityIndicator(radius: 9),
      ),
    );
  }
}

class FocusedAccountHistory extends ConsumerStatefulWidget {
  final BitcoinAccount account;
  final AsyncValue<List<Transaction>> transactionsAsync;
  final AsyncValue<List<ReceivingRequestView>> requestsAsync;

  const FocusedAccountHistory({
    super.key,
    required this.account,
    required this.transactionsAsync,
    required this.requestsAsync,
  });

  @override
  ConsumerState<FocusedAccountHistory> createState() =>
      _FocusedAccountHistoryState();
}

class _FocusedAccountHistoryState extends ConsumerState<FocusedAccountHistory> {
  final Set<String> _expandedTransactionIds = <String>{};

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    String label;
    if (txDate == today) {
      label = 'Hoje';
    } else if (txDate == yesterday) {
      label = 'Ontem';
    } else {
      final months = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ];
      label = '${date.day} de ${months[date.month - 1]}';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 12.0),
      child: Text(
        label,
        style: AppTypography.display.copyWith(
          color: Colors.white,
          fontSize: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);
    final requests =
        widget.requestsAsync.asData?.value ?? const <ReceivingRequestView>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr.primaryNavHistory,
                style: AppTypography.newsreader(
                  color: colors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            Icon(
              KeroseneIcons.moveHorizontal,
              color: colors.mutedText,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _BitcoinAccountsDetailsCopy.filter.toUpperCase(),
              style: AppTypography.inter(
                color: colors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        widget.transactionsAsync.when(
          loading: () => const CompactLoadingPanel(),
          error: (_, __) => BareHistoryMessage(
            text: context.tr.bitcoinAccountsErrorMessage,
          ),
          data: (transactions) {
            var history = transactions;
            // Cold: fill PSBT broadcasts that are not yet in KFE history.
            if (widget.account.isWatchOnly) {
              final coldId = (widget.account.coldWalletId ?? widget.account.id)
                  .trim();
              if (coldId.isNotEmpty) {
                final psbts = ref
                        .watch(bitcoinColdWalletPsbtsProvider(coldId))
                        .asData
                        ?.value ??
                    const <PsbtWorkflowView>[];
                history = mergeColdPsbtBroadcastsIntoHistory(
                  transactions: history,
                  workflows: psbts,
                  coldWalletId: coldId,
                );
              }
            }
            final rows = transactionsForAccount(
              account: widget.account,
              transactions: history,
              requests: requests,
            ).take(8).toList(growable: false);

            if (rows.isEmpty) {
              return BareHistoryMessage(
                text: widget.account.isWatchOnly
                    ? 'Sem movimentos indexados nesta cold. O saldo observado vem da blockchain; UTXOs e envios PSBT aparecem quando detectados.'
                    : 'Sem transações neste cartão.',
              );
            }

            return StatementTransactionScrollStack(
              itemCount: rows.length,
              itemGap: 12,
              itemBuilder: (context, index) {
                final tx = rows[index];
                
                Widget? dateHeader;
                if (index == 0) {
                  dateHeader = _buildDateHeader(tx.timestamp.toLocal());
                } else {
                  final previousTx = rows[index - 1];
                  if (!_isSameDay(tx.timestamp.toLocal(), previousTx.timestamp.toLocal())) {
                    dateHeader = _buildDateHeader(tx.timestamp.toLocal());
                  }
                }

                final expanded = _expandedTransactionIds.contains(tx.id);
                final tile = StatementTransactionCard(
                  transaction: tx,
                  expanded: expanded,
                  mode: StatementTransactionCardMode.stacked,
                  onTap: () {
                    setState(() {
                      if (expanded) {
                        _expandedTransactionIds.remove(tx.id);
                      } else {
                        _expandedTransactionIds.add(tx.id);
                      }
                    });
                  },
                );

                if (dateHeader != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) const SizedBox(height: 16),
                      dateHeader,
                      const SizedBox(height: 8),
                      tile,
                    ],
                  );
                }
                return tile;
              },
            );
          },
        ),
      ],
    );
  }
}

class BareHistoryMessage extends StatelessWidget {
  final String text;

  const BareHistoryMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: AppTypography.inter(
          color: KeroseneBrandTokens.textMuted,
          fontSize: 13,
          height: 1.35,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class FocusedHistoryRow extends StatelessWidget {
  final Transaction transaction;
  final bool showDivider;

  const FocusedHistoryRow({
    required this.transaction,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BitcoinAccountsColors.of(context);
    final title = transaction.description?.trim().isNotEmpty == true
        ? transaction.description!.trim()
        : transactionTitle(transaction);
    final detail = bitcoinAccountHistoryDetail(transaction);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.text.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.isInternal
                      ? KeroseneIcons.wallet
                      : KeroseneIcons.history,
                  color: colors.text,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.inter(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.technicalMono(
                        textStyle:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colors.mutedText,
                                  fontSize: 11,
                                  letterSpacing: 0,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                bitcoinAccountHistoryTimestampLabel(transaction.timestamp),
                textAlign: TextAlign.right,
                style: AppTypography.inter(
                  color: colors.mutedText,
                  fontSize: 10,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            signedSats(transaction),
            style: AppTypography.technicalMono(
              textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: 0,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TransparentStatusPill(
              text: bitcoinAccountTransactionStatusLabel(
                  context, transaction.status),
            ),
          ),
        ],
      ),
    );
  }
}

class TransparentStatusPill extends StatelessWidget {
  final String text;

  const TransparentStatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    const accent = KeroseneBrandTokens.bitcoinOrange;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.inter(
            color: accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
