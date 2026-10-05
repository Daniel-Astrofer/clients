/// Aggregated account activity and balances for one statement period.
///
/// All monetary values are satoshis. Counts distinguish loaded records from
/// those included in totals so partial histories and excluded transactions are
/// visible to the caller instead of silently changing the report totals.
class StatementReport {
  /// Wallets included in the report and their period-end balances.
  final List<StatementWalletInsight> wallets;

  /// Time buckets containing each wallet's movement totals.
  final List<StatementMovementBucket> buckets;

  /// Per-wallet values used to render the period distribution chart.
  final List<StatementDistributionSegment> distribution;

  /// Total incoming value included in the period, in satoshis.
  final int incomingSats;

  /// Total outgoing value included in the period, in satoshis.
  final int outgoingSats;

  /// Network/miner fees included in the report, in satoshis.
  final int feeSats;

  /// Platform or service fees included in the report, in satoshis.
  final int serviceFeeSats;

  /// Value moved between the user's own wallets, kept separate from external flow.
  final int internalTransferSats;

  /// Net external movement represented by the report, in satoshis.
  final int netSats;

  /// Upper bound used to scale chart axes without clipping bucket values.
  final int axisMaxSats;

  /// Combined wallet balance represented at the end of the period, in satoshis.
  final int totalBalanceSats;

  /// Name of the wallet with the largest reported balance, or empty when absent.
  final String dominantWalletName;

  /// Whether source history was incomplete when this aggregate was calculated.
  final bool isPartial;

  /// Number of wallets represented in the report.
  final int walletCount;

  /// Number of transaction records loaded before period/status filtering.
  final int loadedTransactionCount;

  /// Number of transactions contributing to report totals.
  final int includedTransactionCount;

  /// Number of failed transactions excluded from report totals.
  final int ignoredFailedTransactionCount;

  /// Number of transactions excluded because they fall outside the period.
  final int ignoredOutOfPeriodTransactionCount;

  /// Number of records whose movement could not be classified.
  final int unclassifiedTransactionCount;

  /// Inclusive beginning boundary used to select transactions.
  final DateTime periodStart;

  /// Exclusive ending boundary used to select transactions.
  final DateTime periodEnd;

  /// Creates a statement aggregate using already-classified movement totals.
  const StatementReport({
    required this.wallets,
    required this.buckets,
    required this.distribution,
    required this.incomingSats,
    required this.outgoingSats,
    required this.feeSats,
    required this.serviceFeeSats,
    required this.internalTransferSats,
    required this.netSats,
    required this.axisMaxSats,
    required this.totalBalanceSats,
    required this.dominantWalletName,
    required this.isPartial,
    required this.walletCount,
    required this.loadedTransactionCount,
    required this.includedTransactionCount,
    required this.ignoredFailedTransactionCount,
    required this.ignoredOutOfPeriodTransactionCount,
    required this.unclassifiedTransactionCount,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Sum of network and platform fees included in the report, in satoshis.
  int get totalFeesSats => feeSats + serviceFeeSats;
}

/// Supported calendar windows for a generated account statement.
enum StatementReportPeriod { monthly, weekly, annual }

/// Identity, matching aliases, and closing balance for one statement wallet.
class StatementWalletInsight {
  /// Stable wallet identifier used to join this value to movement buckets.
  final String id;

  /// User-facing wallet label.
  final String name;

  /// Normalized wallet names/addresses used to attribute transactions.
  final Set<String> matchKeys;

  /// Wallet balance at the report boundary, in satoshis.
  final int balanceSats;

  /// Creates one wallet's identity and balance entry for a report.
  const StatementWalletInsight({
    required this.id,
    required this.name,
    required this.matchKeys,
    required this.balanceSats,
  });
}

/// Totals for one labeled interval in the statement time series.
class StatementMovementBucket {
  /// Display label for the represented interval.
  final String label;

  /// Start boundary of the interval.
  final DateTime start;

  /// End boundary of the interval.
  final DateTime end;

  /// Per-wallet movement values accumulated within this interval.
  final List<StatementWalletBucketValue> values;

  /// Creates one time-series interval with its wallet-level values.
  const StatementMovementBucket({
    required this.label,
    required this.start,
    required this.end,
    required this.values,
  });
}

/// One wallet's movement total within a statement time bucket.
class StatementWalletBucketValue {
  /// Wallet identifier matching a [StatementWalletInsight.id].
  final String walletId;

  /// Net value attributed to this wallet and interval, in satoshis.
  final int sats;

  /// Creates a wallet movement value for one bucket.
  const StatementWalletBucketValue({
    required this.walletId,
    required this.sats,
  });
}

/// One wallet's share of the statement distribution chart.
class StatementDistributionSegment {
  /// Wallet identifier represented by this segment.
  final String walletId;

  /// Display label for the wallet segment.
  final String label;

  /// Actual balance or movement represented, in satoshis.
  final int sats;

  /// Nonnegative visual magnitude used to retain a visible chart segment.
  final int visualSats;

  /// Segment's percentage of the whole distribution, from 0 to 100.
  final double percent;

  /// Creates one chart segment while preserving actual and visual magnitudes.
  const StatementDistributionSegment({
    required this.walletId,
    required this.label,
    required this.sats,
    required this.visualSats,
    required this.percent,
  });
}
