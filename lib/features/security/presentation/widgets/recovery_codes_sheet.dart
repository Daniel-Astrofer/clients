import 'package:kerosene/core/security/secure_screen_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

bool hasUsableRecoveryCodes(List<String> codes) =>
    codes.isNotEmpty &&
    codes.every((code) => code.trim().isNotEmpty) &&
    codes.toSet().length == codes.length;

/// One-time codes remain in memory, bound to the account that generated them.
class RecoveryCodesSheet extends ConsumerStatefulWidget {
  final List<String> codes;
  final String? ownerScope;
  const RecoveryCodesSheet(
      {super.key, required this.codes, required this.ownerScope});

  @override
  ConsumerState<RecoveryCodesSheet> createState() => _RecoveryCodesSheetState();
}

class _RecoveryCodesSheetState extends ConsumerState<RecoveryCodesSheet>
    with WidgetsBindingObserver {
  bool _revealed = true;
  bool _foreground = true;
  bool _copying = false;
  late final List<String> _codes;

  @override
  void initState() {
    super.initState();
    _codes = List.unmodifiable(widget.codes);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _revealed = _foreground;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _revealed = false;
    });
  }

  bool get _ownsCodes =>
      widget.ownerScope != null &&
      ref.read(sessionStorageScopeProvider) == widget.ownerScope;

  Future<void> _copy() async {
    if (!_ownsCodes || !_revealed || !_foreground || _copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: _codes.join('\n')));
      if (!mounted || !_ownsCodes || !_foreground) return;
      AppNotice.showInfo(context,
          title: context.tr.settingsBackupCopiedTitle,
          message: context.tr.settingsBackupCopiedMessage);
    } catch (_) {
      if (mounted && _ownsCodes && _foreground) {
        AppNotice.showError(context,
            title: context.tr.securityBackupCodesTitle,
            message: context.tr.securityCopyFailedMessage);
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionStorageScopeProvider);
    final visible = _ownsCodes && _foreground && _revealed;
    return SecureScreenScope(
        child: SafeArea(
            child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        decoration: monochromePanelDecoration(
            color: monoSurfaceColor, borderColor: monoBorderStrongColor),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr.securityBackupCodesTitle.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: monoMutedTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    visible
                        ? context.tr.securityBackupCodesBody
                        : context.tr.securitySensitiveHiddenMessage,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: monoMutedTextColor, height: 1.45)),
                if (visible) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _codes
                          .map((code) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: monochromePanelDecoration(
                                    color: monoSurfaceAltColor,
                                    borderColor: monoBorderStrongColor,
                                    showShadow: false),
                                child: Text(code,
                                    style: AppTypography.technicalMono(
                                        color: monoTextColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ))
                          .toList()),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                      onPressed: _copying ? null : _copy,
                      child: Text(context.tr.settingsBackupCopyAll)),
                ] else if (_ownsCodes && _foreground) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                      onPressed: () => setState(() => _revealed = true),
                      child: Text(context.tr.securityRevealCodesAction)),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr.close)),
              ]),
        ),
      ),
    )));
  }
}
