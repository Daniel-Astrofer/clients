import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;

/// A short settings decision remains bound to the account that opened it.
Future<bool> confirmAccountSetting(
  BuildContext context, {
  required String ownerScope,
  required String title,
  required String body,
  required String confirmLabel,
  String? accountName,
  String? accountId,
  List<({String label, String value})> details = const [],
  IconData icon = KeroseneIcons.security,
}) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      animationStyle: AnimationStyle(
          duration: KeroseneMotion.duration(context, KeroseneMotion.short),
          reverseDuration:
              KeroseneMotion.duration(context, KeroseneMotion.short)),
      builder: (_) => _AccountConfirmation(
          ownerScope: ownerScope,
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          accountName: accountName,
          accountId: accountId,
          details: details,
          icon: icon),
    ) ??
    false;

class _AccountConfirmation extends ConsumerStatefulWidget {
  final String ownerScope;
  final String title;
  final String body;
  final String confirmLabel;
  final String? accountName;
  final String? accountId;
  final List<({String label, String value})> details;
  final IconData icon;
  const _AccountConfirmation(
      {required this.ownerScope,
      required this.title,
      required this.body,
      required this.confirmLabel,
      this.accountName,
      this.accountId,
      required this.details,
      required this.icon});
  @override
  ConsumerState<_AccountConfirmation> createState() =>
      _AccountConfirmationState();
}

class _AccountConfirmationState extends ConsumerState<_AccountConfirmation>
    with WidgetsBindingObserver {
  bool _closing = false;
  bool _decided = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) _dismiss();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route?.isActive == true) {
        Navigator.of(context).removeRoute(route!, false);
      }
    });
  }

  void _close(bool result) {
    if (_closing || _decided || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _decided = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionStorageScopeProvider)?.trim() != widget.ownerScope) {
      _dismiss();
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeroseneIcon(widget.icon, size: 28),
                          const SizedBox(height: 12),
                          Text(widget.title,
                              style: AppTypography.playfairDisplay(
                                  fontSize: 20,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 16),
                          Text(widget.body, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          for (final detail in widget.details) ...[
                            Text(detail.label,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            SelectableText(detail.value,
                                style: AppTypography.technicalMono(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 12),
                          ],
                          if (widget.accountName?.trim().isNotEmpty ==
                              true) ...[
                            Text(context.tr.settingsConfirmationAccount,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            SelectableText(widget.accountName!,
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 12),
                          ],
                          Text(context.tr.txListId,
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          SelectableText(widget.accountId ?? widget.ownerScope,
                              style: AppTypography.technicalMono(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 16),
                        ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                          key: const ValueKey('settings-account-confirm'),
                          label: widget.confirmLabel,
                          expand: true,
                          onPressed: () => _close(true)),
                      const SizedBox(height: 12),
                      AppButton(
                          label: context.tr.cancel,
                          expand: true,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => _close(false)),
                    ])),
          ])),
    );
  }
}
