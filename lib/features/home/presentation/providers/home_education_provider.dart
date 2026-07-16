import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';

/// Events that become **theater stages** (communication stage), not modals.
enum HomeEducationKind {
  totpRecommend,
  incomingTransfer,
}

@immutable
class HomeEducationEvent {
  final HomeEducationKind kind;
  final String id;
  final String? amountLabel;
  final String? walletName;
  final String? networkLabel;
  final String? subtitle;

  const HomeEducationEvent({
    required this.kind,
    required this.id,
    this.amountLabel,
    this.walletName,
    this.networkLabel,
    this.subtitle,
  });
}

/// Pulse the balance hero (green flash) when funds arrive.
final homeBalanceReceivePulseProvider =
    NotifierProvider<HomeBalanceReceivePulse, int>(
  HomeBalanceReceivePulse.new,
);

class HomeBalanceReceivePulse extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state = state + 1;
}

/// Queue of theater pieces (FIFO). Host injects into [homeSurfaceProvider].
final homeEducationQueueProvider =
    NotifierProvider<HomeEducationQueue, List<HomeEducationEvent>>(
  HomeEducationQueue.new,
);

class HomeEducationQueue extends Notifier<List<HomeEducationEvent>> {
  @override
  List<HomeEducationEvent> build() => const [];

  void enqueue(HomeEducationEvent event) {
    if (state.any((e) => e.id == event.id)) return;
    state = [...state, event];
  }

  void dequeue(String id) {
    state = [
      for (final e in state)
        if (e.id != id) e,
    ];
  }

  void clear() => state = const [];
}

String totpEducationDismissKey(String userId) =>
    'education.totp.dismissed_at.$userId';

const totpEducationCooldown = Duration(days: 7);

bool shouldOfferTotpEducation({
  required bool totpEnabled,
  required String? userId,
  required SharedPreferences prefs,
}) {
  if (totpEnabled) return false;
  if (userId == null || userId.isEmpty) return false;
  final raw = prefs.getInt(totpEducationDismissKey(userId));
  if (raw == null) return true;
  final dismissed = DateTime.fromMillisecondsSinceEpoch(raw);
  return DateTime.now().difference(dismissed) >= totpEducationCooldown;
}

Future<void> markTotpEducationDismissed({
  required String userId,
  required SharedPreferences prefs,
}) async {
  await prefs.setInt(
    totpEducationDismissKey(userId),
    DateTime.now().millisecondsSinceEpoch,
  );
}

void enqueueTotpEducation(HomeEducationQueue queue) {
  queue.enqueue(
    const HomeEducationEvent(
      kind: HomeEducationKind.totpRecommend,
      id: 'local-totp-recommend',
    ),
  );
}

void enqueueIncomingTransfer(
  HomeEducationQueue queue,
  HomeBalanceReceivePulse pulse, {
  required String id,
  required String amountLabel,
  required String walletName,
  required String networkLabel,
  String? subtitle,
}) {
  queue.enqueue(
    HomeEducationEvent(
      kind: HomeEducationKind.incomingTransfer,
      id: 'local-incoming-$id',
      amountLabel: amountLabel,
      walletName: walletName,
      networkLabel: networkLabel,
      subtitle: subtitle,
    ),
  );
  pulse.trigger();
}

/// Builds a Communication Stage piece for the home theater.
HomeStage homeEducationToStage(HomeEducationEvent event, {String lang = 'pt'}) {
  return switch (event.kind) {
    HomeEducationKind.totpRecommend => _totpStage(lang),
    HomeEducationKind.incomingTransfer => _incomingStage(event, lang),
  };
}

HomeStage _totpStage(String lang) {
  final title = switch (lang) {
    'en' => 'Protect your account with TOTP',
    'es' => 'Protege tu cuenta con TOTP',
    _ => 'Proteja sua conta com TOTP',
  };
  final body = switch (lang) {
    'en' =>
      'TOTP is a code that changes every few seconds in an authenticator app. '
          'Even if someone steals your password, they still need your phone. '
          'Enable it in Settings → Security — it takes about a minute.',
    'es' =>
      'TOTP es un código que cambia cada pocos segundos en una app autenticadora. '
          'Aunque roben tu contraseña, aún necesitan tu teléfono. '
          'Actívalo en Ajustes → Seguridad — tarda cerca de un minuto.',
    _ =>
      'TOTP é um código que muda a cada poucos segundos no app autenticador. '
          'Mesmo que alguém descubra sua senha, ainda precisa do celular. '
          'Ative em Configurações → Segurança — leva cerca de um minuto.',
  };

  return HomeStage(
    id: 'local-totp-recommend',
    kind: HomeStageKind.feature,
    playPolicy: HomeStagePlayPolicy.once,
    priority: 120,
    content: HomeStageContent(
      title: title,
      body: body,
      textMode: HomeStageTextMode.typewriter,
      cta: const HomeStageCta(
        label: 'Ativar TOTP',
        action: 'NAVIGATE',
        target: '/settings/security',
      ),
    ),
    layout: const HomeStageLayout(
      maxHeight: 220,
      gap: 10,
      paddingTop: 4,
      paddingBottom: 10,
    ),
    motion: const HomeStageMotion(
      content: HomeStageMotionStep(
        type: HomeStageMotionType.none,
        durationMs: 16000,
      ),
      bodyShift: HomeStageBodyShift(enabled: true, offsetPx: 28),
    ),
    lifecycle: const HomeStageLifecycle(
      showDurationMs: 16000,
      restoreOnComplete: true,
    ),
    atmosphere: const HomeStageAtmosphere(
      glows: [
        HomeStageGlow(
          id: 'totp-main',
          colorToken: 'cold',
          x: 0.5,
          y: 0.0,
          width: 1.6,
          height: 0.55,
          intensity: 0.42,
          radius: 0.72,
        ),
      ],
      animated: true,
      transitionMs: 480,
    ),
  );
}

HomeStage _incomingStage(HomeEducationEvent event, String lang) {
  final amount = event.amountLabel ?? 'fundos';
  final wallet = event.walletName ?? 'Principal';
  final network = event.networkLabel ?? 'Interna';

  final title = switch (lang) {
    'en' => 'You received $amount',
    'es' => 'Recibiste $amount',
    _ => 'Você recebeu $amount',
  };
  final body = switch (lang) {
    'en' => 'Wallet “$wallet” · $network'
        '${event.subtitle != null && event.subtitle!.isNotEmpty ? '\n${event.subtitle}' : ''}',
    'es' => 'Cartera “$wallet” · $network'
        '${event.subtitle != null && event.subtitle!.isNotEmpty ? '\n${event.subtitle}' : ''}',
    _ => 'Carteira “$wallet” · $network'
        '${event.subtitle != null && event.subtitle!.isNotEmpty ? '\n${event.subtitle}' : ''}',
  };

  final accent = switch (network.toLowerCase()) {
    final n when n.contains('light') => 'amber',
    final n when n.contains('onchain') || n.contains('on-chain') => 'positive',
    _ => 'positive',
  };

  return HomeStage(
    id: event.id,
    kind: HomeStageKind.announcement,
    playPolicy: HomeStagePlayPolicy.once,
    priority: 130, // higher than market so receive is visible
    content: HomeStageContent(
      title: title,
      body: body,
      textMode: HomeStageTextMode.typewriter,
    ),
    layout: const HomeStageLayout(
      maxHeight: 180,
      gap: 8,
      paddingTop: 4,
      paddingBottom: 8,
    ),
    motion: const HomeStageMotion(
      content: HomeStageMotionStep(
        type: HomeStageMotionType.none,
        durationMs: 10000,
      ),
      bodyShift: HomeStageBodyShift(enabled: true, offsetPx: 32),
    ),
    lifecycle: const HomeStageLifecycle(
      showDurationMs: 10000,
      restoreOnComplete: true,
    ),
    atmosphere: HomeStageAtmosphere(
      glows: [
        HomeStageGlow(
          id: 'recv-main',
          colorToken: accent,
          x: 0.5,
          y: 0.0,
          width: 1.7,
          height: 0.55,
          intensity: 0.48,
          radius: 0.72,
        ),
      ],
      animated: true,
      transitionMs: 420,
    ),
  );
}
