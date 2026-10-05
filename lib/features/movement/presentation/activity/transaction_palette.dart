import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/activity_surface_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_taxonomy.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_visual_tokens.dart';
import 'package:kerosene/design_system/foundation/theme/home_surface_tokens.dart';

/// Transaction color system.
///
/// - **Amounts** are always near-black for max readability on light card fills.
/// - Surfaces use expanded [TxVisualVariant] (16 variants: rail × direction +
///   product + lifecycle) — not only white/orange/yellow.
/// - Status accents delegate to [KeroseneBrandTokens.success/warning/error].
/// - Light card surface colors are local (specific to activity statement cards).
enum TransactionCardSurface { internal, onchain, lightning }

/// Semantic lifecycle of a movement (maps from [TransactionStatus]).
enum TransactionStatusTone { confirmed, confirming, pending, cancelled, failed }

/// Single source of truth for transaction UI colors.
///
/// ## Design rules
/// - Ink on light surfaces: `inkPrimary`, `inkSecondary`, `inkTertiary`.
/// - Status: delegates to [KeroseneBrandTokens] (green success, amber warning, red error).
/// - Card surfaces: light paper per rail (internal/onchain/lightning).
/// - Amounts always black on card surfaces (no green/red tint).
abstract final class TransactionPalette {
  // ── Ink on light card surfaces ──────────────────────────────────────────
  /// Titles and amounts.
  static const Color inkPrimary = ActivitySurfaceTokens.inkPrimary;
  static const Color inkSecondary = ActivitySurfaceTokens.inkSecondary;
  static const Color inkTertiary = ActivitySurfaceTokens.inkTertiary;
  static const Color inkOnDark = ActivitySurfaceTokens.inkOnDark;

  // ── Status (delegates to brand tokens) ───────────────────────────────────
  static Color get statusConfirmed => KeroseneBrandTokens.success;
  static Color get statusConfirmedSoft =>
      KeroseneBrandTokens.success.withValues(alpha: 0.85);
  static Color get statusPending => KeroseneBrandTokens.warning;
  static Color get statusPendingSoft =>
      KeroseneBrandTokens.warning.withValues(alpha: 0.85);
  static Color get statusConfirming =>
      KeroseneBrandTokens.warning.withValues(alpha: 0.9);
  static Color get statusConfirmingSoft =>
      KeroseneBrandTokens.warning.withValues(alpha: 0.75);
  static Color get statusFailed => KeroseneBrandTokens.error;
  static Color get statusFailedSoft =>
      KeroseneBrandTokens.error.withValues(alpha: 0.85);
  static Color get statusCancelled =>
      KeroseneBrandTokens.error.withValues(alpha: 0.7);
  static const Color statusTrack = AppColors.activityStatusTrack;

  // ── Amounts: always black ────────────────────────────────────────────────
  static const Color amountCredit = inkPrimary;
  static const Color amountDebit = inkPrimary;
  static const Color amountNeutral = inkPrimary;

  // ── Light card surface paper ─────────────────────────────────────────────
  /// Neutral paper.
  static const Color surfaceInternal = ActivitySurfaceTokens.surfaceInternal;
  static const Color borderInternal = ActivitySurfaceTokens.borderInternal;

  /// On-chain — quiet warm paper.
  static const Color surfaceOnchain = ActivitySurfaceTokens.surfaceOnchain;
  static const Color borderOnchain = ActivitySurfaceTokens.borderOnchain;

  /// Lightning — quiet neutral paper.
  static const Color surfaceLightning = ActivitySurfaceTokens.surfaceLightning;
  static const Color borderLightning = ActivitySurfaceTokens.borderLightning;
  static const Color surfaceDivider = ActivitySurfaceTokens.surfaceDivider;

  /// Icon disc.
  static const Color iconWell = ActivitySurfaceTokens.iconWell;
  static const Color iconWellBorder = ActivitySurfaceTokens.iconWellBorder;

  // ── Resolvers ────────────────────────────────────────────────────────────

  static TransactionCardSurface surfaceFor(Transaction tx) {
    if (tx.isLightning) return TransactionCardSurface.lightning;
    if (tx.isInternal) return TransactionCardSurface.internal;
    return TransactionCardSurface.onchain;
  }

  static TransactionStatusTone toneFor(Transaction tx) {
    if (tx.isCancelled) return TransactionStatusTone.cancelled;
    if (tx.isUnconfirmedExpired || tx.status == TransactionStatus.failed) {
      return TransactionStatusTone.failed;
    }
    if (tx.status == TransactionStatus.confirmed || tx.isConfirmed) {
      return TransactionStatusTone.confirmed;
    }
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

  /// Adapts a compact Home row to the current Home surface contract.
  ///
  /// Full statement cards retain their paper treatment for scanability, but
  /// the Home feed must read as one OLED surface instead of a cream card
  /// inserted into the dark balance scene.
  TransactionCardColors forHomeSurface(HomeSurfaceTheme homeSurface) {
    return TransactionCardColors(
      background: homeSurface.card,
      border: homeSurface.surfaceBorder,
      title: homeSurface.textPrimary,
      subtitle: homeSurface.textSecondary,
      meta: homeSurface.textMuted,
      amount: homeSurface.textPrimary,
      divider: homeSurface.surfaceBorder,
      iconWell: homeSurface.surfaceDim,
      iconWellBorder: homeSurface.surfaceBorder,
      icon: homeSurface.textPrimary,
      statusStrong: statusStrong,
      statusSoft: statusSoft,
      statusTrack: homeSurface.textMuted,
      surface: surface,
      tone: tone,
    );
  }
}
