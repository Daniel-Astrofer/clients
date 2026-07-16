import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/presentation/widgets/app_notice.dart';
import 'package:kerosene/core/theme/monochrome_theme.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_providers.dart';

import 'security_settings_components.dart';
import 'security_totp_screen.dart' deferred as security_totp;
import 'settings_modern_components.dart';
import 'settings_navigation.dart';
import 'settings_route_helpers.dart';

/// Backup codes management — real API status + regenerate (requires TOTP).
class SettingsBackupCodesScreen extends ConsumerStatefulWidget {
  const SettingsBackupCodesScreen({super.key});

  @override
  ConsumerState<SettingsBackupCodesScreen> createState() =>
      _SettingsBackupCodesScreenState();
}

class _SettingsBackupCodesScreenState
    extends ConsumerState<SettingsBackupCodesScreen> {
  List<String> _latestCodes = const [];
  bool _busy = false;

  Future<void> _regenerate() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KeroseneBrandTokens.surfaceMuted,
        title: Text(
          context.tr.securityBackupCodesTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          context.tr.securityBackupCodesBody,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr.securityRegenerateCodesAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).regenerateBackupCodes();
      if (!mounted) return;
      result.fold(
        (failure) {
          AppNotice.showError(
            context,
            title: context.tr.securityBackupRegenerateFailedTitle,
            message: ErrorTranslator.translate(context.tr, failure.message),
          );
        },
        (status) {
          setState(() => _latestCodes = status.newlyGeneratedCodes);
          ref.invalidate(backupCodesStatusProvider);
          ref.invalidate(securityStatusProvider);
          if (status.newlyGeneratedCodes.isNotEmpty) {
            _showCodesSheet(status.newlyGeneratedCodes);
          }
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCodesSheet(List<String> codes) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: monochromePanelDecoration(
              color: monoSurfaceColor,
              borderColor: monoBorderStrongColor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr.securityBackupCodesTitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: monoMutedTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr.securityBackupCodesBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: monoMutedTextColor,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: codes
                      .map(
                        (code) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: monochromePanelDecoration(
                            color: monoSurfaceAltColor,
                            borderColor: monoBorderStrongColor,
                            showShadow: false,
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              color: monoTextColor,
                              fontFamily: AppTypography.financialFontFamily,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: codes.join('\n')),
                    );
                    if (!mounted) return;
                    AppNotice.showInfo(
                      context,
                      title: context.tr.settingsBackupCopiedTitle,
                      message: context.tr.settingsBackupCopiedMessage,
                    );
                  },
                  child: Text(context.tr.settingsBackupCopyAll),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final securityAsync = ref.watch(securityStatusProvider);
    final backupAsync = ref.watch(backupCodesStatusProvider);
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl2,
                AppSpacing.md,
                AppSpacing.xl2,
                viewPadding.bottom + AppSpacing.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: context.responsive.appColumnConstraints,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsHeader(
                          onClose: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).maybePop();
                          },
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          context.tr.settingsBackupTitle,
                          style: AppTypography.newsreader(
                            color: KeroseneBrandTokens.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.tr.settingsBackupSubtitle,
                          style: AppTypography.inter(
                            color: KeroseneBrandTokens.textSecondary,
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        securityAsync.when(
                          data: (security) {
                            if (!security.totpEnabled) {
                              return SettingsGlassPanel(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Icon(
                                      KeroseneIcons.verified,
                                      color: Colors.white70,
                                      size: 28,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      context.tr.settingsBackupEnableTotpFirst,
                                      style: AppTypography.inter(
                                        color: KeroseneBrandTokens.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      context.tr.securityBackupCodesLockedSubtitle,
                                      style: AppTypography.inter(
                                        color: KeroseneBrandTokens.textMuted,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    FilledButton(
                                      onPressed: () {
                                        pushSettingsDeferred(
                                          context,
                                          security_totp.loadLibrary,
                                          (_) => security_totp.SecurityTotpScreen(),
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: Text(
                                        context.tr.securityEnableTotpAction,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return backupAsync.when(
                              data: (backup) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SecuritySectionCard(
                                    title: context.tr.securityBackupCodesTitle,
                                    subtitle: context.tr
                                        .securityBackupCodesRemaining(
                                      backup.remainingCodes,
                                    ),
                                    actionLabel: _busy
                                        ? '…'
                                        : context
                                            .tr.securityRegenerateCodesAction
                                            .toUpperCase(),
                                    onAction: _busy ? null : _regenerate,
                                    trailing: _latestCodes.isNotEmpty
                                        ? TextButton(
                                            onPressed: () =>
                                                _showCodesSheet(_latestCodes),
                                            child: Text(
                                              context
                                                  .tr.securityViewLatestAction,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              error: (error, _) => SettingsGlassPanel(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  ErrorTranslator.translate(
                                    context.tr,
                                    error.toString(),
                                  ),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          error: (error, _) => SettingsGlassPanel(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              ErrorTranslator.translate(
                                context.tr,
                                error.toString(),
                              ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
