import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Canonical loading state for Kerosene screens.
///
/// Three variants:
/// - [KeroseneLoadingState.fullScreen]: branded loader with logo, for first launch
/// - [KeroseneLoadingState.inline]: compact indicator for section-level loading
/// - [KeroseneLoadingState.subtle]: minimal indicator for background refresh
///
/// Minimum display time: [KeroseneMotion.loadingMinimum] (3s) to avoid flash.
/// After [timeout], shows a retry option.
class KeroseneLoadingState extends StatefulWidget {
  final String? message;
  final Duration timeout;
  final VoidCallback? onTimeout;
  final KeroseneLoadingVariant variant;

  /// Full-screen branded loader. Use for first launch / screen-level loading.
  const KeroseneLoadingState.fullScreen({
    super.key,
    this.message,
    this.timeout = KeroseneMotion.loadingTimeout,
    this.onTimeout,
  }) : variant = KeroseneLoadingVariant.fullScreen;

  /// Compact inline loader. Use for section-level loading within a screen.
  const KeroseneLoadingState.inline({
    super.key,
    this.message,
    this.timeout = KeroseneMotion.loadingRetryMedium,
    this.onTimeout,
  }) : variant = KeroseneLoadingVariant.inline;

  /// Minimal indicator. Use when data is refreshing in background.
  const KeroseneLoadingState.subtle({
    super.key,
    this.message,
    this.timeout = KeroseneMotion.loadingRetryLong,
    this.onTimeout,
  }) : variant = KeroseneLoadingVariant.subtle;

  @override
  State<KeroseneLoadingState> createState() => _KeroseneLoadingStateState();
}

enum KeroseneLoadingVariant { fullScreen, inline, subtle }

class _KeroseneLoadingStateState extends State<KeroseneLoadingState> {
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    if (widget.onTimeout != null && widget.timeout > Duration.zero) {
      Future<void>.delayed(widget.timeout, () {
        if (!mounted) return;
        setState(() => _showRetry = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return switch (widget.variant) {
      KeroseneLoadingVariant.fullScreen => _FullScreenLoader(
        message: widget.message,
        showRetry: _showRetry,
        onRetry: widget.onTimeout,
        palette: palette,
      ),
      KeroseneLoadingVariant.inline => _InlineLoader(
        message: widget.message,
        showRetry: _showRetry,
        onRetry: widget.onTimeout,
        palette: palette,
      ),
      KeroseneLoadingVariant.subtle => _SubtleLoader(
        message: widget.message,
        showRetry: _showRetry,
        onRetry: widget.onTimeout,
        palette: palette,
      ),
    };
  }
}

class _FullScreenLoader extends StatelessWidget {
  final String? message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final KeroseneBrandTheme palette;

  const _FullScreenLoader({
    required this.message,
    required this.showRetry,
    required this.onRetry,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Branded loading indicator — use existing KeroseneLogoLoadingView
          // or custom animated glyph
          if (!showRetry) ...[
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(palette.textSecondary),
              ),
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.module),
              Text(
                message!,
                style: AppTypography.inter(
                  fontSize: 15,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ] else ...[
            Text(
              context.tr.loadingTimeout,
              style: AppTypography.inter(
                fontSize: 15,
                color: palette.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(context.tr.tryAgain)),
          ],
        ],
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  final String? message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final KeroseneBrandTheme palette;

  const _InlineLoader({
    required this.message,
    required this.showRetry,
    required this.onRetry,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.module),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showRetry) ...[
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(palette.textSecondary),
                ),
              ),
              if (message != null) ...[
                SizedBox(height: AppSpacing.base),
                Text(
                  message!,
                  style: AppTypography.inter(
                    fontSize: 13,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ] else if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(context.tr.tryAgain)),
          ],
        ),
      ),
    );
  }
}

class _SubtleLoader extends StatelessWidget {
  final String? message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final KeroseneBrandTheme palette;

  const _SubtleLoader({
    required this.message,
    required this.showRetry,
    required this.onRetry,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.base,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(palette.textMuted),
            ),
          ),
          if (message != null) ...[
            SizedBox(width: AppSpacing.sm),
            Text(
              message!,
              style: AppTypography.inter(
                fontSize: 12,
                color: palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
