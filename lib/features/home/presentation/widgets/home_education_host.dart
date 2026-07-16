import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/home_surface_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryPresentNext(force: true);
      _scheduleTotpCheck();
    });
  }

  void _scheduleTotpCheck() {
    if (_totpCheckScheduled) return;
    _totpCheckScheduled = true;
    // Wait for auth + first surface load, then try a few times.
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) unawaited(_tryEnqueueTotp(attempt: 0));
    });
  }

  Future<void> _tryEnqueueTotp({required int attempt}) async {
    if (!mounted || attempt > 6) return;
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      Future<void>.delayed(const Duration(seconds: 2), () {
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
      Future<void>.delayed(const Duration(seconds: 2), () {
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
    final lang = Localizations.localeOf(context).languageCode;
    final stage = homeEducationToStage(event, lang: lang);

    if (!stage.isActive) {
      debugPrint(
        '[homeEducation] built inactive stage id=${stage.id} — skip',
      );
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

  @override
  Widget build(BuildContext context) {
    ref.listen(homeEducationQueueProvider, (prev, next) {
      if (next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresentNext(force: true);
        });
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

    // Also re-try when stage becomes inactive (kind idle).
    ref.listen(homeSurfaceProvider.select((s) => s.stage.isActive), (
      prev,
      next,
    ) {
      if (prev == true && next == false) {
        _activeLocalId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryPresentNext(force: true);
        });
      }
    });

    ref.listen(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated && prev is! AuthAuthenticated) {
        _totpCheckScheduled = false;
        _scheduleTotpCheck();
      }
    });

    return const SizedBox.shrink();
  }
}
