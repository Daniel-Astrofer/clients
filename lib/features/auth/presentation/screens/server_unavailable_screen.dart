import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/app_cold_start_provider.dart';
import 'package:kerosene/core/providers/network_status_provider.dart';
import 'package:kerosene/design_system/components/auth/auth_primary_cta.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';

class ServerAvailabilityGate extends ConsumerStatefulWidget {
  final Widget child;

  const ServerAvailabilityGate({super.key, required this.child});

  @override
  ConsumerState<ServerAvailabilityGate> createState() =>
      _ServerAvailabilityGateState();
}

class _ServerAvailabilityGateState
    extends ConsumerState<ServerAvailabilityGate> {
  bool _showingUnavailableScreen = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(networkStatusProvider);
    final authState = ref.watch(authControllerProvider);
    final torSettled = ref.watch(torSettledProvider);
    final pinUnlocked = ref.watch(appEntryPinUnlockedProvider);

    // During cold session bootstrap the shell shows the K logo. Do not replace
    // it with "server unavailable" for transient offline/Tor-up probes.
    if (authState is AuthInitial ||
        (authState is AuthLoading && !_showingUnavailableScreen)) {
      _showingUnavailableScreen = false;
      return widget.child;
    }

    // Authenticated + PIN gate / Tor still warming: the PIN flow owns the UX
    // (dots while held PIN waits for Tor). Never cover it with offline dialog.
    if (authState is AuthAuthenticated && (!torSettled || !pinUnlocked)) {
      _showingUnavailableScreen = false;
      return widget.child;
    }

    final isUnavailable = !isOnline || authState is AuthServerUnavailable;
    final isRetryingUnavailable =
        _showingUnavailableScreen && authState is AuthLoading;

    if (isUnavailable || isRetryingUnavailable) {
      _showingUnavailableScreen = true;
      return const ServerUnavailableScreen();
    }

    _showingUnavailableScreen = false;
    return widget.child;
  }
}

class ServerUnavailableScreen extends ConsumerWidget {
  final String message;
  final String? retryRouteName;
  final Future<void> Function()? onRetryOverride;

  const ServerUnavailableScreen({
    super.key,
    this.message = 'Servidor em manutenção',
    this.retryRouteName,
    this.onRetryOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;
    const title = 'Conexão indisponível';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: KeroseneBrandTokens.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Icon(
                            KeroseneIcons.serverUnavailable,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl2),
                      Text(
                        title,
                        style: AppTypography.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          height: 1.08,
                          letterSpacing: 0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl2),
                      AuthPrimaryCta(
                        label: context.tr.tryAgain,
                        onPressed:
                            isLoading ? null : () => _retry(context, ref),
                        isLoading: isLoading,
                        height: 54,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        textStyle: AppTypography.buttonText.copyWith(
                          fontSize: 15,
                          fontWeight: AppTypography.w590,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    if (onRetryOverride != null) {
      await onRetryOverride!();
      return;
    }

    if (retryRouteName != null) {
      GoRouter.of(context).go(retryRouteName!);
      return;
    }

    final authState = ref.read(authControllerProvider);
    if (authState is AuthServerUnavailable ||
        authState is AuthAuthenticated ||
        authState is AuthLoading) {
      await ref.read(authControllerProvider.notifier).retrySessionCheck();
      return;
    }

    await ref.read(networkStatusProvider.notifier).checkConnection();
  }
}
