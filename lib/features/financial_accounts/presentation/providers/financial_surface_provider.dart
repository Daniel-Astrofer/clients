import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ref-count of screens that need live balance / statement polling
/// (home, extrato, wallets, send/receive). Zero ⇒ periodic poll is idle.
class FinancialSurfaceGateNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void acquire() {
    state = state + 1;
  }

  void release() {
    if (state <= 0) {
      state = 0;
      return;
    }
    state = state - 1;
  }
}

final financialSurfaceGateProvider =
    NotifierProvider<FinancialSurfaceGateNotifier, int>(
  FinancialSurfaceGateNotifier.new,
);

/// True while at least one financial surface is mounted.
final financialSurfaceActiveProvider = Provider<bool>((ref) {
  return ref.watch(financialSurfaceGateProvider) > 0;
});

/// App foreground (resumed/inactive). False when paused/hidden/detached.
class AppForegroundNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  // ignore: use_setters_to_change_properties
  void setForeground(bool value) {
    if (state == value) return;
    state = value;
  }
}

final appForegroundProvider =
    NotifierProvider<AppForegroundNotifier, bool>(AppForegroundNotifier.new);

/// Combined gate for the realtime poll loop.
final financialPollAllowedProvider = Provider<bool>((ref) {
  final surface = ref.watch(financialSurfaceActiveProvider);
  final foreground = ref.watch(appForegroundProvider);
  return surface && foreground;
});

/// Register [ref] for the lifetime of a [ConsumerState] financial screen.
mixin FinancialSurfaceMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _financialSurfaceHeld = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _financialSurfaceHeld) return;
      ref.read(financialSurfaceGateProvider.notifier).acquire();
      _financialSurfaceHeld = true;
    });
  }

  @override
  void dispose() {
    if (_financialSurfaceHeld) {
      // ref is still valid in dispose for ConsumerState.
      ref.read(financialSurfaceGateProvider.notifier).release();
      _financialSurfaceHeld = false;
    }
    super.dispose();
  }
}
