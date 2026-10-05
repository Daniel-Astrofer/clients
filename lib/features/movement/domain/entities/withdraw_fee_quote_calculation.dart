/// Determines whether quoted fees are added to the debit or deducted from payout.
enum WithdrawFeeMode {
  /// The requested amount reaches the recipient; fees increase the sender debit.
  senderPays,

  /// Fees are deducted from the requested amount before the recipient is paid.
  recipientPays,
}

/// Fee breakdown and resulting payout/debit for one Bitcoin withdrawal quote.
///
/// Amounts are BTC. Invalid negative fee inputs are clamped to zero by
/// [resolve], while nonpositive requested amounts produce a zero quote.
class WithdrawFeeQuoteCalculation {
  /// Conversion factor used when comparing BTC values at satoshi precision.
  static const int _satsPerBtc = 100000000;

  /// Charging mode used to calculate this quote.
  final WithdrawFeeMode mode;

  /// Amount requested by the caller before any recipient-paid deductions.
  final double requestedAmountBtc;

  /// Amount that the destination receives after applicable deductions.
  final double receiverAmountBtc;

  /// Platform fee rate applied to the recipient amount.
  final double platformFeeRate;

  /// Platform fee amount calculated for this quote.
  final double platformFeeBtc;

  /// Network fee amount included in this quote.
  final double networkFeeBtc;

  /// Total amount removed from the sender's balance.
  final double totalDebitedBtc;

  /// Creates a fully resolved quote; use [resolve] to apply fee rules.
  const WithdrawFeeQuoteCalculation({
    required this.mode,
    required this.requestedAmountBtc,
    required this.receiverAmountBtc,
    required this.platformFeeRate,
    required this.platformFeeBtc,
    required this.networkFeeBtc,
    required this.totalDebitedBtc,
  });

  /// Adds network and platform fees for display or reconciliation.
  double get totalFeesBtc => platformFeeBtc + networkFeeBtc;

  /// Whether this quote deducts fees from the requested recipient amount.
  bool get deductsFees => mode == WithdrawFeeMode.recipientPays;

  /// Checks available balance at satoshi precision against the quoted debit.
  ///
  /// A nonpositive debit is considered covered. Non-finite inputs are rejected
  /// for positive debits so NaN/infinity cannot authorize an insufficient balance.
  static bool hasSufficientBalance({
    required double availableBtc,
    required double totalDebitedBtc,
  }) {
    if (totalDebitedBtc <= 0) {
      return true;
    }
    if (!availableBtc.isFinite || !totalDebitedBtc.isFinite) {
      return false;
    }

    return _toSats(availableBtc) >= _toSats(totalDebitedBtc);
  }

  /// Calculates payout, platform fee, network fee, and total sender debit.
  ///
  /// Negative fee rate and network fee inputs are treated as zero. If the
  /// requested amount is nonpositive, the returned quote has zero monetary
  /// outputs while retaining the supplied mode and requested amount.
  static WithdrawFeeQuoteCalculation resolve({
    required WithdrawFeeMode mode,
    required double requestedAmountBtc,
    required double platformFeeRate,
    required double networkFeeBtc,
  }) {
    if (requestedAmountBtc <= 0) {
      return WithdrawFeeQuoteCalculation(
        mode: mode,
        requestedAmountBtc: requestedAmountBtc,
        receiverAmountBtc: 0,
        platformFeeRate: platformFeeRate,
        platformFeeBtc: 0,
        networkFeeBtc: 0,
        totalDebitedBtc: 0,
      );
    }

    final safeNetworkFeeBtc = networkFeeBtc < 0 ? 0.0 : networkFeeBtc;
    final safePlatformFeeRate = platformFeeRate < 0 ? 0.0 : platformFeeRate;
    final receiverAmountBtc = mode == WithdrawFeeMode.senderPays
        ? requestedAmountBtc
        : _receiverAmountAfterFees(
            requestedAmountBtc: requestedAmountBtc,
            platformFeeRate: safePlatformFeeRate,
            networkFeeBtc: safeNetworkFeeBtc,
          );
    final platformFeeBtc = receiverAmountBtc * safePlatformFeeRate;
    final totalDebitedBtc = receiverAmountBtc <= 0
        ? 0.0
        : receiverAmountBtc + platformFeeBtc + safeNetworkFeeBtc;

    return WithdrawFeeQuoteCalculation(
      mode: mode,
      requestedAmountBtc: requestedAmountBtc,
      receiverAmountBtc: receiverAmountBtc,
      platformFeeRate: safePlatformFeeRate,
      platformFeeBtc: platformFeeBtc,
      networkFeeBtc: safeNetworkFeeBtc,
      totalDebitedBtc: totalDebitedBtc,
    );
  }

  /// Solves the recipient-paid equation after subtracting network fees.
  ///
  /// Dividing by `1 + rate` ensures the platform percentage is computed
  /// from the final amount delivered to the recipient.
  static double _receiverAmountAfterFees({
    required double requestedAmountBtc,
    required double platformFeeRate,
    required double networkFeeBtc,
  }) {
    final netBeforePlatformFee = requestedAmountBtc - networkFeeBtc;
    if (netBeforePlatformFee <= 0) {
      return 0;
    }
    return netBeforePlatformFee / (1 + platformFeeRate);
  }

  /// Converts BTC to the nearest satoshi for balance comparisons.
  static int _toSats(double btc) => (btc * _satsPerBtc).round();
}
