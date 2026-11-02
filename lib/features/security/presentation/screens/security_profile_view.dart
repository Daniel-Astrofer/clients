import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'settings_modern_components.dart';
import 'security_lookup.dart';

/// Retains only this account's successfully observed security data. A stale
/// snapshot remains readable, with its lookup time; it cannot authorize changes.
class SecurityProfileView extends ConsumerStatefulWidget {
  final Widget Function(AccountSecurityProfile profile, bool current) builder;
  const SecurityProfileView({super.key, required this.builder});
  @override
  ConsumerState<SecurityProfileView> createState() =>
      _SecurityProfileViewState();
}

class _SecurityProfileViewState extends ConsumerState<SecurityProfileView> {
  final _lookup = SecurityLookup<AccountSecurityProfile>();
  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(sessionStorageScopeProvider)?.trim();
    final source = ref.watch(accountSecurityProfileProvider);
    _lookup.observe(scope, source);
    final tr = context.tr;
    if (_lookup.last == null) {
      if (source.isLoading && scope?.isNotEmpty == true) {
        return SettingsLoadingPanel(label: tr.settingsSecurityLoading);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SettingsEmptyPanel(
            icon: KeroseneIcons.warning,
            title: tr.settingsSecurityLoadErrorTitle,
            body: tr.settingsSecurityLoadErrorBody),
        TextButton(
            key: const ValueKey('security-profile-retry'),
            onPressed: () => ref.invalidate(accountSecurityProfileProvider),
            child: Text(tr.tryAgain)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SecurityLookupNotice(
        sources: [(label: tr.securityScreenTitle, lookup: _lookup)],
        retryKey: 'security-profile-retry',
        onRetry: () => ref.invalidate(accountSecurityProfileProvider),
      ),
      widget.builder(_lookup.last!, _lookup.current),
    ]);
  }
}
