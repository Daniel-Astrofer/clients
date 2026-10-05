import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic signal emitted when the HTTP layer confirms the local session
/// cannot be trusted anymore.
final sessionInvalidationProvider =
    NotifierProvider<SessionInvalidationNotifier, int>(
  SessionInvalidationNotifier.new,
);

class SessionInvalidationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void emit() {
    state += 1;
  }
}

/// Bumped when the access token is persisted (login / silent refresh).
///
/// Realtime listeners watch this so STOMP reconnects with a fresh JWT instead
/// of keeping the credential captured at socket construction time.
final sessionCredentialVersionProvider =
    NotifierProvider<SessionCredentialVersionNotifier, int>(
  SessionCredentialVersionNotifier.new,
);

class SessionCredentialVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}
