import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

typedef DeferredWidgetBuilder = Widget Function(BuildContext context);

/// Dedupes [loadLibrary] so prefetch + first navigation share one Future.
final Map<Future<void> Function(), Future<void>> _deferredLibraryCache = {};

/// Load (or reuse) a deferred library. Safe to call from idle prefetch.
Future<void> loadDeferredLibrary(Future<void> Function() loadLibrary) {
  return _deferredLibraryCache.putIfAbsent(loadLibrary, loadLibrary);
}

/// Prefetch several deferred libs without blocking the UI isolate critically.
void prefetchDeferredLibraries(
  Iterable<Future<void> Function()> loaders,
) {
  for (final load in loaders) {
    // Fire-and-forget; errors are ignored until real navigation surfaces them.
    loadDeferredLibrary(load).ignore();
  }
}

class DeferredPage extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final DeferredWidgetBuilder builder;
  final Widget? loading;

  /// When false, skip the library-ready fade/micro-slide (useful when the
  /// route already has a full-bleed page transition).
  final bool animateReveal;

  const DeferredPage({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loading,
    this.animateReveal = true,
  });

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _libraryFuture;

  @override
  void initState() {
    super.initState();
    _libraryFuture = loadDeferredLibrary(widget.loadLibrary);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _libraryFuture,
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.connectionState != ConnectionState.done) {
          child = widget.loading ?? const _DeferredPageLoadingView();
        } else if (snapshot.hasError) {
          child = _DeferredPageErrorView(error: snapshot.error);
        } else {
          child = widget.builder(context);
        }

        if (!widget.animateReveal ||
            KeroseneMotion.reduceMotion(context)) {
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
              snapshot.connectionState == ConnectionState.done
                  ? snapshot.hasError
                      ? snapshot.error ?? 'deferred-error'
                      : 'deferred-ready'
                  : 'deferred-loading',
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _DeferredPageLoadingView extends StatelessWidget {
  const _DeferredPageLoadingView();

  @override
  Widget build(BuildContext context) {
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

  const _DeferredPageErrorView({this.error});

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
            ],
          ),
        ),
      ),
    );
  }
}
