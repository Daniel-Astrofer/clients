import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Canonical offline state for Kerosene screens.
///
/// Shows last-known data with an offline badge. Does NOT replace the entire
/// screen — the user can still see their data. Auto-retries with pulse.
///
/// Usage:
/// ```dart
/// // As overlay on existing content:
/// Column(children: [
///   if (isOffline) const KeroseneOfflineBanner(lastSync: '12:45'),
///   ...existingContent,
/// ])
///
/// // Or as standalone state (first launch, no cached data):
/// const KeroseneOfflineState.fullScreen()
/// ```
class KeroseneOfflineBanner extends StatelessWidget {
  final String? lastSyncTime;
  final VoidCallback? onRetry;

  const KeroseneOfflineBanner({
    super.key,
    this.lastSyncTime,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.base,
      ),
      color: AppColors.hexFF23252A, // Smoke surface
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 14,
            color: KeroseneBrandTokens.warning,
            semanticLabel: 'Offline',
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              lastSyncTime != null
                  ? 'Offline — Ultima sincronizacao: $lastSyncTime'
                  : 'Sem conexao',
              style: AppTypography.inter(
                fontSize: 12,
                color: palette.textSecondary,
              ),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Tentar',
                style: AppTypography.inter(
                  fontSize: 12,
                  color: palette.textPrimary,
                  fontWeight: AppTypography.w510,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen offline state for first launch when no cached data is available.
class KeroseneOfflineFullScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const KeroseneOfflineFullScreen({super.key, this.onRetry});

  @override
  State<KeroseneOfflineFullScreen> createState() =>
      _KeroseneOfflineFullScreenState();
}

class _KeroseneOfflineFullScreenState extends State<KeroseneOfflineFullScreen> {
  late final Timer _retryTimer;

  @override
  void initState() {
    super.initState();
    // Auto-retry pulse at offline interval
    _retryTimer = Timer.periodic(
      KeroseneMotion.offlineRetryInterval,
      (_) => widget.onRetry?.call(),
    );
  }

  @override
  void dispose() {
    _retryTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KeroseneBrandTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.module),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: palette.textTertiary,
              semanticLabel: 'Sem conexao',
            ),
            SizedBox(height: AppSpacing.base),
            Text(
              'Sem conexao',
              style: AppTypography.inter(
                fontSize: 15,
                color: palette.textPrimary,
                fontWeight: AppTypography.w510,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Verifique sua conexao com a internet.\n'
              'Tentando reconectar automaticamente...',
              style: AppTypography.inter(
                fontSize: 13,
                color: palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                child: Text('Tentar agora'),
              ),
          ],
        ),
      ),
    );
  }
}
