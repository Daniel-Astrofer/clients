import 'package:flutter/widgets.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';

/// Structured payload for the send review confirmation card.
class SendPaymentReviewCardData {
  final String recipientName;
  final String recipientAddress;
  final String transferAmountLabel;
  final String transferFiatLabel;
  final String totalAmountLabel;
  final String totalFiatLabel;
  final String networkLabel;

  /// Platform / Kerosene fee — null when not applicable (e.g. internal).
  final String? transactionFeeLabel;
  final String? transactionFeeFiatLabel;

  /// Network / mining fee — null when not applicable.
  final String? miningFeeLabel;
  final String? miningFeeFiatLabel;

  final bool isInternal;
  final bool isLightning;
  final bool isOnChain;

  const SendPaymentReviewCardData({
    required this.recipientName,
    required this.recipientAddress,
    required this.transferAmountLabel,
    required this.transferFiatLabel,
    required this.totalAmountLabel,
    required this.totalFiatLabel,
    required this.networkLabel,
    this.transactionFeeLabel,
    this.transactionFeeFiatLabel,
    this.miningFeeLabel,
    this.miningFeeFiatLabel,
    this.isInternal = false,
    this.isLightning = false,
    this.isOnChain = false,
  });
}

class InternalTransferReviewArgs<T> {
  final String title;
  final String amountBtcLabel;
  final String fiatAmountLabel;
  final String confirmLabel;
  final String submittingLabel;
  final String? destinationLabel;
  final String? networkLabel;
  final String? fromWalletLabel;
  final List<SendPaymentReviewRowData> rows;
  final SendPaymentReviewCardData card;
  final bool requiresFirstSendAck;
  final String? firstSendAddressPreview;
  final String? firstSendAddress;
  final String? authNextStepLabel;
  final Future<T?> Function(BuildContext context) onConfirm;
  final SendPaymentReceiptData? Function(T result)? receiptBuilder;

  /// Locked payment-request flows: show speed chips; amount stays fixed.
  final bool showFeeTierControls;
  final NetworkFeeTier? feeTier;
  final ValueChanged<NetworkFeeTier>? onFeeTierChanged;

  InternalTransferReviewArgs({
    this.title = '',
    required this.amountBtcLabel,
    required this.fiatAmountLabel,
    this.confirmLabel = '',
    this.submittingLabel = '',
    this.destinationLabel,
    this.networkLabel,
    this.fromWalletLabel,
    required this.rows,
    required this.card,
    this.requiresFirstSendAck = false,
    this.firstSendAddressPreview,
    this.firstSendAddress,
    this.authNextStepLabel,
    required this.onConfirm,
    this.receiptBuilder,
    this.showFeeTierControls = false,
    this.feeTier,
    this.onFeeTierChanged,
  });
}

class SendPaymentReceiptArgs<T> {
  final SendPaymentReceiptData data;
  final T result;

  SendPaymentReceiptArgs({
    required this.data,
    required this.result,
  });
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;

  CircularRevealClipper({required this.fraction});

  @override
  Path getClip(Size size) {
    // Start from bottom-center where the button is
    final center = Offset(size.width / 2, size.height - 80);
    final maxRadius = size.height * 1.5;
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxRadius * fraction));
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
