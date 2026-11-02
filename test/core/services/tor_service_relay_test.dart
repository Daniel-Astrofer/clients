import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/tor_service_io.dart';

void main() {
  test('onion retry preserves the SOCKS proxy and another active tunnel',
      () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    final attempts = <String, int>{};
    final errors = <Object>[];
    final handlers = <Future<void>>[];
    final service = TorService.forTesting(socksPort: proxy.port);

    Future<void> handle(Socket socket) async {
      sockets.add(socket);
      final input = StreamIterator<Uint8List>(socket);
      final buffer = <int>[];
      Future<List<int>> read(int count) async {
        while (buffer.length < count) {
          if (!await input.moveNext()) throw StateError('Unexpected EOF');
          buffer.addAll(input.current);
        }
        final result = buffer.take(count).toList();
        buffer.removeRange(0, count);
        return result;
      }

      try {
        expect(await read(3), [5, 1, 0]);
        socket.add([5, 0]);
        final request = await read(5);
        expect(request.take(4), [5, 1, 0, 3]);
        final host = utf8.decode(await read(request[4]));
        await read(2);
        attempts.update(host, (count) => count + 1, ifAbsent: () => 1);
        if (host == 'login.onion' && attempts[host] == 1) {
          socket.add([5, 1, 0, 1, 0, 0, 0, 0, 0, 0]);
          await socket.flush();
          return;
        }
        socket.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 80]);
        await socket.flush();
        if (buffer.isNotEmpty) socket.add(buffer);
        while (await input.moveNext()) {
          socket.add(input.current);
          await socket.flush();
        }
      } catch (error) {
        errors.add(error);
      } finally {
        socket.destroy();
        await input.cancel();
      }
    }

    final listener = proxy.listen((socket) => handlers.add(handle(socket)));
    addTearDown(() async {
      for (final socket in sockets) {
        socket.destroy();
      }
      await service.stop();
      await listener.cancel();
      await proxy.close();
      await Future.wait(handlers);
    });

    final stablePort = await service.startRelay('stable.onion', 80);
    final stable = await Socket.connect('127.0.0.1', stablePort);
    sockets.add(stable);
    final stableInput = StreamIterator<Uint8List>(stable);
    addTearDown(stableInput.cancel);
    stable.add([11]);
    expect(await stableInput.moveNext().timeout(const Duration(seconds: 10)),
        isTrue);
    expect(stableInput.current, [11]);

    final loginPort = await service.startRelay('login.onion', 80);
    final login = await Socket.connect('127.0.0.1', loginPort);
    sockets.add(login);
    final loginInput = StreamIterator<Uint8List>(login);
    addTearDown(loginInput.cancel);
    login.add([22]);
    expect(await loginInput.moveNext().timeout(const Duration(seconds: 10)),
        isTrue);
    expect(loginInput.current, [22]);
    expect(attempts['login.onion'], 2);
    expect(service.socksPort, proxy.port);
    expect(service.isRunning, isTrue);

    stable.add([33]);
    expect(await stableInput.moveNext().timeout(const Duration(seconds: 10)),
        isTrue);
    expect(stableInput.current, [33]);
    expect(errors, isEmpty);
  });
}
