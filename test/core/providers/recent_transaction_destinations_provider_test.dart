import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/app/providers/session_storage_scope_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sharedPreferences;
  late ProviderContainer container;

  Future<ProviderContainer> createContainer() async {
    sharedPreferences = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionStorageScopeProvider.overrideWithValue('test-session'),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    FlutterSecureStorage.setMockInitialValues({});
    container = await createContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('stores only usernames and ignores address / invoice destinations',
      () async {
    final notifier = container.read(
      recentTransactionDestinationsProvider.notifier,
    );

    await notifier.saveDestination(
      address: 'bc1qvaultdestino',
      kind: RecentTransactionDestinationKind.onChain,
      label: 'Cold wallet',
    );
    await notifier.saveDestination(
      address: 'alice_user',
      kind: RecentTransactionDestinationKind.internal,
      label: 'Alice',
    );
    await notifier.saveDestination(
      address: 'lnbc1invoice',
      kind: RecentTransactionDestinationKind.lightning,
    );
    await notifier.saveDestination(
      address: 'alice_user',
      kind: RecentTransactionDestinationKind.internal,
      label: 'Alice Updated',
    );

    final destinations = container.read(recentTransactionDestinationsProvider);

    expect(destinations, hasLength(1));
    expect(destinations.single.address, 'alice_user');
    expect(destinations.single.kind, RecentTransactionDestinationKind.internal);
    expect(destinations.single.label, 'Alice Updated');
  });

  test('persists username destinations and enforces the storage limit',
      () async {
    final notifier = container.read(
      recentTransactionDestinationsProvider.notifier,
    );

    for (var index = 0; index < 14; index++) {
      await notifier.saveDestination(
        address: 'wallet_$index',
        kind: RecentTransactionDestinationKind.internal,
      );
    }

    final current = container.read(recentTransactionDestinationsProvider);
    expect(current, hasLength(12));
    expect(current.first.address, 'wallet_13');
    expect(current.last.address, 'wallet_2');

    final reloaded = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionStorageScopeProvider.overrideWithValue('test-session'),
      ],
    );
    addTearDown(reloaded.dispose);

    reloaded.read(recentTransactionDestinationsProvider);
    await Future<void>.delayed(Duration.zero);

    final persisted = reloaded.read(recentTransactionDestinationsProvider);
    expect(persisted, hasLength(12));
    expect(persisted.first.address, 'wallet_13');
    expect(persisted.last.address, 'wallet_2');
  });

  test('removes a saved username destination', () async {
    final notifier = container.read(
      recentTransactionDestinationsProvider.notifier,
    );

    await notifier.saveDestination(
      address: 'alice_user',
      kind: RecentTransactionDestinationKind.internal,
      label: 'Alice',
    );
    await notifier.saveDestination(
      address: 'bob_user',
      kind: RecentTransactionDestinationKind.internal,
      label: 'Bob',
    );

    await notifier.removeDestination(
      address: 'alice_user',
      kind: RecentTransactionDestinationKind.internal,
    );

    final destinations = container.read(recentTransactionDestinationsProvider);

    expect(destinations, hasLength(1));
    expect(destinations.single.address, 'bob_user');
  });

  test('rejects uuid and hash-looking internal addresses', () async {
    final notifier = container.read(
      recentTransactionDestinationsProvider.notifier,
    );

    await notifier.saveDestination(
      address: '550e8400-e29b-41d4-a716-446655440000',
      kind: RecentTransactionDestinationKind.internal,
    );
    await notifier.saveDestination(
      address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      kind: RecentTransactionDestinationKind.internal,
    );

    expect(container.read(recentTransactionDestinationsProvider), isEmpty);
  });
}
