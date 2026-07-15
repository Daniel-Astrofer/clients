import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tor/tor.dart';

/// Manages the embedded Tor client lifecycle using the `tor` package
/// (Foundation Devices). Based on Arti (Rust Tor implementation).
/// On activation it starts a local SOCKS5 proxy on a dynamic port.
class TorService {
  static TorService? _instance;
  static TorService get instance => _instance ??= TorService._();
  TorService._();

  bool _isRunning = false;
  int _socksPort = 9050;
  Future<bool>? _startFuture;
  Future<bool>? _restartFuture;

  static const String _externalSocksHost = String.fromEnvironment(
    'KERO_TOR_SOCKS_HOST',
    defaultValue: '127.0.0.1',
  );
  static const int _externalSocksPort = int.fromEnvironment(
    'KERO_TOR_SOCKS_PORT',
    defaultValue: 0,
  );
  static const bool _purgeEmbeddedTorStateOnRestart = bool.fromEnvironment(
    'KERO_TOR_PURGE_STATE_ON_RESTART',
    defaultValue: false,
  );

  bool get isRunning => _isRunning;
  int get socksPort => _socksPort;
  bool get _usesExternalSocksProxy => _isValidPort(_externalSocksPort);
  String get _socksHost =>
      _usesExternalSocksProxy ? _externalSocksHost : '127.0.0.1';

  /// Starts the embedded Tor daemon via the `tor` package.
  /// Returns true if Tor is ready.
  Future<bool> start() async {
    if (_isRunning) return true;
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;

    _startFuture = _startInternal().whenComplete(() {
      if (!_isRunning) {
        _startFuture = null;
      }
    });
    return _startFuture!;
  }

  Future<bool> _startInternal() async {
    if (_usesExternalSocksProxy) {
      _socksPort = _externalSocksPort;
      try {
        debugPrint(
          '🧅 TorService: Using external SOCKS5 proxy at $_externalSocksHost:$_socksPort',
        );
        await _waitForProxyToBoot(_socksPort, timeoutSeconds: 10);
        _isRunning = true;
      } catch (_) {
        debugPrint(
          'Tor external SOCKS5 proxy is NOT answering on $_externalSocksHost:$_socksPort.',
        );
        _isRunning = false;
      }
      return _isRunning;
    }

    debugPrint('🧅 TorService: Initializing Tor (Arti) via tor package...');

    // Initialize and start the Tor proxy
    await Tor.init();
    await Tor.instance.start();

    // The `tor` package picks a free port automatically, but some mobile
    // builds briefly expose -1 while Arti is still bootstrapping. Never let
    // an invalid port reach Socket.connect; wait for a real SOCKS port first.
    _socksPort = await _waitForValidTorPackagePort();
    if (!_isValidPort(_socksPort)) {
      throw SocketException(
        'Tor package did not report a valid SOCKS5 port: $_socksPort',
      );
    }

    _isRunning = Tor.instance.started;
    if (_isRunning) {
      // Short window: SOCKS usually answers within a few hundred ms after port is valid.
      await _waitForProxyToBoot(_socksPort, timeoutSeconds: 8);
      debugPrint(
        '🧅 TorService: Tor (Arti) running on SOCKS5 port $_socksPort',
      );
    } else {
      debugPrint('🧅 TorService: Tor.instance.started returned false');
    }

    return _isRunning;
  }

  static bool _isValidPort(int port) => port > 0 && port <= 65535;

  Future<int> _waitForValidTorPackagePort({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final stopwatch = Stopwatch()..start();
    var lastPort = Tor.instance.port;

    while (stopwatch.elapsed < timeout) {
      lastPort = Tor.instance.port;
      if (_isValidPort(lastPort)) return lastPort;

      // 50ms poll — Arti often publishes the port quickly after start().
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return lastPort;
  }

  int _normalizeTargetPort(int targetPort) {
    if (_isValidPort(targetPort)) return targetPort;

    // Uri.port returns -1 when the URL has no explicit port. Hidden-service
    // HTTP URLs such as http://example.onion must still connect to port 80.
    debugPrint(
      '🧅 TorService: Invalid target port $targetPort; falling back to HTTP port 80.',
    );
    return 80;
  }

  /// Stops the embedded Tor daemon.
  Future<void> stop() async {
    await _closeRelays();
    if (!_isRunning) return;
    try {
      await Tor.instance.stop();
    } catch (e) {
      debugPrint('🧅 TorService: Error stopping Tor: $e');
    }
    _isRunning = false;
    _startFuture = null;
    debugPrint('🧅 TorService: Tor (Arti) stopped.');
  }

  Future<bool> _restartTorProxyForOnionFailure() async {
    final inFlight = _restartFuture;
    if (inFlight != null) return inFlight;

    _restartFuture = () async {
      debugPrint(
        '🧅 TorService: Restarting Tor proxy after onion connection failure.',
      );
      try {
        if (_isRunning) {
          await Tor.instance.stop();
        }
      } catch (error) {
        debugPrint('🧅 TorService: Error stopping stale Tor proxy: $error');
      }

      _isRunning = false;
      _startFuture = null;
      if (_purgeEmbeddedTorStateOnRestart) {
        await _purgeEmbeddedTorState();
      }
      final restarted = await start();
      if (restarted) {
        debugPrint(
          '🧅 TorService: Tor proxy restarted on SOCKS5 port $_socksPort.',
        );
      }
      return restarted;
    }()
        .whenComplete(() {
      _restartFuture = null;
    });

    return _restartFuture!;
  }

  Future<void> _purgeEmbeddedTorState() async {
    if (_usesExternalSocksProxy) return;

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      for (final name in const ['tor_state', 'tor_cache']) {
        final dir = Directory('${appSupportDir.path}/$name');
        if (!await dir.exists()) continue;
        await dir.delete(recursive: true);
        debugPrint('🧅 TorService: Deleted stale Arti $name directory.');
      }
    } catch (error) {
      debugPrint('🧅 TorService: Failed to purge Arti state/cache: $error');
    }
  }

  /// Polls the SOCKS port until a raw TCP connection succeeds.
  Future<void> _waitForProxyToBoot(int port, {int timeoutSeconds = 45}) async {
    debugPrint(
      '🧅 TorService: Checking if proxy is listening on $_socksHost:$port...',
    );
    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    while (stopwatch.elapsed.inSeconds < timeoutSeconds) {
      attempts++;
      try {
        final socket = await Socket.connect(
          _socksHost,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        socket.destroy();
        debugPrint(
          '🧅 TorService: Proxy is ALIVE at $port after $attempts attempts '
          '(${stopwatch.elapsedMilliseconds}ms).',
        );
        return;
      } catch (_) {
        if (attempts % 10 == 0) {
          debugPrint(
            '🧅 TorService: Still waiting for port $port... (${stopwatch.elapsed.inSeconds}s)',
          );
        }
        // Tight poll — full 1s sleep was the dominant delay when the proxy
        // was already up but we missed the first connect window.
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
    throw SocketException(
      'Tor proxy did not bootstrap within $timeoutSeconds seconds.',
    );
  }

  // ==========================================
  // WEBSOCKET & RAW TCP SOCKS5 RELAY TUNNEL
  // ==========================================

  /// Map of active relay servers, keyed by 'host:port'.
  final Map<String, ServerSocket> _relayServers = {};
  final Map<String, int> _relayPorts = {};
  final Map<String, Future<int>> _relayStartFutures = {};

  Future<void> _closeRelays() async {
    final servers = List<ServerSocket>.from(_relayServers.values);
    _relayServers.clear();
    _relayPorts.clear();
    _relayStartFutures.clear();
    for (final server in servers) {
      try {
        await server.close();
      } catch (_) {}
    }
  }

  /// Starts a local TCP server that blindly relays bytes through the Tor SOCKS5 proxy.
  /// This is used to tunnel protocols like WebSockets that don't natively support SOCKS5.
  ///
  /// [warmUpCircuit] opens a full onion circuit before binding. That is expensive
  /// (often many seconds) — cold start uses `false` and warms in the background.
  Future<int> startRelay(
    String targetHost,
    int targetPort, {
    bool warmUpCircuit = false,
  }) async {
    if (!_isRunning || !_isValidPort(_socksPort)) {
      throw SocketException(
        'Cannot start relay: Tor is not running with a valid SOCKS5 port. current=$_socksPort',
      );
    }

    final resolvedTargetPort = _normalizeTargetPort(targetPort);
    final key = '$targetHost:$resolvedTargetPort';
    if (_relayPorts.containsKey(key)) {
      if (warmUpCircuit) {
        unawaited(warmOnionCircuit(targetHost, resolvedTargetPort));
      }
      return _relayPorts[key]!;
    }
    final inFlight = _relayStartFutures[key];
    if (inFlight != null) {
      return inFlight;
    }

    final startFuture = _startRelayInternal(
      key,
      targetHost,
      resolvedTargetPort,
      warmUpCircuit: warmUpCircuit,
    );
    _relayStartFutures[key] = startFuture;
    try {
      return await startFuture;
    } finally {
      _relayStartFutures.remove(key);
    }
  }

  /// Opens and closes one onion tunnel to prime Arti circuits (non-blocking UX).
  Future<void> warmOnionCircuit(String targetHost, int targetPort) async {
    if (!_isRunning || !_isValidPort(_socksPort)) return;
    final resolved = _normalizeTargetPort(targetPort);
    try {
      final tunnel = await _openSocksTunnel(
        targetHost: targetHost,
        targetPort: resolved,
        logPrefix: 'TorService [Circuit warm]',
      );
      tunnel.close();
      debugPrint(
        '🧅 TorService: Onion circuit warm complete for $targetHost:$resolved',
      );
    } catch (e) {
      debugPrint('🧅 TorService: Circuit warm skipped/failed: $e');
    }
  }

  Future<int> _startRelayInternal(
    String key,
    String targetHost,
    int targetPort, {
    bool warmUpCircuit = false,
  }) async {
    // Cold start must not block the UI on a full onion preflight (often 10–20s).
    // Circuits are opened on the first client connection (or via [warmOnionCircuit]).
    if (warmUpCircuit) {
      final preflightTunnel = await _openSocksTunnel(
        targetHost: targetHost,
        targetPort: targetPort,
        logPrefix: 'TorService [Relay preflight]',
      );
      preflightTunnel.close();
    }

    final relayServer = await ServerSocket.bind('127.0.0.1', 0);
    final relayPort = relayServer.port;
    _relayServers[key] = relayServer;
    _relayPorts[key] = relayPort;

    relayServer.listen((clientSocket) async {
      debugPrint('🧅 Tor Relay: Received connection on 127.0.0.1:$relayPort');
      try {
        final tunnel = await _openSocksTunnel(
          targetHost: targetHost,
          targetPort: targetPort,
          logPrefix: 'TorService [Relay]',
        );

        // Bi-Directional Pipe
        final capturedTorSocket = tunnel.socket;
        clientSocket.listen(
          capturedTorSocket.add,
          onDone: () => capturedTorSocket.destroy(),
          onError: (e) {
            debugPrint(' onion TorService [Relay]: Client socket error: $e');
            capturedTorSocket.destroy();
          },
        );

        final capturedIter = tunnel.iterator;
        final capturedBuffer = List<int>.from(tunnel.pendingBytes);
        unawaited(() async {
          try {
            if (capturedBuffer.isNotEmpty) {
              clientSocket.add(Uint8List.fromList(capturedBuffer));
            }
            while (await capturedIter.moveNext()) {
              clientSocket.add(capturedIter.current);
            }
          } catch (e) {
            debugPrint(' onion TorService [Relay]: Tor stream error: $e');
          } finally {
            clientSocket.destroy();
          }
        }());
      } catch (e) {
        debugPrint(' onion TorService [Relay]: Fatal error in relay loop: $e');
        clientSocket.destroy();
      }
    });

    debugPrint(
      ' onion TorService [Relay]: Started local proxy server at 127.0.0.1:$relayPort bridging to $targetHost:$targetPort',
    );
    return relayPort;
  }

  Future<_SocksTunnel> _openSocksTunnel({
    required String targetHost,
    required int targetPort,
    required String logPrefix,
  }) async {
    int relayAttempts = 0;
    const int maxRelayAttempts = 10;
    bool restartedForOnionFailure = false;
    Socket? torSocket;
    StreamIterator<Uint8List>? torIter;
    final readBuffer = <int>[];

    Future<Uint8List> readExact(int count) async {
      while (readBuffer.length < count) {
        if (!await torIter!.moveNext()) {
          throw SocketException(
            'Stream closed prematurely: expected $count bytes, got ${readBuffer.length}',
          );
        }
        readBuffer.addAll(torIter.current);
      }
      final result = Uint8List.fromList(readBuffer.take(count).toList());
      readBuffer.removeRange(0, count);
      return result;
    }

    while (relayAttempts < maxRelayAttempts) {
      relayAttempts++;
      await torIter?.cancel();
      torSocket?.destroy();
      readBuffer.clear();
      torIter = null;
      torSocket = null;

      try {
        torSocket = await _connectToSocksProxy();
        torIter = StreamIterator<Uint8List>(torSocket);

        torSocket.add([0x05, 0x01, 0x00]);
        await torSocket.flush();
        final handshakeRes = await readExact(2);
        if (handshakeRes[0] != 0x05 || handshakeRes[1] != 0x00) {
          throw const SocketException('Tor SOCKS5 handshake failed');
        }

        final request = <int>[0x05, 0x01, 0x00, 0x03];
        final domainBytes = utf8.encode(targetHost);
        if (domainBytes.length > 255) {
          throw SocketException('SOCKS5 target host is too long: $targetHost');
        }
        request.add(domainBytes.length);
        request.addAll(domainBytes);
        request.add((targetPort >> 8) & 0xFF);
        request.add(targetPort & 0xFF);
        torSocket.add(request);
        await torSocket.flush();

        final connectRes = await readExact(4);
        if (connectRes[1] == 0x00) {
          final atyp = connectRes[3];
          if (atyp == 0x01) {
            await readExact(6);
          } else if (atyp == 0x03) {
            final len = (await readExact(1))[0];
            await readExact(len + 2);
          } else if (atyp == 0x04) {
            await readExact(18);
          } else {
            throw SocketException(
              'Tor SOCKS5 CONNECT reply has unsupported address type: $atyp',
            );
          }

          debugPrint(
              '🧅 $logPrefix: Tunnel established to $targetHost:$targetPort');
          return _SocksTunnel(
            socket: torSocket,
            iterator: torIter,
            pendingBytes: List<int>.from(readBuffer),
          );
        }

        final errorCode = connectRes[1];
        final errorMsg = _getSocksErrorMessage(errorCode);
        debugPrint(
          ' onion $logPrefix: SOCKS5 Connect failure to $targetHost:$targetPort: $errorMsg on attempt $relayAttempts/$maxRelayAttempts',
        );

        if (_shouldRestartForOnionConnectError(
              errorCode: errorCode,
              targetHost: targetHost,
            ) &&
            !restartedForOnionFailure) {
          restartedForOnionFailure = true;
          final restarted = await _restartTorProxyForOnionFailure();
          if (!restarted) {
            throw const SocketException(
              'Tor restart failed after onion connect failure',
            );
          }
          relayAttempts = 0;
          continue;
        }

        if (_isTerminalOnionDescriptorError(errorCode)) {
          relayAttempts = maxRelayAttempts;
          throw SocketException('Tor SOCKS5 to $targetHost refused: $errorMsg');
        }

        if (relayAttempts >= maxRelayAttempts) {
          throw SocketException(
            'Tor SOCKS5 to $targetHost refused after $maxRelayAttempts attempts: $errorMsg',
          );
        }
      } catch (e, stackTrace) {
        debugPrint(
          ' onion $logPrefix: SOCKS5 attempt $relayAttempts/$maxRelayAttempts exception: $e',
        );
        debugPrint(' onion $logPrefix: SOCKS5 stack: $stackTrace');
        if (relayAttempts >= maxRelayAttempts) rethrow;
      }

      await Future.delayed(_relayRetryDelay(relayAttempts));
    }

    throw const SocketException(
      'Failed to establish SOCKS5 connection after all retries',
    );
  }

  Future<Socket> _connectToSocksProxy() async {
    int sockAttempts = 0;
    while (sockAttempts < 5) {
      try {
        if (!_isValidPort(_socksPort)) {
          throw SocketException(
            'Invalid Tor SOCKS5 port before connect: $_socksPort',
          );
        }
        return Socket.connect(
          _socksHost,
          _socksPort,
          timeout: const Duration(seconds: 5),
        );
      } catch (_) {
        sockAttempts++;
        if (sockAttempts >= 5) rethrow;
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    throw const SocketException('Could not connect to Tor SOCKS5');
  }

  /// Maps SOCKS5 error codes (REP) to human readable messages.
  String _getSocksErrorMessage(int code) {
    return switch (code) {
      0x01 => 'General SOCKS server failure',
      0x02 => 'Connection not allowed by ruleset',
      0x03 => 'Network unreachable',
      0x04 => 'Host unreachable',
      0x05 => 'Connection refused',
      0x06 => 'TTL expired',
      0x07 => 'Command not supported',
      0x08 => 'Address type not supported',
      0xF0 => 'Onion Service Descriptor Not Found',
      0xF1 => 'Onion Service Descriptor Is Invalid',
      0xF2 => 'Onion Service Descriptor Is Stale',
      0xF3 => 'Onion Service Rendezvous Failed',
      0xF4 => 'Onion Service Intro Failed',
      0xF5 => 'Onion Service Unreachable',
      0xF6 => 'Missing Client Auth',
      0xF7 => 'Bad Client Auth',
      _ => 'Unknown SOCKS error',
    };
  }

  bool _isTerminalOnionDescriptorError(int code) =>
      code == 0xF1 || code == 0xF6 || code == 0xF7;

  bool _shouldRestartForOnionConnectError({
    required int errorCode,
    required String targetHost,
  }) {
    if (_usesExternalSocksProxy ||
        !targetHost.toLowerCase().endsWith('.onion')) {
      return false;
    }

    // Arti can collapse onion-service descriptor/rendezvous failures into the
    // generic SOCKS 0x01 code. Restart once so a stale client state does not
    // trap the app in a request loop after the hidden service is already alive.
    return errorCode == 0x01 ||
        errorCode == 0xF0 ||
        errorCode == 0xF2 ||
        errorCode == 0xF3 ||
        errorCode == 0xF4 ||
        errorCode == 0xF5;
  }

  Duration _relayRetryDelay(int attempt) {
    final seconds = attempt * 3;
    return Duration(seconds: seconds > 15 ? 15 : seconds);
  }
}

/// Provides access to the singleton TorService.
final torServiceProvider = Provider<TorService>((ref) {
  return TorService.instance;
});

class _SocksTunnel {
  const _SocksTunnel({
    required this.socket,
    required this.iterator,
    required this.pendingBytes,
  });

  final Socket socket;
  final StreamIterator<Uint8List> iterator;
  final List<int> pendingBytes;

  void close() {
    unawaited(iterator.cancel());
    socket.destroy();
  }
}

/// A wrapper class that allows a Socket to be treated as a broadcast stream.
class BroadcastSocket extends Stream<Uint8List> implements Socket {
  final Socket _socket;
  final Stream<Uint8List> _broadcastStream;

  BroadcastSocket(this._socket)
      : _broadcastStream = _socket.asBroadcastStream();

  BroadcastSocket.fromStream(this._socket, this._broadcastStream);

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _broadcastStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Encoding get encoding => _socket.encoding;
  @override
  set encoding(Encoding e) => _socket.encoding = e;

  @override
  void add(List<int> data) => _socket.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);
  @override
  Future addStream(Stream<List<int>> stream) => _socket.addStream(stream);
  @override
  Future close() => _socket.close();
  @override
  Future get done => _socket.done;
  @override
  Future flush() => _socket.flush();
  @override
  void write(Object? obj) => _socket.write(obj);
  @override
  void writeAll(Iterable objects, [String separator = ""]) =>
      _socket.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);
  @override
  void writeln([Object? obj = ""]) => _socket.writeln(obj);

  @override
  InternetAddress get address => _socket.address;
  @override
  void destroy() => _socket.destroy();
  @override
  int get port => _socket.port;
  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;
  @override
  int get remotePort => _socket.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);
  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);
}
