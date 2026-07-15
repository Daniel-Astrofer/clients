import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Best-effort block of screenshots / screen recording while sensitive UI is up.
///
/// Android: [WindowManager.LayoutParams.FLAG_SECURE] via platform channel.
/// iOS / desktop / web: no hard block (OS limitation); still pairs with
/// [SecureSeedVisibility] to hide secrets when the app backgrounds.
class SecureScreenGuard {
  SecureScreenGuard._();

  static const MethodChannel _channel =
      MethodChannel('com.kerosene.app/secure_screen');

  static int _depth = 0;

  /// Enter a secure scope (ref-counted for nested routes).
  static Future<void> enter() async {
    _depth++;
    if (_depth == 1) {
      await _setPlatformSecure(true);
    }
  }

  /// Leave a secure scope.
  static Future<void> leave() async {
    if (_depth <= 0) {
      _depth = 0;
      return;
    }
    _depth--;
    if (_depth == 0) {
      await _setPlatformSecure(false);
    }
  }

  static Future<void> _setPlatformSecure(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } on MissingPluginException {
      // Platform not wired (tests / desktop).
    } on PlatformException {
      // Best-effort only.
    }
  }
}

/// Enables [SecureScreenGuard] for the lifetime of [child].
class SecureScreenScope extends StatefulWidget {
  final Widget child;

  const SecureScreenScope({super.key, required this.child});

  @override
  State<SecureScreenScope> createState() => _SecureScreenScopeState();
}

class _SecureScreenScopeState extends State<SecureScreenScope> {
  @override
  void initState() {
    super.initState();
    SecureScreenGuard.enter();
  }

  @override
  void dispose() {
    SecureScreenGuard.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Hides seed words when the app is backgrounded / inactive (multi-tasker leak).
///
/// Call [reveal] only after explicit user action. Lifecycle automatically
/// calls [hide].
class SecureSeedVisibility with WidgetsBindingObserver {
  SecureSeedVisibility({required this.onChanged});

  final VoidCallback onChanged;
  bool visible = false;
  bool _observing = false;

  void attach() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void detach() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  void reveal() {
    if (visible) return;
    visible = true;
    onChanged();
  }

  void hide() {
    if (!visible) return;
    visible = false;
    onChanged();
  }

  void toggle() {
    if (visible) {
      hide();
    } else {
      reveal();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      hide();
    }
  }
}
