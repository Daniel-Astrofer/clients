import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'package:kerosene/core/security/secure_screen_guard.dart';

/// Applies [SecureScreenGuard] only when the user enabled screenshot blocking
/// for financial screens (extrato / detail / balance-heavy surfaces).
class FinancialSecureScope extends ConsumerStatefulWidget {
  final Widget child;

  const FinancialSecureScope({super.key, required this.child});

  @override
  ConsumerState<FinancialSecureScope> createState() =>
      _FinancialSecureScopeState();
}

class _FinancialSecureScopeState extends ConsumerState<FinancialSecureScope> {
  bool _secured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    if (_secured) {
      SecureScreenGuard.leave();
      _secured = false;
    }
    super.dispose();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final want = ref.read(privacyPreferencesProvider).blockFinancialScreenshots;
    if (want && !_secured) {
      await SecureScreenGuard.enter();
      _secured = true;
    } else if (!want && _secured) {
      await SecureScreenGuard.leave();
      _secured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(privacyPreferencesProvider, (prev, next) {
      _sync();
    });
    return widget.child;
  }
}
