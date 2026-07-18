import 'dart:async';

/// Latest-wins coalescer for high-frequency streams (SSE / WS text tokens).
///
/// Within [interval] (default ~1 frame @ 60Hz), only the newest value is kept
/// and flushed once. Structural / urgent events should call [force] so they
/// never wait behind a pending batch.
class FrameCoalescer<T> {
  FrameCoalescer({
    required void Function(T value) onFlush,
    this.interval = const Duration(milliseconds: 16),
  }) : _onFlush = onFlush;

  final void Function(T value) _onFlush;
  final Duration interval;

  T? _pending;
  Timer? _timer;
  bool _disposed = false;

  bool get hasPending => _pending != null;

  /// Queue [value]; previous pending of the same batch is dropped.
  void add(T value) {
    if (_disposed) return;
    _pending = value;
    _timer ??= Timer(interval, _flushTimer);
  }

  /// Cancel the timer and deliver [value] immediately (after any prior
  /// pending flush of a different path — callers should [flushPending] first
  /// when order matters across channels).
  void force(T value) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _onFlush(value);
  }

  /// Deliver whatever is waiting, if any.
  void flushPending() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      _onFlush(pending);
    }
  }

  /// Drop pending work without delivering (e.g. stage clear supersedes tokens).
  void cancelPending() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void _flushTimer() {
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && !_disposed) {
      _onFlush(pending);
    }
  }
}
