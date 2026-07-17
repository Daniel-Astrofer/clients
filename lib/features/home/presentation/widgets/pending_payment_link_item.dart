import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/widgets/activity_glyph.dart';

class PendingPaymentLinkItem extends StatelessWidget {
  final PaymentLink paymentLink;
  final VoidCallback? onTap;

  const PendingPaymentLinkItem({
    super.key,
    required this.paymentLink,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountLabel = 'VALOR';
    final timeLeft = paymentLink.expiresAt != null
        ? paymentLink.expiresAt!.difference(DateTime.now())
        : Duration.zero;

    final isExpired =
        timeLeft.isNegative && !paymentLink.isCompleted && !paymentLink.isPaid;
    final isCompleted = paymentLink.isCompleted || paymentLink.isPaid;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final error = Theme.of(context).colorScheme.error;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KeroseneMotion.medium,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        width: 280,
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          // Distinct from settled transaction cards (link product, not movement).
          border: Border.all(
            color: isExpired
                ? error.withValues(alpha: 0.35)
                : onSurface.withValues(alpha: 0.20),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // QR primary + rail network pip (LN / on-chain / internal).
                ActivityGlyph.forPaymentLink(paymentLink, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? 'RECEBIDO'
                            : (isExpired ? 'EXPIRADO' : 'PENDENTE'),
                        style: TextStyle(
                          color: isExpired
                              ? error
                              : onSurface.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (!isCompleted && !isExpired)
                        Text(
                          _formatDuration(timeLeft),
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.24),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      paymentLink.amountBtc.toStringAsFixed(8),
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: AppTypography.financialFontFamily,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              paymentLink.description.isNotEmpty
                  ? paymentLink.description
                  : (paymentLink.isLightningPaymentRequest
                      ? 'Aguardando pagamento Lightning (BOLT11)...'
                      : 'Aguardando pagamento via rede Bitcoin...'),
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCompleted
                      ? (paymentLink.isLightningPaymentRequest
                          ? 'Pago · Lightning'
                          : 'Confirmado')
                      : (paymentLink.isLightningPaymentRequest
                          ? 'Fatura Lightning'
                          : 'Link de Pagamento'),
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.2),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  KeroseneIcons.chevronRight,
                  size: 12,
                  color: onSurface.withValues(alpha: 0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
