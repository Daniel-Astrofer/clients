import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web uses same-origin routing through the onion gateway. It must never load
/// the native Arti/FFI package, which is unavailable in browsers.
class TorService {
  static TorService? _instance;
  static TorService get instance => _instance ??= TorService._();
  TorService._();

  bool get isRunning => true;
  int get socksPort => 0;

  Future<bool> start() async => true;

  Future<void> stop() async {}

  Future<int> startRelay(
    String targetHost,
    int targetPort, {
    bool warmUpCircuit = false,
  }) async {
    throw UnsupportedError(
      'Native Tor relay is unavailable on web; use same-origin onion routing.',
    );
  }

  Future<void> warmOnionCircuit(String targetHost, int targetPort) async {}
}

final torServiceProvider = Provider<TorService>((ref) => TorService.instance);
