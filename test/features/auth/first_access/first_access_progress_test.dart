import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/features/auth/presentation/first_access/first_access_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  test('new users without accounts choose, existing accounts keep Home', () {
    expect(
        FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: false), isTrue);
    expect(
        FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: true), isFalse);
  });
  test('pending stages resume even when an account already exists', () async {
    for (final write in [
      FirstAccessProgress.markPending,
      FirstAccessProgress.creating,
      FirstAccessProgress.ready
    ]) {
      await write(prefs, 'a');
      expect(FirstAccessProgress.hasCheckpoint(prefs, 'a'), isTrue);
      expect(
          FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: true), isTrue);
    }
  });
  test(
      'explore completion is isolated by owner and persists a navigation marker only',
      () async {
    await FirstAccessProgress.complete(prefs, 'a');
    expect(
        FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: false), isFalse);
    expect(
        FirstAccessProgress.shouldShow(prefs, 'b', hasWallets: false), isTrue);
    expect(prefs.getKeys(), {'first_access.v1.a'});
    expect(prefs.getString('first_access.v1.a'), 'complete');
  });
  test('migration preserves previous account setup dismissal', () async {
    await prefs.setBool('home.wallet_setup_redirect_seen.a', true);
    expect(
        FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: false), isFalse);
    await FirstAccessProgress.markPending(prefs, 'a');
    expect(
        FirstAccessProgress.shouldShow(prefs, 'a', hasWallets: false), isTrue);
  });
  test('empty owners cannot persist checkpoints', () async {
    await expectLater(
        FirstAccessProgress.complete(prefs, ' '), throwsStateError);
    expect(prefs.getKeys(), isEmpty);
  });
}
