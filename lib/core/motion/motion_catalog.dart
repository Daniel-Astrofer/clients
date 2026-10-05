// architecture-allow-large-file: Motion registry mapping all KeroseneMotion tokens
// to semantic categories. This file is a reference catalog, not executable logic.
// Each enum value + extension method is one line of data; splitting across files
// would scatter related motion decisions. Keep together for auditability.

import 'package:flutter/animation.dart';
import 'package:kerosene/core/motion/app_motion.dart';

/// Semantic category for every motion token in the Kerosene system.
///
/// Maps to [docs/product/design/motion-system.md] categories.
enum KeroseneMotionCategory {
  /// State changes in widgets: button press, toggle, value update, error appear.
  /// Tokens: fast, short, medium, long, standard, emphasized, entrance, exit.
  functional,

  /// Screen-to-screen relationships: push, pop, hero, wallet expand.
  /// Tokens: pageIn, pageOut, route.
  continuity,

  /// Rare, high-impact moments: confirmation, authorization, sync, onboarding.
  /// Tokens: ceremonial, secureLoop, odometerCeremony, odometerUpdate,
  ///         passkeyScene, passkeyPulse, totpTransition, status.
  brand,

  /// Background atmosphere: glow, slow displacement, scroll reaction.
  /// Tokens: ambient, calm, slow, heroLoop, walletLoop.
  ambient,

  /// Loading, retry, timeout, and connection progress.
  /// Tokens: loadingMinimum, loadingRetryMedium, loadingRetryLong, loadingTimeout,
  ///         startupConnectionProgressTick, startupConnectionTimeout,
  ///         offlineRetryPulse, offlineRetryInterval.
  loading,

  /// Small delays between items entering: list, auth form, surface elements.
  /// Tokens: microStagger, authStagger, listStagger, compactStagger, surfaceStagger.
  micro,

  /// Security rituals: passkey, TOTP, PIN transitions.
  /// Tokens: passkeyScene, passkeySceneCompact, passkeyPulse, totpTransition,
  ///         secureLoop.
  security,

  /// NFC interaction timing.
  /// Tokens: nfcSceneIntro, nfcSceneReady.
  nfc,

  /// Feedback notices and notifications.
  /// Tokens: noticeHold, noticeExtendedHold, notificationHold, notificationLongHold.
  feedback,

  /// Special: balance display ceremonies.
  /// Tokens: odometerCeremony, odometerUpdate, odometerInitial.
  balance,
}

/// Describes which motion tokens to use for a specific interaction.
///
/// Every animation in feature code should reference a [MotionContract]
/// rather than picking raw durations.
class MotionContract {
  final Duration enter;
  final Duration exit;
  final Curve curve;
  final KeroseneMotionCategory category;
  final String description;

  const MotionContract({
    required this.enter,
    this.exit = Duration.zero,
    this.curve = Curves.easeOutCubic,
    required this.category,
    this.description = '',
  });

  /// Every visual contract resolves immediately with reduced motion.
  Duration resolvedEnter(bool reduceMotion) =>
      reduceMotion ? Duration.zero : enter;
  Duration resolvedExit(bool reduceMotion) =>
      reduceMotion ? Duration.zero : exit;
}

/// Registry of all KeroseneMotion tokens mapped to their semantic categories.
///
/// Usage:
/// ```dart
/// final contract = KeroseneMotionRegistry.contractFor('pageIn');
/// final duration = contract.resolvedEnter(reduceMotion);
/// ```
class KeroseneMotionRegistry {
  const KeroseneMotionRegistry._();

  /// Lookup a [MotionContract] by token name.
  ///
  /// Returns null if the token name is not in the registry (should not happen
  /// if using [KeroseneMotion] constants).
  static MotionContract? contractFor(String tokenName) {
    return _registry[tokenName];
  }

  /// All registered contracts, keyed by their KeroseneMotion constant name.
  static const Map<String, MotionContract> _registry = {
    'pageTransition': MotionContract(
        enter: KeroseneMotion.pageTransition,
        category: KeroseneMotionCategory.continuity),
    'statusChange': MotionContract(
        enter: KeroseneMotion.statusChange,
        category: KeroseneMotionCategory.functional),
    'sheet': MotionContract(
        enter: KeroseneMotion.sheet,
        category: KeroseneMotionCategory.continuity),
    'success': MotionContract(
        enter: KeroseneMotion.success,
        category: KeroseneMotionCategory.feedback),
    // ── Functional ───────────────────────────────────────────────────────
    'fast': MotionContract(
      enter: KeroseneMotion.fast,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.functional,
      description: 'Button press feedback, toggle, switch',
    ),
    'short': MotionContract(
      enter: KeroseneMotion.short,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.functional,
      description: 'Item removal, toggle state change',
    ),
    'medium': MotionContract(
      enter: KeroseneMotion.medium,
      curve: Curves.easeOutExpo,
      category: KeroseneMotionCategory.functional,
      description: 'Value update, error appearing, modal present',
    ),
    'long': MotionContract(
      enter: KeroseneMotion.long,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.functional,
      description: 'Complex state transition, multi-element animation',
    ),
    'standard_curve': MotionContract(
      enter: KeroseneMotion.short,
      curve: KeroseneMotion.standard,
      category: KeroseneMotionCategory.functional,
      description: 'Default functional curve (easeOutCubic)',
    ),
    'emphasized_curve': MotionContract(
      enter: KeroseneMotion.medium,
      curve: KeroseneMotion.emphasized,
      category: KeroseneMotionCategory.functional,
      description: 'Emphasized functional curve (easeOutExpo)',
    ),
    'entrance_curve': MotionContract(
      enter: KeroseneMotion.short,
      curve: KeroseneMotion.entrance,
      category: KeroseneMotionCategory.functional,
      description: 'Element entrance (easeOutQuart)',
    ),
    'exit_curve': MotionContract(
      enter: KeroseneMotion.short,
      exit: KeroseneMotion.short,
      curve: KeroseneMotion.exit,
      category: KeroseneMotionCategory.functional,
      description: 'Element exit (easeInCubic)',
    ),

    // ── Continuity ────────────────────────────────────────────────────────
    'pageIn': MotionContract(
      enter: KeroseneMotion.pageIn,
      curve: Curves.easeOutQuart,
      category: KeroseneMotionCategory.continuity,
      description: 'Push to new screen',
    ),
    'pageOut': MotionContract(
      enter: KeroseneMotion.pageOut,
      curve: Curves.easeInCubic,
      category: KeroseneMotionCategory.continuity,
      description: 'Pop back to previous screen',
    ),
    'route': MotionContract(
      enter: KeroseneMotion.route,
      curve: Curves.easeOutQuart,
      category: KeroseneMotionCategory.continuity,
      description: 'Route transition (alias for pageIn)',
    ),

    // ── Brand ────────────────────────────────────────────────────────────
    'ceremonial': MotionContract(
      enter: KeroseneMotion.ceremonial,
      curve: Curves.easeOutExpo,
      category: KeroseneMotionCategory.brand,
      description: 'Payment confirmed, ceremonial celebration',
    ),
    'secureLoop': MotionContract(
      enter: KeroseneMotion.secureLoop,
      curve: Curves.linear,
      category: KeroseneMotionCategory.brand,
      description: 'Secure operation authorized (Rive loop)',
    ),
    'status': MotionContract(
      enter: KeroseneMotion.status,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.brand,
      description: 'Status transition: pending → confirmed',
    ),
    'odometerCeremony': MotionContract(
      enter: KeroseneMotion.odometerCeremony,
      curve: Curves.easeOutExpo,
      category: KeroseneMotionCategory.balance,
      description: 'Balance first appearance ceremony',
    ),
    'odometerUpdate': MotionContract(
      enter: KeroseneMotion.odometerUpdate,
      curve: Curves.easeOutExpo,
      category: KeroseneMotionCategory.balance,
      description: 'Balance update on real delta',
    ),
    'passkeyScene': MotionContract(
      enter: KeroseneMotion.passkeyScene,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.security,
      description: 'Passkey verification scene',
    ),
    'passkeyPulse': MotionContract(
      enter: KeroseneMotion.passkeyPulse,
      curve: Curves.linear,
      category: KeroseneMotionCategory.security,
      description: 'Passkey waiting pulse loop',
    ),
    'totpTransition': MotionContract(
      enter: KeroseneMotion.totpTransition,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.security,
      description: 'TOTP code transition',
    ),

    // ── Ambient ──────────────────────────────────────────────────────────
    'ambient': MotionContract(
      enter: KeroseneMotion.ambient,
      curve: Curves.linear,
      category: KeroseneMotionCategory.ambient,
      description: 'Aurora glow slow displacement (20s)',
    ),
    'calm': MotionContract(
      enter: KeroseneMotion.calm,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.ambient,
      description: 'Slow surface transition',
    ),
    'slow': MotionContract(
      enter: KeroseneMotion.slow,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.ambient,
      description: 'Slow ambient shift',
    ),
    'heroLoop': MotionContract(
      enter: KeroseneMotion.heroLoop,
      curve: Curves.linear,
      category: KeroseneMotionCategory.ambient,
      description: 'Hero background loop',
    ),
    'walletLoop': MotionContract(
      enter: KeroseneMotion.walletLoop,
      curve: Curves.linear,
      category: KeroseneMotionCategory.ambient,
      description: 'Wallet background loop',
    ),

    // ── Loading ──────────────────────────────────────────────────────────
    'loadingMinimum': MotionContract(
      enter: KeroseneMotion.loadingMinimum,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Minimum loading display (avoid flash)',
    ),
    'loadingRetryMedium': MotionContract(
      enter: KeroseneMotion.loadingRetryMedium,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Loading with retry (medium wait)',
    ),
    'loadingRetryLong': MotionContract(
      enter: KeroseneMotion.loadingRetryLong,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Loading with retry (long wait)',
    ),
    'loadingTimeout': MotionContract(
      enter: KeroseneMotion.loadingTimeout,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Loading timeout threshold',
    ),
    'offlineRetryPulse': MotionContract(
      enter: KeroseneMotion.offlineRetryPulse,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.loading,
      description: 'Offline retry pulse animation',
    ),
    'offlineRetryInterval': MotionContract(
      enter: KeroseneMotion.offlineRetryInterval,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Offline retry interval (4s)',
    ),
    'startupConnectionProgressTick': MotionContract(
      enter: KeroseneMotion.startupConnectionProgressTick,
      curve: Curves.linear,
      category: KeroseneMotionCategory.loading,
      description: 'Startup connection progress tick',
    ),

    // ── Micro ────────────────────────────────────────────────────────────
    'microStagger': MotionContract(
      enter: KeroseneMotion.microStagger,
      curve: Curves.linear,
      category: KeroseneMotionCategory.micro,
      description: 'Generic stagger step (50ms)',
    ),
    'authStagger': MotionContract(
      enter: KeroseneMotion.authStagger,
      curve: Curves.linear,
      category: KeroseneMotionCategory.micro,
      description: 'Auth form field stagger (34ms)',
    ),
    'listStagger': MotionContract(
      enter: KeroseneMotion.listStagger,
      curve: Curves.linear,
      category: KeroseneMotionCategory.micro,
      description: 'List item stagger (60ms)',
    ),
    'compactStagger': MotionContract(
      enter: KeroseneMotion.compactStagger,
      curve: Curves.linear,
      category: KeroseneMotionCategory.micro,
      description: 'Compact element stagger (45ms)',
    ),
    'surfaceStagger': MotionContract(
      enter: KeroseneMotion.surfaceStagger,
      curve: Curves.linear,
      category: KeroseneMotionCategory.micro,
      description: 'Surface element stagger (28ms)',
    ),

    // ── NFC ──────────────────────────────────────────────────────────────
    'nfcSceneIntro': MotionContract(
      enter: KeroseneMotion.nfcSceneIntro,
      curve: Curves.easeOutCubic,
      category: KeroseneMotionCategory.nfc,
      description: 'NFC scene intro animation',
    ),
    'nfcSceneReady': MotionContract(
      enter: KeroseneMotion.nfcSceneReady,
      curve: Curves.linear,
      category: KeroseneMotionCategory.nfc,
      description: 'NFC ready + listening loop',
    ),

    // ── Feedback ─────────────────────────────────────────────────────────
    'noticeHold': MotionContract(
      enter: KeroseneMotion.noticeHold,
      curve: Curves.linear,
      category: KeroseneMotionCategory.feedback,
      description: 'Info notice display hold (3s)',
    ),
    'noticeExtendedHold': MotionContract(
      enter: KeroseneMotion.noticeExtendedHold,
      curve: Curves.linear,
      category: KeroseneMotionCategory.feedback,
      description: 'Extended/error notice hold (4s)',
    ),
    'notificationHold': MotionContract(
      enter: KeroseneMotion.notificationHold,
      curve: Curves.linear,
      category: KeroseneMotionCategory.feedback,
      description: 'Push notification hold (5s)',
    ),
    'notificationLongHold': MotionContract(
      enter: KeroseneMotion.notificationLongHold,
      curve: Curves.linear,
      category: KeroseneMotionCategory.feedback,
      description: 'Long notification hold (6s)',
    ),
  };

  /// Returns all tokens in a given category.
  static List<MapEntry<String, MotionContract>> byCategory(
    KeroseneMotionCategory category,
  ) {
    return _registry.entries
        .where((e) => e.value.category == category)
        .toList();
  }

  /// Returns the curve for a given semantic role.
  /// Use this when you know WHAT you want (e.g., "page transition")
  /// but not which specific curve token to use.
  static Curve curveFor(String role) {
    return switch (role) {
      'pageEnter' || 'push' => Curves.easeOutQuart,
      'pageExit' || 'pop' => Curves.easeInCubic,
      'default' || 'standard' => Curves.easeOutCubic,
      'emphasized' || 'ceremonial' => Curves.easeOutExpo,
      'entrance' => Curves.easeOutQuart,
      'exit' => Curves.easeInCubic,
      _ => Curves.easeOutCubic,
    };
  }
}

/// Extension for [KeroseneMotionCategory] to provide human-readable labels.
extension KeroseneMotionCategoryLabel on KeroseneMotionCategory {
  String get label => switch (this) {
        KeroseneMotionCategory.functional => 'Functional',
        KeroseneMotionCategory.continuity => 'Continuity',
        KeroseneMotionCategory.brand => 'Brand',
        KeroseneMotionCategory.ambient => 'Ambient',
        KeroseneMotionCategory.loading => 'Loading',
        KeroseneMotionCategory.micro => 'Micro',
        KeroseneMotionCategory.security => 'Security',
        KeroseneMotionCategory.nfc => 'NFC',
        KeroseneMotionCategory.feedback => 'Feedback',
        KeroseneMotionCategory.balance => 'Balance',
      };

  /// Whether this category should be removed entirely under reduceMotion.
  bool get removeOnReduceMotion => switch (this) {
        KeroseneMotionCategory.ambient => true,
        KeroseneMotionCategory.micro => true,
        _ => false,
      };

  /// Whether this category should collapse to instant under reduceMotion.
  bool get collapseOnReduceMotion => this != KeroseneMotionCategory.ambient;
}
