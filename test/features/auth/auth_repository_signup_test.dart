import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:kerosene/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:kerosene/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  for (final failToken in [false, true]) {
    test(
        'invalid session cleanup attempts both keys and propagates failure: token=$failToken',
        () async {
      final events = <String>[];
      final local = _RecordingAuthLocalDataSource(events)
        ..failTokenRemoval = failToken
        ..failUserRemoval = !failToken;
      final repository = AuthRepositoryImpl(
        remoteDataSource: _RecordingAuthRemoteDataSource(events),
        localDataSource: local,
      );
      await expectLater(repository.clearInvalidSession(), throwsStateError);
      expect(events, ['removeToken', 'removeUser']);
    });
  }
  test('invalid session cleanup confirms both removals', () async {
    final events = <String>[];
    final repository = AuthRepositoryImpl(
      remoteDataSource: _RecordingAuthRemoteDataSource(events),
      localDataSource: _RecordingAuthLocalDataSource(events),
    );
    await repository.clearInvalidSession();
    expect(events, ['removeToken', 'removeUser']);
  });
  test('signup clears stale local auth and TOTP material before remote signup',
      () async {
    final events = <String>[];
    final localDataSource = _RecordingAuthLocalDataSource(events);
    final remoteDataSource = _RecordingAuthRemoteDataSource(events);
    final repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );

    final result = await repository.signup(
      username: 'new_user',
      passphrase: 'StrongPassphrase123!',
    );

    expect(result.isRight(), isTrue);
    expect(events, [
      'removeToken',
      'removeUser',
      'removeTotpSecret',
      'removeBackupCodes',
      'remoteSignup:new_user',
      'saveBackupCodes:1',
    ]);
  });
}

class _RecordingAuthLocalDataSource implements AuthLocalDataSource {
  final List<String> events;
  bool failTokenRemoval = false;
  bool failUserRemoval = false;

  _RecordingAuthLocalDataSource(this.events);

  @override
  Future<void> removeToken() async {
    events.add('removeToken');
    if (failTokenRemoval) throw StateError('Storage fixture failure');
  }

  @override
  Future<void> removeUser() async {
    events.add('removeUser');
    if (failUserRemoval) throw StateError('Storage fixture failure');
  }

  @override
  Future<void> removeTotpSecret() async {
    events.add('removeTotpSecret');
  }

  @override
  Future<void> removeBackupCodes() async {
    events.add('removeBackupCodes');
  }

  @override
  Future<void> saveBackupCodes(List<String> codes) async {
    events.add('saveBackupCodes:${codes.length}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAuthRemoteDataSource implements AuthRemoteDataSource {
  final List<String> events;

  _RecordingAuthRemoteDataSource(this.events);

  @override
  Future<SignupInitResult> signup({
    required String username,
    required String passphrase,
    required String accountSecurity,
    int? shamirTotalShares,
    int? shamirThreshold,
    int? multisigThreshold,
  }) async {
    events.add('remoteSignup:$username');
    return const SignupInitResult(
      sessionId: 'signup-session',
      totpSecret: 'JBSWY3DPEHPK3PXP',
      qrCodeUri:
          'otpauth://totp/Kerosene:new_user?secret=JBSWY3DPEHPK3PXP&issuer=Kerosene',
      backupCodes: ['12345678'],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
