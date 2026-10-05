import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';
import 'package:kerosene/features/home/presentation/providers/incoming_transfer_theater.dart';
import 'package:kerosene/features/home/presentation/providers/theater_scheduler.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart'
    show HomeLedgerBalanceView, homeLedgerBalanceViewProvider;
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';

/// Injects education / receive copy into the **home theater** (Communication Stage).
///
/// Not modals — pieces appear as [HomeCommunicationStage] content via
/// [HomeSurfaceNotifier.presentLocalStage].
class HomeEducationHost extends ConsumerStatefulWidget {
  const HomeEducationHost({super.key});

  @override
  ConsumerState<HomeEducationHost> createState() => _HomeEducationHostState();
}

class _HomeEducationHostState extends ConsumerState<HomeEducationHost> {
  bool _totpCheckScheduled = false;
  String? _activeLocalId;

  /// First non-empty history snapshot only seeds seen IDs (no theater spam).
  bool _historySeeded = false;
  final Set<String> _seenCreditIds = <String>{};

  TheaterSchedulerState _schedulerSession = const TheaterSchedulerState();
  DateTime? _stageIdleSince;
  Timer? _educationTimer;
  Timer? _educationKickTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Seed before any listen delta so already-loaded history never floods theater.
      final existing = ref.read(transactionHistoryProvider).asData?.value;
      if (existing != null && existing.isNotEmpty) {
        _onHistorySnapshot(existing);
      }
      _tryPresentNext(force: true);
      _scheduleTotpCheck();
      _armEducationTimer();
    });
  }

  @override
  void dispose() {
    _educationTimer?.cancel();
    _educationKickTimer?.cancel();
    _educationTimer = null;
    _educationKickTimer = null;
    super.dispose();
  }

  void _armEducationTimer() {
    _educationTimer?.cancel();
    _educationKickTimer?.cancel();
    // Periodic tick: offer catalog tip when home is quiet.
    _educationTimer = Timer.periodic(KeroseneMotion.educationPoll, (_) {
      if (!mounted) return;
      _tryEnqueueEducation();
    });
    // First attempt after a short quiet period (after TOTP window).
    // Must be a cancelable [Timer] — bare Future.delayed survives dispose and
    // can touch defunct elements on hot restart.
    _educationKickTimer = Timer(KeroseneMotion.educationKick, () {
      if (!mounted) return;
      _tryEnqueueEducation();
    });
  }

  Set<String> _contextTags() {
    final tags = <String>{};
    final view = ref.read(homeLedgerBalanceViewProvider);
    switch (view) {
      case HomeLedgerBalanceView.platform:
        tags.add('platform');
      case HomeLedgerBalanceView.onChain:
        tags.add('onchain');
      case HomeLedgerBalanceView.cold:
        tags.addAll({'cold', 'onchain'});
      case HomeLedgerBalanceView.total:
        break;
    }
    final walletState = ref.read(walletProvider);
    if (walletState is WalletLoaded && walletState.wallets.isNotEmpty) {
      tags.add('hasWallet');
      final hasCold = walletState.wallets.any((w) => w.isColdWallet);
      if (hasCold) tags.add('cold');
    }
    return tags;
  }

  void _tryEnqueueEducation() {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) return;

    final surface = ref.read(homeSurfaceProvider);
    final stage = surface.stage;
    final busy =
        stage.isActive &&
        (stage.id.startsWith('local-incoming') ||
            stage.id.startsWith('local-totp') ||
            stage.priority >= 120);
    if (busy) {
      _stageIdleSince = null;
      return;
    }
    if (!stage.isActive) {
      _stageIdleSince ??= DateTime.now();
    } else {
      // Market BE stage counts as not-idle for education offer.
      _stageIdleSince = null;
      return;
    }

    final idleFor = _stageIdleSince == null
        ? null
        : DateTime.now().difference(_stageIdleSince!);

    final prefs = ref.read(sharedPreferencesProvider);
    final lang = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().split(RegExp(r'[_-]')).first;
    final piece = pickNextTheaterPiece(
      prefs: prefs,
      context: TheaterSchedulerContext(
        userId: auth.user.id,
        lang: lang,
        tags: _contextTags(),
        highPriorityBusy: busy,
        idleFor: idleFor,
      ),
      session: _schedulerSession,
    );
    if (piece == null) return;

    enqueueEducationTip(
      ref.read(homeEducationQueueProvider.notifier),
      piece: piece,
    );
    unawaited(
      markTheaterPieceShown(prefs: prefs, userId: auth.user.id, piece: piece),
    );
    _schedulerSession = _schedulerSession.copyWith(
      educationPresentedThisSession:
          _schedulerSession.educationPresentedThisSession + 1,
      lastEducationAt: DateTime.now(),
      lastFamily: piece.family,
    );
    debugPrint('[homeEducation] catalog tip queued id=${piece.id}');
    _tryPresentNext(force: true);
  }

  void _scheduleTotpCheck() {
    if (_totpCheckScheduled) return;
    _totpCheckScheduled = true;
    // Wait for auth + first surface load, then try a few times.
    Future<void>.delayed(KeroseneMotion.educationAuthWarmup, () {
      if (mounted) unawaited(_tryEnqueueTotp(attempt: 0));
    });
  }

  Future<void> _tryEnqueueTotp({required int attempt}) async {
    if (!mounted || attempt > 6) return;
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      Future<void>.delayed(KeroseneMotion.educationAuthRetry, () {
        if (mounted) unawaited(_tryEnqueueTotp(attempt: attempt + 1));
      });
      return;
    }

    try {
      final status = await ref.read(securityStatusProvider.future);
      if (!mounted) return;
      if (status.totpEnabled) {
        debugPrint('[homeEducation] TOTP already enabled — skip theater tip');
        return;
      }
      final prefs = ref.read(sharedPreferencesProvider);
      if (!shouldOfferTotpEducation(
        totpEnabled: false,
        userId: auth.user.id,
        prefs: prefs,
      )) {
        debugPrint('[homeEducation] TOTP tip on cooldown — skip');
        return;
      }
      enqueueTotpEducation(ref.read(homeEducationQueueProvider.notifier));
      debugPrint('[homeEducation] TOTP tip queued');
      // Inject immediately; do not wait for market stage to finish.
      _tryPresentNext(force: true);
    } catch (e, st) {
      debugPrint('[homeEducation] totp check failed (retry): $e\n$st');
      Future<void>.delayed(KeroseneMotion.educationAuthRetry, () {
        if (mounted) unawaited(_tryEnqueueTotp(attempt: attempt + 1));
      });
    }
  }

  void _tryPresentNext({bool force = false}) {
    if (!mounted) return;
    final queue = ref.read(homeEducationQueueProvider);
    if (queue.isEmpty) return;

    final surface = ref.read(homeSurfaceProvider);
    // Already showing this local piece — leave it alone.
    if (_activeLocalId != null &&
        surface.stage.id == _activeLocalId &&
        surface.stage.isActive) {
      return;
    }
    // Another local piece is live — wait unless force (receive/TOTP priority).
    if (!force &&
        surface.stage.isActive &&
        surface.stage.id.startsWith('local-') &&
        surface.stage.id != queue.first.id) {
      return;
    }

    final event = queue.first;
    final lang = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().split(RegExp(r'[_-]')).first;
    final stage = homeEducationToStage(event, lang: lang);

    if (!stage.isActive) {
      debugPrint('[homeEducation] built inactive stage id=${stage.id} — skip');
      ref.read(homeEducationQueueProvider.notifier).dequeue(event.id);
      return;
    }

    // Always inject: local theater education/receive must be visible.
    // Backend market can wait; receive and tips are user-facing priority.
    _activeLocalId = stage.id;
    ref.read(homeSurfaceProvider.notifier).presentLocalStage(stage);
    ref.read(homeEducationQueueProvider.notifier).dequeue(event.id);
    debugPrint(
      '[homeEducation] presented theater stage=${stage.id} '
      'kind=${stage.kind.name} force=$force',
    );

    // Dismiss cooldown only after we successfully showed TOTP tip.
    if (event.kind == HomeEducationKind.totpRecommend) {
      final auth = ref.read(authControllerProvider);
      if (auth is AuthAuthenticated) {
        unawaited(
          markTotpEducationDismissed(
            userId: auth.user.id,
            prefs: ref.read(sharedPreferencesProvider),
          ),
        );
      }
    }
  }

  void _onHistorySnapshot(List<Transaction> txs) {
    if (txs.isEmpty) return;

    if (!_historySeeded) {
      for (final tx in txs) {
        if (tx.isCredit) _seenCreditIds.add(tx.id);
      }
      _historySeeded = true;
      debugPrint(
        '[homeEducation] seeded ${_seenCreditIds.length} credit ids '
        '(no theater for historical receives)',
      );
      return;
    }

    // Only brand-new credits after the seed. Caps to avoid floods.
    var presented = 0;
    for (final tx in txs) {
      if (!tx.isCredit || tx.isCancelled) continue;
      if (_seenCreditIds.contains(tx.id)) continue;
      _seenCreditIds.add(tx.id);

      final payload = payloadFromTransaction(tx, read: ref.read);
      if (payload == null) continue;

      presentIncomingTheater(
        ref.read(homeEducationQueueProvider.notifier),
        ref.read(homeBalanceReceivePulseProvider.notifier),
        payload,
      );
      presented += 1;
      debugPrint(
        '[homeEducation] history receive → theater id=${payload.id} '
        'amount=${payload.amountLabel}',
      );
      if (presented >= 3) break;
    }

    // Bound memory for long sessions.
    if (_seenCreditIds.length > 400) {
      final keep = txs
          .where((t) => t.isCredit)
          .map((t) => t.id)
          .take(200)
          .toSet();
      _seenCreditIds
        ..clear()
        ..addAll(keep);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeEducationQueueProvider, (prev, next) {
      if (next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresentNext(force: true);
        });
      }
    });

    // Extrato path: when poll/WS refresh brings a new credit, show theater even
    // if /queue/notifications never delivered the financial notification.
    ref.listen<AsyncValue<List<Transaction>>>(transactionHistoryProvider, (
      prev,
      next,
    ) {
      final txs = next.asData?.value;
      if (txs == null) return;
      _onHistorySnapshot(txs);
    });

    ref.listen(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated && prev is! AuthAuthenticated) {
        _historySeeded = false;
        _seenCreditIds.clear();
        _totpCheckScheduled = false;
        _schedulerSession = const TheaterSchedulerState();
        _stageIdleSince = null;
        _scheduleTotpCheck();
        _armEducationTimer();
      }
    });

    ref.listen(homeSurfaceProvider.select((s) => s.stage.id), (prev, next) {
      // Local piece finished / replaced → free to show next.
      if (_activeLocalId != null && next != _activeLocalId) {
        if (prev == _activeLocalId) {
          _activeLocalId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tryPresentNext(force: true);
          });
        }
      }
      if (next.startsWith('local-')) {
        _activeLocalId = next;
      }
      // When theater goes idle and queue still has work, inject.
      if (next.isEmpty || next == 'idle') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresentNext(force: true);
        });
      }
    });

    // Stage inactive → free queue + track idle window for education scheduler.
    ref.listen(homeSurfaceProvider.select((s) => s.stage.isActive), (
      prev,
      next,
    ) {
      if (next == false) {
        _stageIdleSince ??= DateTime.now();
        if (prev == true) {
          _activeLocalId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tryPresentNext(force: true);
          });
        }
      } else {
        final id = ref.read(homeSurfaceProvider).stage.id;
        if (!id.startsWith('local-edu-')) {
          _stageIdleSince = null;
        }
      }
    });

    return const SizedBox.shrink();
  }
}
