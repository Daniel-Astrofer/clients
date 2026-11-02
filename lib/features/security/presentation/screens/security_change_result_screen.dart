import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import '../widgets/recovery_codes_sheet.dart';

/// Acknowledged security changes stay visible until an explicit next step.
/// Recovery codes remain in memory and are revealed only by their owner.
class SecurityChangeResultScreen extends ConsumerStatefulWidget {
  final String title;
  final String body;
  final String ownerScope;
  final List<String> codes;
  const SecurityChangeResultScreen(
      {super.key,
      required this.title,
      required this.body,
      required this.ownerScope,
      this.codes = const []});
  @override
  ConsumerState<SecurityChangeResultScreen> createState() =>
      _SecurityChangeResultState();
}

class _SecurityChangeResultState
    extends ConsumerState<SecurityChangeResultScreen>
    with WidgetsBindingObserver {
  late final List<String> _codes;
  bool _foreground = true;
  bool _openingCodes = false;
  @override
  void initState() {
    super.initState();
    _codes = List.unmodifiable(widget.codes);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  bool get _owns =>
      mounted &&
      ref.read(sessionStorageScopeProvider)?.trim() == widget.ownerScope;
  Future<void> _showCodes() async {
    if (!_owns || !_foreground || _openingCodes || _codes.isEmpty) return;
    setState(() => _openingCodes = true);
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          sheetAnimationStyle: AnimationStyle(
              duration: KeroseneMotion.duration(context, KeroseneMotion.short),
              reverseDuration:
                  KeroseneMotion.duration(context, KeroseneMotion.short)),
          builder: (_) =>
              RecoveryCodesSheet(codes: _codes, ownerScope: widget.ownerScope));
    } finally {
      if (mounted) setState(() => _openingCodes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owns =
        ref.watch(sessionStorageScopeProvider)?.trim() == widget.ownerScope;
    final tr = context.tr;
    final theme = Theme.of(context);
    final visible = owns && _foreground;
    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        KeroseneIcon(
                            visible
                                ? KeroseneIcons.success
                                : KeroseneIcons.warning,
                            size: 48),
                        const SizedBox(height: 24),
                        Text(
                            visible
                                ? widget.title
                                : owns
                                    ? tr.securitySensitiveHiddenMessage
                                    : tr.securitySessionChangedMessage,
                            key: const ValueKey('security-change-result-title'),
                            textAlign: TextAlign.center,
                            style: AppTypography.playfairDisplay(
                                color: theme.colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                height: 1.14)),
                        if (visible) ...[
                          const SizedBox(height: 16),
                          Text(widget.body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium),
                          if (_codes.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(tr.securityResultCodesReady(_codes.length),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium),
                          ],
                        ],
                      ]))),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visible && _codes.isNotEmpty) ...[
                      AppButton(
                          key: const ValueKey('security-result-view-codes'),
                          label: tr.securityRevealCodesAction,
                          expand: true,
                          onPressed: _openingCodes ? null : _showCodes),
                      const SizedBox(height: 12),
                    ],
                    AppButton(
                        key: const ValueKey('security-result-done'),
                        label: tr.securityCredentialDoneAction,
                        expand: true,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(owns)),
                  ])),
        ])));
  }
}
