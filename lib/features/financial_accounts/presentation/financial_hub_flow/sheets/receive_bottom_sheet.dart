import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_presentation_support.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import '../theme/financial_hub_tokens.dart';

/// Modal bottom sheet displaying receive options, QR Code, address copy, and address rotation.
class ReceiveBottomSheet extends ConsumerStatefulWidget {
  final BitcoinAccount account;
  final ReceivingRequestView? request;
  final ValueChanged<ReceivingRequestView>? onAddressRotated;

  const ReceiveBottomSheet({
    super.key,
    required this.account,
    this.request,
    this.onAddressRotated,
  });

  static Future<void> show(
    BuildContext context, {
    required BitcoinAccount account,
    ReceivingRequestView? request,
    ValueChanged<ReceivingRequestView>? onAddressRotated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiveBottomSheet(
        account: account,
        request: request,
        onAddressRotated: onAddressRotated,
      ),
    );
  }

  @override
  ConsumerState<ReceiveBottomSheet> createState() => _ReceiveBottomSheetState();
}

class _ReceiveBottomSheetState extends ConsumerState<ReceiveBottomSheet> {
  bool _busyRotating = false;

  @override
  Widget build(BuildContext context) {
    final address = widget.request?.address ?? widget.account.id;
    final bip21 = widget.request?.bip21 ?? address;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          left: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Title in Playfair Display
          Text(
            'Receber Bitcoin',
            style: FinancialHubTokens.titleH1(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'Use este QR Code ou endereço para receber sats nesta conta.',
            style: FinancialHubTokens.body(fontSize: 13),
          ),
          const SizedBox(height: 20),

          // QR Code Container
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: QrImageView(
                data: bip21,
                version: QrVersions.auto,
                size: 180.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Address field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Endereço de Recebimento',
                        style: FinancialHubTokens.caption(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: FinancialHubTokens.numberText(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    AppNotice.showSuccess(
                      context,
                      title: 'Copiado',
                      message: 'Endereço copiado para a área de transferência',
                    );
                  },
                  icon: Icon(KeroseneIcons.copy, color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busyRotating || widget.account.isWatchOnly
                      ? null
                      : _rotateAddress,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side:
                        BorderSide(color: Theme.of(context).dividerColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _busyRotating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : const Icon(KeroseneIcons.refresh, size: 18),
                  label: Text(
                    'Rotacionar Endereço',
                    style: FinancialHubTokens.buttonLabel(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rotateAddress() async {
    setState(() => _busyRotating = true);
    try {
      final rotated = await ref
          .read(bitcoinAccountsProvider.notifier)
          .rotateReceiveAddress(accountId: widget.account.id);
      widget.onAddressRotated?.call(rotated);
      if (!mounted) return;
      AppNotice.showSuccess(
        context,
        title: 'Novo Endereço Gerado',
        message: bitcoinAccountDisplayValue(rotated.address),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: 'Erro',
        message: 'Não foi possível rotacionar o endereço agora.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyRotating = false);
      }
    }
  }
}
