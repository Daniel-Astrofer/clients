import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';

BitcoinAccount account(
        {String id = 'wallet-1',
        String label = 'Original',
        String status = 'ACTIVE',
        int balance = 123456,
        String? updatedAt}) =>
    BitcoinAccount.fromJson({
      'id': id,
      'type': 'INTERNAL_CARD',
      'status': status,
      'label': label,
      'balanceAvailableSats': balance,
      'updatedAt': updatedAt
    });

class _Service implements BitcoinAccountsService {
  List<BitcoinAccount> accounts = [account(updatedAt: '2026-10-09T10:00:00Z')];
  bool failMutation = false;
  bool failRead = false;
  Completer<List<BitcoinAccount>>? delayedRead;
  int mutationCalls = 0;
  bool delayUsed = false;
  Completer<BitcoinAccount>? delayedMutation;
  @override
  Future<List<BitcoinAccount>> listAccounts() async {
    if (failRead) throw const NetworkException();
    if (delayedRead != null && !delayUsed) {
      delayUsed = true;
      return delayedRead!.future;
    }
    return accounts;
  }

  @override
  Future<BitcoinAccount> renameWallet(
      {required String accountId, required String label}) async {
    mutationCalls++;
    if (failMutation) throw const NetworkException();
    if (delayedMutation != null) return delayedMutation!.future;
    return account(
        label: 'Server name', balance: 0, updatedAt: '2026-10-09T10:01:00Z');
  }

  @override
  Future<BitcoinAccount> archiveWallet(String accountId) async {
    mutationCalls++;
    if (failMutation) throw const NetworkException();
    return account(
        status: 'ARCHIVED', balance: 0, updatedAt: '2026-10-09T10:01:00Z');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Service service;
  late ProviderContainer container;
  setUp(() async {
    service = _Service();
    container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue('owner-1'),
      bitcoinAccountsServiceProvider.overrideWithValue(service),
    ]);
    container.read(bitcoinAccountsProvider);
    await container.read(bitcoinAccountsByScopeProvider(
            container.read(sessionStorageScopeProvider))
        .future);
  });
  tearDown(() => container.dispose());

  for (final archive in [false, true]) {
    test('failed mutation propagates and retains confirmed accounts: $archive',
        () async {
      service.failMutation = true;
      final notifier = container.read(bitcoinAccountsControllerProvider);
      await expectLater(
          archive
              ? notifier.archiveWallet(accountId: 'wallet-1')
              : notifier.renameWallet(accountId: 'wallet-1', label: 'New'),
          throwsA(isA<NetworkException>()));
      expect(container.read(bitcoinAccountsProvider).value?.single.label,
          'Original');
      expect(
          container
              .read(bitcoinAccountsProvider)
              .value
              ?.single
              .balanceAvailableSats,
          123456);
      expect(container.read(bitcoinAccountsSyncProvider).hasError, isTrue);
    });
    test(
        'confirmed metadata wins over old list without zeroing balances: $archive',
        () async {
      final notifier = container.read(bitcoinAccountsControllerProvider);
      if (archive) {
        await notifier.archiveWallet(accountId: 'wallet-1');
      } else {
        await notifier.renameWallet(accountId: 'wallet-1', label: 'New');
      }
      final current = container.read(bitcoinAccountsProvider).value!.single;
      expect(archive ? current.status : current.label,
          archive ? 'ARCHIVED' : 'Server name');
      expect(current.balanceAvailableSats, 123456);
    });
  }
  test('list refresh failure retains data and exposes error', () async {
    service.failRead = true;
    await container.read(bitcoinAccountsControllerProvider).refresh();
    expect(container.read(bitcoinAccountsSyncProvider).hasError, isTrue);
    expect(container.read(bitcoinAccountsProvider).value?.single.label,
        'Original');
  });
  test('old in-flight list cannot overwrite confirmed rename', () async {
    service.delayedRead = Completer<List<BitcoinAccount>>();
    final notifier = container.read(bitcoinAccountsControllerProvider);
    final refresh = notifier.refresh();
    await notifier.renameWallet(accountId: 'wallet-1', label: 'New');
    service.delayedRead!.complete(service.accounts);
    await refresh;
    expect(container.read(bitcoinAccountsProvider).value?.single.label,
        'Server name');
  });
  test('later stale snapshot preserves newer metadata but refreshes balance',
      () async {
    final notifier = container.read(bitcoinAccountsControllerProvider);
    await notifier.renameWallet(accountId: 'wallet-1', label: 'New');
    service.accounts = [
      account(balance: 234567, updatedAt: '2026-10-09T10:00:00Z')
    ];
    await notifier.refresh();
    final current = container.read(bitcoinAccountsProvider).value!.single;
    expect(current.label, 'Server name');
    expect(current.balanceAvailableSats, 234567);
  });
  test('mutation confirmation survives a same-owner list refresh', () async {
    service.delayedMutation = Completer<BitcoinAccount>();
    final mutation = container
        .read(bitcoinAccountsControllerProvider)
        .renameWallet(accountId: 'wallet-1', label: 'New');
    await container.read(bitcoinAccountsControllerProvider).refresh();
    service.delayedMutation!.complete(
        account(label: 'Confirmed', updatedAt: '2026-10-09T10:02:00Z'));
    await mutation;
    expect(container.read(bitcoinAccountsProvider).value?.single.label,
        'Confirmed');
  });
  test('late mutation from another owner cannot overwrite the new owner',
      () async {
    service.delayedMutation = Completer<BitcoinAccount>();
    final mutation = container
        .read(bitcoinAccountsControllerProvider)
        .renameWallet(accountId: 'wallet-1', label: 'Old owner');
    final rejected = expectLater(mutation, throwsA(isA<StateError>()));
    service.accounts = [account(id: 'owner-2-wallet', label: 'New owner')];
    container.updateOverrides([
      sessionStorageScopeProvider.overrideWithValue('owner-2'),
      bitcoinAccountsServiceProvider.overrideWithValue(service)
    ]);
    await container.read(bitcoinAccountsByScopeProvider(
            container.read(sessionStorageScopeProvider))
        .future);
    service.delayedMutation!.complete(account(label: 'Old owner changed'));
    await rejected;
    expect(container.read(bitcoinAccountsProvider).value?.single.id,
        'owner-2-wallet');
    expect(container.read(bitcoinAccountsProvider).hasError, isFalse);
  });
  test('failed lookup for a new owner never carries the old owner data',
      () async {
    service.failRead = true;
    container.updateOverrides([
      sessionStorageScopeProvider.overrideWithValue('owner-2'),
      bitcoinAccountsServiceProvider.overrideWithValue(service)
    ]);
    await expectLater(
        container.read(bitcoinAccountsByScopeProvider(
                container.read(sessionStorageScopeProvider))
            .future),
        throwsA(isA<NetworkException>()));
    expect(container.read(bitcoinAccountsProvider).value, isNull);
  });
  test('metadata update preserves wallet order', () async {
    service.accounts = [account(), account(id: 'wallet-2', label: 'Second')];
    await container.read(bitcoinAccountsControllerProvider).refresh();
    await container
        .read(bitcoinAccountsControllerProvider)
        .renameWallet(accountId: 'wallet-1', label: 'New');
    expect(
        container
            .read(bitcoinAccountsProvider)
            .value
            ?.map((a) => a.id)
            .toList(),
        ['wallet-1', 'wallet-2']);
  });
}
