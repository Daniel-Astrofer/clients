import 'package:flutter/material.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/domain/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/widgets/transaction_visual_tokens.dart';

/// Transaction color system.
///
/// - **Amounts** are always near-black for max readability on light card fills.
/// - Surfaces use expanded [TxVisualVariant] (16 variants: rail × direction +
///   product + lifecycle) — not only white/orange/yellow.
/// - Status accents (rings) stay saturated against light surfaces.
enum TransactionCardSurface {
  /// Kerosene-to-Kerosene — neutral light paper.
  internal,

  /// On-chain — orange / peach wash.
  onchain,

  /// Lightning — soft gold (not competing with on-chain orange).
  lightning,
}

/// Semantic lifecycle of a movement (maps from [TransactionStatus]).
enum TransactionStatusTone {
  confirmed,
  confirming,
  pending,
  cancelled,
  failed,
}

/// Single source of truth for transaction UI colors.
abstract final class TransactionPalette {
  // ── Ink on light surfaces ────────────────────────────────────────────────
  /// Titles and **amounts** — pure black for maximum contrast.
  static const Color inkPrimary = Color(0xFF000000);

  /// Counterparty / secondary lines.
  static const Color inkSecondary = Color(0xFF4B4F57);

  /// Timestamp / meta.
  static const Color inkTertiary = Color(0xFF6E737C);

  /// Text on pure black rows (bank mode list).
  static const Color inkOnDark = Color(0xFFF2F2F3);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color statusConfirmed = Color(0xFF1F8A4C);
  static const Color statusConfirmedSoft = Color(0xFF2FA85F);

  static const Color statusPending = Color(0xFFE08912);
  static const Color statusPendingSoft = Color(0xFFF0A020);

  static const Color statusConfirming = Color(0xFFD4780C);
  static const Color statusConfirmingSoft = Color(0xFFE89218);

  static const Color statusFailed = Color(0xFFC43C3C);
  static const Color statusFailedSoft = Color(0xFFD45555);
  static const Color statusCancelled = Color(0xFFB04A4A);

  /// Empty ring track on light cards.
  static const Color statusTrack = Color(0xFF9AA0A8);

  // ── Amounts: always black (no green/red amount tint) ─────────────────────
  static const Color amountCredit = inkPrimary;
  static const Color amountDebit = inkPrimary;
  static const Color amountNeutral = inkPrimary;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Neutral paper.
  static const Color surfaceInternal = Color(0xFFF4F4F5);
  static const Color borderInternal = Color(0xFFD8DADF);

  /// On-chain — quiet warm paper (rail shown by glyph, not neon wash).
  static const Color surfaceOnchain = Color(0xFFF6F1EA);
  static const Color borderOnchain = Color(0xFFD8D0C6);

  /// Lightning — quiet neutral paper.
  static const Color surfaceLightning = Color(0xFFF3F2EE);
  static const Color borderLightning = Color(0xFFD5D2C9);

  static const Color surfaceDivider = Color(0x290F0F10);

  /// Icon disc.
  static const Color iconWell = Color(0xFF141416);
  static const Color iconWellBorder = Color(0xFF2A2A2E);

  // ── Resolvers ────────────────────────────────────────────────────────────

  static TransactionCardSurface surfaceFor(Transaction tx) {
    if (tx.isLightning) return TransactionCardSurface.lightning;
    if (tx.isInternal) return TransactionCardSurface.internal;
    return TransactionCardSurface.onchain;
  }

  static TransactionStatusTone toneFor(Transaction tx) {
    if (tx.isCancelled) return TransactionStatusTone.cancelled;
    // 24h with zero backend confs while still open → treat as not confirmed.
    if (tx.isUnconfirmedExpired || tx.status == TransactionStatus.failed) {
      return TransactionStatusTone.failed;
    }
    if (tx.status == TransactionStatus.confirmed || tx.isConfirmed) {
      return TransactionStatusTone.confirmed;
    }
    // Only treat block confs as "confirming" for real on-chain rails.
    if (tx.status == TransactionStatus.confirming ||
        (tx.showsOnchainConfirmations && tx.confirmations > 0)) {
      return TransactionStatusTone.confirming;
    }
    return TransactionStatusTone.pending;
  }

  static Color backgroundFor(TransactionCardSurface surface) {
    return switch (surface) {
      TransactionCardSurface.internal => surfaceInternal,
      TransactionCardSurface.onchain => surfaceOnchain,
      TransactionCardSurface.lightning => surfaceLightning,
    };
  }

  static Color borderFor(TransactionCardSurface surface) {
    return switch (surface) {
      TransactionCardSurface.internal => borderInternal,
      TransactionCardSurface.onchain => borderOnchain,
      TransactionCardSurface.lightning => borderLightning,
    };
  }

  static Color statusStrong(TransactionStatusTone tone) {
    return switch (tone) {
      TransactionStatusTone.confirmed => statusConfirmed,
      TransactionStatusTone.confirming => statusConfirming,
      TransactionStatusTone.pending => statusPending,
      TransactionStatusTone.cancelled => statusCancelled,
      TransactionStatusTone.failed => statusFailed,
    };
  }

  static Color statusSoft(TransactionStatusTone tone) {
    return switch (tone) {
      TransactionStatusTone.confirmed => statusConfirmedSoft,
      TransactionStatusTone.confirming => statusConfirmingSoft,
      TransactionStatusTone.pending => statusPendingSoft,
      TransactionStatusTone.cancelled => statusCancelled,
      TransactionStatusTone.failed => statusFailedSoft,
    };
  }

  /// Amounts are always black on card surfaces.
  static Color amountColor(Transaction tx) => inkPrimary;

  static Color iconAccent(Transaction tx) {
    return statusStrong(toneFor(tx));
  }
}

/// Resolved style bundle for a single statement card.
class TransactionCardColors {
  final Color background;
  final Color border;
  final Color title;
  final Color subtitle;
  final Color meta;
  final Color amount;
  final Color divider;
  final Color iconWell;
  final Color iconWellBorder;
  final Color icon;
  final Color statusStrong;
  final Color statusSoft;
  final Color statusTrack;
  final TransactionCardSurface surface;
  final TransactionStatusTone tone;

  const TransactionCardColors({
    required this.background,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.amount,
    required this.divider,
    required this.iconWell,
    required this.iconWellBorder,
    required this.icon,
    required this.statusStrong,
    required this.statusSoft,
    required this.statusTrack,
    required this.surface,
    required this.tone,
  });

  factory TransactionCardColors.resolve(
    Transaction tx, {
    List<Wallet> wallets = const [],
    List<BitcoinAccount> accounts = const [],
  }) {
    final axes = TransactionAxes.classify(
      tx,
      wallets: wallets,
      accounts: accounts,
    );
    final surface = TransactionVisualTokens.legacySurfaceFor(axes.rail);
    final tone = TransactionPalette.toneFor(tx);
    return TransactionCardColors(
      // Expanded paper fills (16 variants) instead of 3 rail-only colors.
      background: TransactionVisualTokens.backgroundFor(axes.variant),
      border: TransactionVisualTokens.borderFor(axes.variant),
      title: TransactionPalette.inkPrimary,
      subtitle: TransactionPalette.inkSecondary,
      meta: TransactionPalette.inkTertiary,
      amount: TransactionPalette.amountColor(tx),
      divider: TransactionPalette.surfaceDivider,
      iconWell: TransactionPalette.iconWell,
      iconWellBorder: TransactionPalette.iconWellBorder,
      icon: TransactionPalette.inkOnDark,
      statusStrong: TransactionPalette.statusStrong(tone),
      statusSoft: TransactionPalette.statusSoft(tone),
      statusTrack: TransactionPalette.statusTrack,
      surface: surface,
      tone: tone,
    );
  }
}
