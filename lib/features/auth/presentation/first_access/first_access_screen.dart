import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/watch_only_import_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import '../widgets/auth_motion.dart';
import 'first_access_progress.dart';

/// Post-authentication account choice. Financial readiness always comes from the server.
class FirstAccessScreen extends ConsumerStatefulWidget {
  const FirstAccessScreen({super.key});

  @override
  ConsumerState<FirstAccessScreen> createState() => _FirstAccessScreenState();
}

class _FirstAccessScreenState extends ConsumerState<FirstAccessScreen> {
  final _label = TextEditingController();
  String? _owner;
  String? _scope;
  int _errorRevision = 0;
  String? _error;
  bool _busy = false;
  bool _ready = false;
  bool _unknownCreation = false;
  bool _resumeReady = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    _owner = auth is AuthAuthenticated ? auth.user.id : null;
    _scope = ref.read(sessionStorageScopeProvider);
    if (_owner != null) {
      // A saved checkpoint resumes reconciliation, never asserts readiness.
      _resumeReady = FirstAccessProgress.isReady(
          ref.read(sharedPreferencesProvider), _owner!);
      _unknownCreation = _resumeReady ||
          FirstAccessProgress.isPendingCreation(
              ref.read(sharedPreferencesProvider), _owner!);
    }
  }

  bool get _owns {
    final auth = ref.read(authControllerProvider);
    return mounted &&
        _scope != null &&
        ref.read(sessionStorageScopeProvider) == _scope &&
        auth is AuthAuthenticated &&
        auth.user.id == _owner;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_owns) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (_owns) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorRevision++;
          _error = ErrorTranslator.translate(context.tr, error.toString());
        });
      }
    } finally {
      if (_owns) setState(() => _busy = false);
    }
  }

  Future<void> _showReady() async {
    if (!_owns) return;
    final accounts = ref.read(bitcoinAccountsProvider).asData?.value;
    if (accounts == null ||
        ref.read(bitcoinAccountsSyncProvider).hasError ||
        !accounts.any((account) => account.isActive)) {
      setState(() => _error = context.tr.firstAccessNotReady);
      return;
    }
    await FirstAccessProgress.ready(
        ref.read(sharedPreferencesProvider), _owner!);
    if (!_owns) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _ready = true;
      _unknownCreation = false;
    });
  }

  Future<void> _createOnchain() {
    final defaultLabel = context.tr.homeOnchainTab;
    return _run(() async {
      final controller = ref.read(bitcoinAccountsControllerProvider);
      await controller.refresh();
      if (!_owns) return;
      final accounts = ref.read(bitcoinAccountsProvider).asData?.value;
      if (accounts == null || ref.read(bitcoinAccountsSyncProvider).hasError) {
        setState(() => _error = context.tr.firstAccessNotReady);
        return;
      }
      if (accounts.any((a) => a.isCustodialOnchain && a.isActive)) {
        await _showReady();
        return;
      }
      // A lost POST reply is never automatically retransmitted.
      await FirstAccessProgress.creating(
          ref.read(sharedPreferencesProvider), _owner!);
      if (!_owns) return;
      setState(() => _unknownCreation = true);
      final BitcoinAccount created;
      try {
        created = await controller.createWallet(
            label:
                _label.text.trim().isEmpty ? defaultLabel : _label.text.trim(),
            custody: BitcoinAccountCustody.custodialOnchain);
      } on AppException catch (error) {
        // An explicit rejection allows correction; transport/5xx outcomes
        // retain the reconciliation checkpoint to avoid duplicate creation.
        if (_owns && const [400, 403, 422].contains(error.statusCode)) {
          await FirstAccessProgress.markPending(
              ref.read(sharedPreferencesProvider), _owner!);
          if (_owns) setState(() => _unknownCreation = false);
        }
        rethrow;
      }
      if (!_owns) return;
      if (created.isActive) {
        await _showReady();
      } else {
        setState(() => _error = context.tr.firstAccessNotReady);
      }
    });
  }

  Future<void> _reconcile() => _run(() async {
        await ref.read(bitcoinAccountsControllerProvider).refresh();
        if (!_owns) return;
        final accounts = ref.read(bitcoinAccountsProvider).asData?.value;
        if (accounts == null ||
            ref.read(bitcoinAccountsSyncProvider).hasError) {
          setState(() => _error = context.tr.firstAccessNotReady);
          return;
        }
        if (accounts
            .any((a) => a.isActive && (_resumeReady || a.isCustodialOnchain))) {
          await _showReady();
        } else {
          setState(() => _error = context.tr.firstAccessCreationUnknown);
        }
      });

  Future<void> _importWatchOnly() => _run(() async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                WatchOnlyImportScreen(initialLabel: _label.text.trim())));
        if (!_owns) return;
        await ref.read(bitcoinAccountsControllerProvider).refresh();
        if (!_owns) return;
        final accounts = ref.read(bitcoinAccountsProvider).asData?.value;
        if (accounts != null &&
            accounts.any((a) => a.isWatchOnly && a.isActive)) {
          await _showReady();
        }
      });

  Future<void> _finish({bool receive = false, bool explore = false}) =>
      _run(() async {
        if (!explore) {
          await ref.read(bitcoinAccountsControllerProvider).refresh();
          if (!_owns) return;
          final accounts = ref.read(bitcoinAccountsProvider).asData?.value;
          if (accounts == null ||
              accounts.where((a) => a.isActive).isEmpty ||
              ref.read(bitcoinAccountsSyncProvider).hasError ||
              (receive && !accounts.any((a) => a.isActive && !a.isWatchOnly))) {
            setState(() {
              _ready = false;
              _error = context.tr.firstAccessNotReady;
            });
            return;
          }
        }
        await FirstAccessProgress.complete(
            ref.read(sharedPreferencesProvider), _owner!);
        if (!_owns || !mounted) return;
        unawaited(ref.read(walletProvider.notifier).refresh());
        context.go(receive ? '/receive' : '/home');
      });

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthAuthenticated || !_owns) {
      return Scaffold(
          body: Center(
              child: TextButton(
        onPressed: () => context.go('/login'),
        child: Text(context.tr.firstAccessSignIn),
      )));
    }
    final theme = Theme.of(context);
    final reduce = KeroseneMotion.reduceMotion(context);
    final accounts = ref.watch(bitcoinAccountsProvider).asData?.value;
    final hasSpendable =
        accounts?.any((a) => !a.isWatchOnly && a.isActive) == true;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: context.responsive.formConstraints,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthMotionShake(
                triggerKey: _errorRevision,
                child: AnimatedSwitcher(
                  duration: reduce ? Duration.zero : KeroseneMotion.medium,
                  child: AuthMotionStagger(
                    key: ValueKey(_ready),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('KEROSENE', style: AppTypography.label),
                      const SizedBox(height: 40),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(('icon', _ready)),
                        tween: Tween(begin: reduce ? 1 : 0.92, end: 1),
                        duration:
                            reduce ? Duration.zero : KeroseneMotion.success,
                        builder: (_, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: KeroseneIcon(
                                _ready
                                    ? KeroseneIcons.success
                                    : KeroseneIcons.wallet,
                                size: 48,
                                color: theme.colorScheme.onSurface)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                          _ready
                              ? context.tr.firstAccessReadyTitle
                              : context.tr.firstAccessChoiceTitle,
                          style: AppTypography.inter(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 12),
                      Text(
                          _ready
                              ? context.tr.firstAccessReadyBody
                              : context.tr.firstAccessChoiceBody,
                          style: AppTypography.bodyMedium.copyWith(
                              fontSize: 14,
                              height: 1.45,
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 28),
                      if (!_ready && !_unknownCreation) ...[
                        TextField(
                            controller: _label,
                            enabled: !_busy,
                            maxLength: 80,
                            decoration: InputDecoration(
                                labelText: context.tr.firstAccessAccountLabel)),
                        const SizedBox(height: 16),
                        _option(
                            context.tr.homeOnchainTab,
                            context.tr.firstAccessOnchainBody,
                            KeroseneIcons.onchain,
                            _busy ? null : _createOnchain),
                        const SizedBox(height: 12),
                        _option(
                            context.tr.homeColdTab,
                            context.tr.firstAccessWatchBody,
                            KeroseneIcons.visibility,
                            _busy ? null : _importWatchOnly),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: AppTypography.bodySmall
                                    .copyWith(color: theme.colorScheme.error))),
                      ],
                      if (_busy) ...[
                        const SizedBox(height: 24),
                        const Center(
                            child: CircularProgressIndicator.adaptive()),
                        const SizedBox(height: 12),
                        Text(context.tr.firstAccessPreparing,
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 28),
                      if (_unknownCreation && !_ready)
                        FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: theme.colorScheme.onSurface,
                                foregroundColor: theme.colorScheme.surface),
                            onPressed: _busy ? null : _reconcile,
                            child: Text(context.tr.firstAccessCheckStatus)),
                      if (_ready) ...[
                        FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: theme.colorScheme.onSurface,
                                foregroundColor: theme.colorScheme.surface),
                            onPressed: _busy ? null : () => _finish(),
                            child: Text(context.tr.firstAccessGoHome)),
                        if (hasSpendable)
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _finish(receive: true),
                              child: Text(context.tr.homeReceiveActionShort)),
                      ] else
                        TextButton(
                            onPressed:
                                _busy ? null : () => _finish(explore: true),
                            child: Text(context.tr.firstAccessExplore)),
                    ],
                  ),
                )),
          ),
        ))),
      ),
    );
  }

  Widget _option(
          String title, String body, IconData icon, VoidCallback? onTap) =>
      AuthMotionPressScale(
          enabled: onTap != null,
          child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  minimumSize: const Size.fromHeight(76)),
              child: Row(children: [
                KeroseneIcon(icon, size: 26),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(body, style: AppTypography.bodySmall),
                    ])),
              ])));
}
