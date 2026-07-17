import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kerosene/bootstrap/mobile_bootstrap.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/providers/tor_providers.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

import 'real_session.dart';

/// Boots the **real** mobile shell (same [MyApp] / routes / theme / fonts as
/// production) with a live session and PIN gate unlocked for automation.
class VisualAppHarness {
  VisualAppHarness._(this.container, this.session);

  final ProviderContainer container;
  final RealSession session;

  /// Tor + session + PIN unlock + [initializeApp], ready to [pump].
  static Future<VisualAppHarness> start({
    bool createEphemeralIfNoEnv = true,
  }) async {
    // PIN pad must never block screenshots.
    AppEntryPinSession.markUnlocked();

    final apiBase = await bootstrapTorRelay();
    final session = await obtainVisualSession(apiBase);
    await persistSession(session);

    final prefs = await SharedPreferences.getInstance();
    // Hint: do not force PIN setup during the visual run.
    // Session scope resolves after auth; process unlock flag is enough.

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    // Point the live app at the same Tor relay used for signup/login.
    container.read(torApiUrlProvider.notifier).updateUrl(session.apiBaseUrl);

    await initializeApp(container);

    // Ensure unlock sticks if any early auth tick cleared it.
    AppEntryPinSession.markUnlocked();
    try {
      container.read(appEntryPinUnlockedProvider.notifier).unlock();
    } catch (e) {
      debugPrint('[visual-e2e] pin unlock notifier: $e');
    }

    return VisualAppHarness._(container, session);
  }

  /// Pumps the real [MyApp] under a capture [RepaintBoundary].
  Future<void> pump(WidgetTester tester) async {
    AppEntryPinSession.markUnlocked();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('visual_e2e_capture_root'),
          child: MyApp(),
        ),
      ),
    );
    // Brand splash is 3s; give the shell room to leave K logo.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    AppEntryPinSession.markUnlocked();
    try {
      container.read(appEntryPinUnlockedProvider.notifier).unlock();
    } catch (_) {}
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Navigate with the real navigator (same routes as production).
  Future<void> goNamed(WidgetTester tester, String routeName) async {
    final nav = SnackbarHelper.navigatorKey.currentState;
    if (nav == null) {
      throw StateError('Navigator not ready for route $routeName');
    }
    nav.pushNamed(routeName);
    await tester.pump(const Duration(milliseconds: 400));
    // Deferred libraries + data fetch.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  void dispose() {
    container.dispose();
  }
}

/// Heuristic: home (or authenticated shell) is past splash/welcome/PIN.
bool looksLikeAuthenticatedShell() {
  final iniciar = find.textContaining('INICIANDO');
  if (iniciar.evaluate().isNotEmpty) return false;

  final homeHints = [
    find.textContaining('SALDO'),
    find.textContaining('Saldo'),
    find.textContaining('BTC'),
    find.textContaining('Receber'),
    find.textContaining('Enviar'),
    find.textContaining('Atividades'),
    find.textContaining('Bom dia'),
    find.textContaining('Boa tarde'),
    find.textContaining('Boa noite'),
    find.textContaining('Onboarding'),
    find.textContaining('Primeiros passos'),
    find.textContaining('Ajuste sua conta'),
    find.textContaining('Ajustes'),
  ];

  if (homeHints.any((f) => f.evaluate().isNotEmpty)) {
    return true;
  }

  // Still on welcome / login → not authenticated shell.
  final unauth = [
    find.textContaining('Criar conta'),
    find.textContaining('Já tenho conta'),
    find.textContaining('Perdi acesso'),
  ];
  if (unauth.any((f) => f.evaluate().isNotEmpty)) {
    return false;
  }

  // PIN-only pad without home chrome.
  final pinOnly = find.textContaining('PIN');
  if (pinOnly.evaluate().isNotEmpty) {
    return false;
  }

  return false;
}
