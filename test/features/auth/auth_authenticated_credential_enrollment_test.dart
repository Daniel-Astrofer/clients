import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/core/services/passkey_service.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/auth/domain/repositories/auth_repository.dart';

final alice = User(id: '1', username: 'alice', createdAt: DateTime(2020));
final bob = User(id: '2', username: 'bob', createdAt: DateTime(2020));

class _Repository implements AuthRepository {
  Completer<void>? startGate, finishGate, remoteGate;
  Failure? finishFailure, remoteFailure;
  User returnedUser = alice;
  int starts = 0, finishes = 0, remoteReads = 0;
  String? path;
  Map<String, dynamic>? submitted;
  Future<Either<Failure, T>> _start<T>(String kind, T value) async {
    starts++;
    path = kind;
    await startGate?.future;
    return Right(value);
  }

  @override
  Future<Either<Failure, String>> passkeyRegisterStart(String username) =>
      _start('legacy', '00' * 32);
  @override
  Future<Either<Failure, Map<String, dynamic>>> deviceKeyRegisterStart() =>
      _start('canonical', {
        'challengeId': 'PUBLIC-CHALLENGE',
        'challenge': 'PUBLIC-CHALLENGE',
        'onionServiceId': 'fixture.onion',
        'algorithm': 'Ed25519',
        'canonicalization': 'KEROSENE_JSON_V1'
      });
  Future<Either<Failure, void>> _finish(Map<String, dynamic> credential) async {
    finishes++;
    submitted = Map.of(credential);
    await finishGate?.future;
    return finishFailure == null ? const Right(null) : Left(finishFailure!);
  }

  @override
  Future<Either<Failure, void>> passkeyRegisterFinish(
          Map<String, dynamic> credential) =>
      _finish(credential);
  @override
  Future<Either<Failure, void>> deviceKeyRegisterFinish(
          Map<String, dynamic> credential) =>
      _finish(credential);
  @override
  Future<Either<Failure, User>> getCurrentUser(
      {bool forceRemote = false}) async {
    expect(forceRemote, isTrue);
    remoteReads++;
    await remoteGate?.future;
    return remoteFailure == null ? Right(returnedUser) : Left(remoteFailure!);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Device extends DeviceKeyService {
  int registrations = 0, activations = 0;
  Completer<void>? registerGate;
  bool missingId = false;
  @override
  Future<Map<String, dynamic>> register(
      {required DeviceKeyChallenge challenge,
      required String username,
      required String sessionId,
      bool appPinConfigured = false,
      bool activateImmediately = true,
      bool requireStrictUserPresence = false}) async {
    expect(username, 'alice');
    expect(activateImmediately, isFalse);
    registrations++;
    await registerGate?.future;
    return {
      'publicKey': 'PUBLIC-KEY',
      if (!missingId) 'credentialId': 'prepared-id'
    };
  }

  @override
  Future<void> activateRegistration(
      {required String username, required String credentialId}) async {
    expect(username, 'alice');
    expect(credentialId, 'prepared-id');
    activations++;
  }
}

class _Passkey extends PasskeyService {
  int registrations = 0, bindings = 0, rebinds = 0;
  Completer<void>? registerGate;
  @override
  Future<Map<String, dynamic>> register(
      {required String challengeHex,
      required String username,
      bool confirmUnlinkDevice = false,
      bool appPinConfigured = false}) async {
    registrations++;
    await registerGate?.future;
    return {'publicKey': 'PUBLIC-KEY', 'credentialId': 'prepared-id'};
  }

  @override
  Future<void> prepareDeviceRebind({required String newUsername}) async {
    rebinds++;
  }

  @override
  Future<void> markDeviceBound({required String username}) async {
    bindings++;
  }
}

class _Controller extends AuthController {
  final _Repository repository;
  final _Device device;
  final _Passkey passkey;
  _Controller(this.repository, this.device, this.passkey);
  @override
  AuthState build() {
    authRepository = repository;
    return AuthAuthenticated(alice);
  }

  @override
  DeviceKeyService get deviceKeyService => device;
  @override
  PasskeyService get passkeyService => passkey;
  void switchSession(AuthState next) => state = next;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    group('authenticated registration on $platform', () {
      late _Repository repo;
      late _Device device;
      late _Passkey passkey;
      late ProviderContainer container;
      late _Controller controller;
      setUp(() {
        debugDefaultTargetPlatformOverride = platform;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (call) async => call.method == 'getAvailableBiometrics'
                ? ['fingerprint']
                : true);
        repo = _Repository();
        device = _Device();
        passkey = _Passkey();
        container = ProviderContainer(overrides: [
          authControllerProvider
              .overrideWith(() => _Controller(repo, device, passkey))
        ]);
        controller =
            container.read(authControllerProvider.notifier) as _Controller;
      });
      tearDown(() {
        container.dispose();
        debugDefaultTargetPlatformOverride = null;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null);
      });
      test('duplicate attempts share one native and server operation',
          () async {
        repo.finishGate = Completer<void>();
        final first = controller.registerPasskey();
        final second = controller.registerPasskey();
        expect(identical(first, second), isTrue);
        await flush();
        expect(repo.path,
            platform == TargetPlatform.android ? 'canonical' : 'legacy');
        expect(repo.starts, 1);
        expect(repo.finishes, 1);
        expect(device.activations, 0);
        repo.finishGate!.complete();
        expect((await first).isSuccess, isTrue);
        expect(passkey.bindings, 1);
        expect(device.activations, platform == TargetPlatform.android ? 1 : 0);
      });
      test(
          'logout while challenge loads never opens native enrollment or restores login',
          () async {
        repo.startGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        controller.switchSession(const AuthUnauthenticated());
        repo.startGate!.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(device.registrations + passkey.registrations, 0);
        expect(repo.finishes, 0);
        expect(
            container.read(authControllerProvider), isA<AuthUnauthenticated>());
      });
      test(
          'account change while native enrollment waits never submits with the new session',
          () async {
        final gate = Completer<void>();
        device.registerGate = gate;
        passkey.registerGate = gate;
        final pending = controller.registerPasskey();
        await flush();
        controller.switchSession(AuthAuthenticated(bob));
        gate.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(repo.finishes, 0);
        expect(device.activations, 0);
        expect(
            (container.read(authControllerProvider) as AuthAuthenticated)
                .user
                .id,
            '2');
      });
      test(
          'late finish acknowledgement cannot activate a key or bind a different account',
          () async {
        repo.finishGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        controller.switchSession(AuthAuthenticated(bob));
        repo.finishGate!.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(device.activations, 0);
        expect(passkey.bindings, 0);
        expect(repo.remoteReads, 0);
        expect(
            (container.read(authControllerProvider) as AuthAuthenticated)
                .user
                .id,
            '2');
      });
      test(
          'late user refresh never resurrects the previous authenticated state',
          () async {
        repo.remoteGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        expect(repo.remoteReads, 1);
        controller.switchSession(const AuthUnauthenticated());
        repo.remoteGate!.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(
            container.read(authControllerProvider), isA<AuthUnauthenticated>());
      });
      test('a different user returned by refresh is rejected', () async {
        repo.returnedUser = bob;
        expect((await controller.registerPasskey()).status,
            PasskeyRegisterStatus.notAuthenticated);
        expect(
            (container.read(authControllerProvider) as AuthAuthenticated)
                .user
                .id,
            '1');
      });
      test('profile lookup failure retains only the same acknowledged session',
          () async {
        repo.remoteFailure = const NetworkFailure();
        final owner = container.read(authControllerProvider);
        expect((await controller.registerPasskey()).isSuccess, isTrue);
        expect(
            identical(container.read(authControllerProvider), owner), isTrue);
      });
      test('server conflict cannot activate prepared material', () async {
        repo.finishFailure = const AuthFailure(
            message: 'fixture conflict', errorCode: 'AUTH_024');
        expect((await controller.registerPasskey()).isDeviceConflict, isTrue);
        expect(device.activations, 0);
        expect(passkey.bindings, 0);
      });
      test('a new session for the same user does not own the old request',
          () async {
        repo.finishGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        controller.switchSession(AuthAuthenticated(alice));
        repo.finishGate!.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(passkey.bindings, 0);
      });
      test('local rebind cleanup waits for the server acknowledgement',
          () async {
        repo.finishGate = Completer<void>();
        final pending = controller.registerPasskey(confirmUnlinkDevice: true);
        await flush();
        expect(passkey.rebinds, 0);
        expect(device.activations, 0);
        if (platform == TargetPlatform.android) {
          expect(repo.submitted!['confirmUnlinkDevice'], isTrue);
          expect(repo.submitted!['confirm_unlink_device'], isTrue);
        }
        repo.finishGate!.complete();
        expect((await pending).isSuccess, isTrue);
        expect(passkey.rebinds, platform == TargetPlatform.linux ? 1 : 0);
      });
      test('a rejected enrollment never activates or marks a credential bound',
          () async {
        repo.finishFailure = const NetworkFailure();
        final owner = container.read(authControllerProvider);
        expect((await controller.registerPasskey()).isSuccess, isFalse);
        expect(device.activations, 0);
        expect(passkey.bindings, 0);
        expect(
            identical(container.read(authControllerProvider), owner), isTrue);
      });
      test(
          'disposing the owner while a request waits cannot restore authentication',
          () async {
        repo.finishGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        container.dispose();
        repo.finishGate!.complete();
        expect((await pending).status, PasskeyRegisterStatus.notAuthenticated);
        expect(device.activations, 0);
        expect(passkey.bindings, 0);
      });
      if (platform == TargetPlatform.android) {
        test('a prepared key without its id is never submitted or activated',
            () async {
          device.missingId = true;
          expect((await controller.registerPasskey()).isSuccess, isFalse);
          expect(repo.finishes, 0);
          expect(device.activations, 0);
        });
      }
      test(
          'a second account cannot start enrollment while the previous native operation is pending',
          () async {
        repo.finishGate = Completer<void>();
        final pending = controller.registerPasskey();
        await flush();
        controller.switchSession(AuthAuthenticated(bob));
        final next = await controller.registerPasskey();
        expect(next.errorCode, 'ERR_AUTH_DEVICE_KEY_REGISTRATION_BUSY');
        expect(repo.starts, 1);
        repo.finishGate!.complete();
        await pending;
      });
    });
  }
}
