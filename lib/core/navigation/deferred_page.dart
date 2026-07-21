import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

typedef DeferredWidgetBuilder = Widget Function(BuildContext context);

/// Stable keys for deferred units — [Function] tear-offs from different
/// import prefixes are not identical, so prefetch + route must share a key.
abstract final class DeferredLibraryKeys {
  static const home = 'home';
  static const settings = 'settings';
  static const deposits = 'deposits';
  static const bitcoinAccounts = 'bitcoin_accounts';
  static const sendMoney = 'send_money';
  static const sendMoneyReview = 'send_money_review';
  static const receive = 'receive';
}

/// Dedupes [loadLibrary] so prefetch + first navigation share one Future
/// **per deferred import prefix**.
///
/// Important: Dart loads deferred libraries **per import prefix**. Prefetching
/// `home` from bootstrap does **not** load `home` from the router — caching only
/// by a shared string key caused "deferred library home was not loaded".
final Map<Object, Future<void>> _deferredLibraryCache = {};

/// Prefix tear-offs (and optional shared keys) that finished loading.
final Set<Object> _deferredLibraryReady = {};

/// Whether the deferred unit identified by [key] has finished loading.
///
/// Prefer passing the same [loadLibrary] tear-off used to load; shared
/// [DeferredLibraryKeys] only mean "at least one prefix of this unit loaded".
bool isDeferredLibraryReady(Object key) {
  return _deferredLibraryReady.contains(key);
}

/// Load (or reuse) a deferred library. Safe to call from idle prefetch.
///
/// Always caches by the [loadLibrary] tear-off so each import prefix actually
/// loads. Optional [key] is recorded when done (for coarse readiness probes).
Future<void> loadDeferredLibrary(
  Future<void> Function() loadLibrary, {
  Object? key,
}) {
  // Key by the tear-off — one entry per deferred import prefix.
  return _deferredLibraryCache.putIfAbsent(loadLibrary, () async {
    await loadLibrary();
    _deferredLibraryReady.add(loadLibrary);
    if (key != null) {
      _deferredLibraryReady.add(key);
    }
  });
}

/// Prefetch several deferred libs without blocking the UI isolate critically.
void prefetchDeferredLibraries(
  Iterable<({Future<void> Function() load, Object key})> loaders,
) {
  for (final entry in loaders) {
    // Fire-and-forget; errors are ignored until real navigation surfaces them.
    loadDeferredLibrary(entry.load, key: entry.key).ignore();
  }
}

class DeferredPage extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final DeferredWidgetBuilder builder;
  final Widget? loading;

  /// Optional shared label (see [DeferredLibraryKeys]). Does **not** replace
  /// loading this widget's [loadLibrary] prefix.
  final Object? libraryKey;

  /// When false, skip the library-ready fade/micro-slide (useful when the
  /// route already has a full-bleed page transition).
  final bool animateReveal;

  const DeferredPage({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loading,
    this.libraryKey,
    this.animateReveal = true,
  });

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _libraryFuture;
  Object? _error;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Always load THIS import prefix — never skip because another file's
    // prefix already finished under the same DeferredLibraryKeys label.
    _libraryFuture = loadDeferredLibrary(
      widget.loadLibrary,
      key: widget.libraryKey,
    );
    if (isDeferredLibraryReady(widget.loadLibrary)) {
      _ready = true;
      return;
    }
    _libraryFuture.then(
      (_) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _failed = false;
          _error = null;
        });
      },
      onError: (Object error, StackTrace _) {
        if (!mounted) return;
        // Allow a later retry to call loadLibrary again.
        _deferredLibraryCache.remove(widget.loadLibrary);
        _deferredLibraryReady.remove(widget.loadLibrary);
        setState(() {
          _ready = false;
          _failed = true;
          _error = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_failed) {
      child = _DeferredPageErrorView(
        error: _error,
        onRetry: () {
          _deferredLibraryCache.remove(widget.loadLibrary);
          _deferredLibraryReady.remove(widget.loadLibrary);
          setState(() {
            _failed = false;
            _error = null;
            _ready = false;
          });
          // Re-enter load path.
          final future = loadDeferredLibrary(
            widget.loadLibrary,
            key: widget.libraryKey,
          );
          future.then(
            (_) {
              if (!mounted) return;
              setState(() {
                _ready = true;
                _failed = false;
                _error = null;
              });
            },
            onError: (Object error, StackTrace _) {
              if (!mounted) return;
              _deferredLibraryCache.remove(widget.loadLibrary);
              setState(() {
                _ready = false;
                _failed = true;
                _error = error;
              });
            },
          );
        },
      );
    } else if (_ready) {
      child = widget.builder(context);
    } else {
      child = widget.loading ??
          _DeferredPageLoadingView(matchRouteChrome: !widget.animateReveal);
    }

    if (!widget.animateReveal || KeroseneMotion.reduceMotion(context)) {
      return child;
    }

    return AnimatedSwitcher(
      duration: KeroseneMotion.short,
      reverseDuration: KeroseneMotion.fast,
      switchInCurve: KeroseneMotion.entrance,
      switchOutCurve: KeroseneMotion.exit,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: KeroseneMotion.entrance,
          reverseCurve: KeroseneMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(curved),
            transformHitTests: false,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<Object?>(
          _failed
              ? _error ?? 'deferred-error'
              : _ready
                  ? 'deferred-ready'
                  : 'deferred-loading',
        ),
        child: child,
      ),
    );
  }
}

class _DeferredPageLoadingView extends StatelessWidget {
  /// When true (route already animates), use solid brand bg with no spinner so
  /// a mid-transition swap does not flash a soft grey + indicator.
  final bool matchRouteChrome;

  const _DeferredPageLoadingView({this.matchRouteChrome = false});

  @override
  Widget build(BuildContext context) {
    if (matchRouteChrome) {
      return const ColoredBox(
        color: KeroseneBrandTokens.background,
        child: SizedBox.expand(),
      );
    }

    return const Scaffold(
      backgroundColor: KeroseneBrandTokens.backgroundSoft,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _DeferredPageErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const _DeferredPageErrorView({this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeroseneBrandTokens.backgroundSoft,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                KeroseneIcons.serverUnavailable,
                color: KeroseneBrandTokens.textSecondary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr.deferredLoadFailure,
                style: const TextStyle(color: KeroseneBrandTokens.textPrimary),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr.deferredLoadDetails,
                  style: const TextStyle(
                    color: KeroseneBrandTokens.textMuted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.tr.tryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
