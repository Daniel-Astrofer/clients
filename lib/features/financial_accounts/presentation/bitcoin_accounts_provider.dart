import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/features/financial_accounts/application/providers/bitcoin_accounts_service_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
export 'package:kerosene/features/financial_accounts/application/providers/bitcoin_accounts_service_provider.dart';

const int maxActiveColdWallets = 2;

/// Read failures remain visible without replacing confirmed wallet data.
class BitcoinAccountsSyncNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    ref.watch(sessionStorageScopeProvider);
    return const AsyncData(null);
  }

  void publish(AsyncValue<void> status) => state = status;
}

final bitcoinAccountsSyncProvider =
    NotifierProvider<BitcoinAccountsSyncNotifier, AsyncValue<void>>(
        BitcoinAccountsSyncNotifier.new);

class BitcoinAccountsNotifier extends AsyncNotifier<List<BitcoinAccount>> {
  BitcoinAccountsNotifier([this.boundScope]);
  final String? boundScope;
  late BitcoinAccountsService _service;
  List<BitcoinAccount> _lastAccounts = const [];
  String? _scope;
  bool _hasSnapshot = false;
  int _generation = 0;
  int _loadGeneration = 0;
  int _revision = 0;
  Future<void>? _refreshFuture;

  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(sessionStorageScopeProvider) == _scope;

  @override
  Future<List<BitcoinAccount>> build() async {
    final sessionScope = boundScope;
    final loadGeneration = ++_loadGeneration;
    _refreshFuture = null;
    if (_scope != sessionScope) {
      _lastAccounts = const [];
      _hasSnapshot = false;
      _scope = sessionScope;
      _generation++;
      _revision++;
    }
    final service = _service = ref.watch(bitcoinAccountsServiceProvider);
    if (sessionScope == null) return const [];
    final generation = _generation;
    final revision = _revision;
    final List<BitcoinAccount> accounts;
    try {
      accounts = await service.listAccounts();
    } catch (error, stackTrace) {
      if (_current(generation) && loadGeneration == _loadGeneration) {
        _sync(AsyncError(error, stackTrace));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!_current(generation)) throw StateError('Wallet session changed.');
    if (revision == _revision && loadGeneration == _loadGeneration) {
      _lastAccounts = _mergeSnapshot(accounts);
      _hasSnapshot = true;
      _sync(const AsyncData(null));
    }
    return _lastAccounts;
  }

  Future<void> refresh() {
    final running = _refreshFuture;
    if (running != null) return running;
    final generation = _generation;
    final revision = _revision;
    final future = _refresh(_service, generation, revision, ++_loadGeneration);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
  }

  Future<void> _refresh(BitcoinAccountsService service, int generation,
      int revision, int loadGeneration) async {
    if (!_hasSnapshot) state = const AsyncLoading();
    _sync(const AsyncLoading());
    try {
      final accounts = await service.listAccounts();
      if (!_current(generation) || loadGeneration != _loadGeneration) return;
      if (revision != _revision) {
        _sync(const AsyncData(null));
        return;
      }
      _lastAccounts = _mergeSnapshot(accounts);
      _hasSnapshot = true;
      state = AsyncData(_lastAccounts);
      _sync(const AsyncData(null));
    } catch (error, stackTrace) {
      if (_current(generation) &&
          revision == _revision &&
          loadGeneration == _loadGeneration) {
        _failed(error, stackTrace);
      }
    }
  }

  void _sync(AsyncValue<void> status) =>
      ref.read(bitcoinAccountsSyncProvider.notifier).publish(status);

  void _failed(Object error, StackTrace stackTrace) {
    _sync(AsyncError(error, stackTrace));
    state =
        _hasSnapshot ? AsyncData(_lastAccounts) : AsyncError(error, stackTrace);
  }

  /// Mutation DTOs have metadata, not balances. Preserve the last known ledger
  /// values until a dashboard response supplies a new financial snapshot.
  BitcoinAccount _metadata(
          BitcoinAccount balanceSnapshot, BitcoinAccount metadata) =>
      BitcoinAccount.fromJson({
        ...balanceSnapshot.toJson(),
        'label': metadata.label,
        'status': metadata.status,
        'updatedAt': metadata.updatedAt?.toUtc().toIso8601String() ??
            balanceSnapshot.updatedAt?.toUtc().toIso8601String(),
      });

  List<BitcoinAccount> _mergeSnapshot(List<BitcoinAccount> incoming) => [
        for (final account in incoming) _preferMetadata(account),
      ];

  BitcoinAccount _preferMetadata(BitcoinAccount incoming) {
    final previous =
        _lastAccounts.where((a) => a.id == incoming.id).firstOrNull;
    if (previous?.updatedAt != null &&
        incoming.updatedAt != null &&
        previous!.updatedAt!.isAfter(incoming.updatedAt!)) {
      return _metadata(incoming, previous);
    }
    return incoming;
  }

  BitcoinAccount _confirmed(BitcoinAccount result, int generation,
      {String? accountId}) {
    if (!_current(generation)) throw StateError('Wallet session changed.');
    if (result.id.trim().isEmpty ||
        (accountId != null && result.id != accountId)) {
      throw const ServerException(
          message: 'Wallet response does not match the request.',
          errorCode: 'ERR_WALLET_RESPONSE_MISMATCH');
    }
    final previous = _lastAccounts.where((a) => a.id == result.id).firstOrNull;
    final newerKnown = previous?.updatedAt != null &&
        result.updatedAt != null &&
        previous!.updatedAt!.isAfter(result.updatedAt!);
    final confirmed = previous == null
        ? result
        : newerKnown
            ? previous
            : _metadata(previous, result);
    _revision++;
    _lastAccounts = [
      for (final account in _lastAccounts)
        if (account.id == result.id) confirmed else account,
      if (previous == null) confirmed,
    ];
    _hasSnapshot = true;
    state = AsyncData(_lastAccounts);
    return confirmed;
  }

  Future<BitcoinAccount> createInternalCard({
    required String label,
  }) async {
    return createWallet(
      label: label,
      custody: BitcoinAccountCustody.internal,
    );
  }

  Future<BitcoinAccount> createWallet({
    required String label,
    required BitcoinAccountCustody custody,
  }) async {
    final generation = _generation;
    final service = _service;
    try {
      _ensureCustodyAvailable(custody);
      final created = await service.createWallet(
        label: label,
        custody: custody,
      );
      _confirmed(created, generation);
      await refresh();
      if (!_current(generation)) throw StateError('Wallet session changed.');
      return created;
    } catch (error, stackTrace) {
      if (_current(generation)) _failed(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<BitcoinAccount> importColdWallet({
    required String label,
    required String xpub,
    required String fingerprint,
    required String derivationPath,
    required String scriptPolicy,
  }) async {
    final generation = _generation;
    final service = _service;
    try {
      _ensureCustodyAvailable(BitcoinAccountCustody.watchOnly);
      final imported = await service.importColdWallet(
        label: label,
        xpub: xpub,
        fingerprint: fingerprint,
        derivationPath: derivationPath,
        scriptPolicy: scriptPolicy,
      );
      _confirmed(imported, generation);
      await refresh();
      if (!_current(generation)) throw StateError('Wallet session changed.');
      return imported;
    } catch (error, stackTrace) {
      if (_current(generation)) _failed(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ReceivingRequestView> rotateReceiveAddress(
      {required String accountId}) async {
    final generation = _generation;
    final service = _service;
    final rotated = await service.rotateReceiveAddress(accountId);
    if (!_current(generation)) throw StateError('Wallet session changed.');
    _revision++;
    ref.invalidate(bitcoinAccountReceiveRequestsProvider(accountId));
    await refresh();
    if (!_current(generation)) throw StateError('Wallet session changed.');
    return rotated;
  }

  Future<BitcoinAccount> renameWallet(
      {required String accountId, required String label}) async {
    final generation = _generation;
    final service = _service;
    try {
      final result =
          await service.renameWallet(accountId: accountId, label: label);
      return _confirmed(result, generation, accountId: accountId);
    } catch (error, stackTrace) {
      if (_current(generation)) _failed(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<BitcoinAccount> archiveWallet({required String accountId}) async {
    final generation = _generation;
    final service = _service;
    try {
      final result = await service.archiveWallet(accountId);
      return _confirmed(result, generation, accountId: accountId);
    } catch (error, stackTrace) {
      if (_current(generation)) _failed(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _ensureCustodyAvailable(BitcoinAccountCustody custody) {
    final accounts = _lastAccounts;
    final activeWallets = accounts
        .where((account) =>
            account.isActive && _accountMatchesCustody(account, custody))
        .length;
    final maxWallets =
        custody == BitcoinAccountCustody.watchOnly ? maxActiveColdWallets : 1;
    if (activeWallets >= maxWallets) {
      throw ValidationException(
        message: custody == BitcoinAccountCustody.watchOnly
            ? 'Voce pode criar no maximo duas carteiras frias.'
            : 'Ja existe uma carteira ativa para este metodo de custodia.',
        statusCode: 409,
        errorCode: 'ERR_WALLET_CUSTODY_ALREADY_EXISTS',
      );
    }
  }

  bool _accountMatchesCustody(
    BitcoinAccount account,
    BitcoinAccountCustody custody,
  ) {
    return switch (custody) {
      BitcoinAccountCustody.internal =>
        account.isInternal && !account.isCustodialOnchain,
      BitcoinAccountCustody.custodialOnchain => account.isCustodialOnchain,
      BitcoinAccountCustody.watchOnly => account.isWatchOnly,
    };
  }
}

final bitcoinAccountsByScopeProvider = AsyncNotifierProvider.autoDispose
    .family<BitcoinAccountsNotifier, List<BitcoinAccount>, String?>(
  BitcoinAccountsNotifier.new,
  retry: (_, __) => null,
);

/// A synchronous selector never carries another account's previous AsyncValue.
final bitcoinAccountsProvider =
    Provider<AsyncValue<List<BitcoinAccount>>>((ref) {
  return ref.watch(
      bitcoinAccountsByScopeProvider(ref.watch(sessionStorageScopeProvider)));
});

final bitcoinAccountsControllerProvider =
    Provider<BitcoinAccountsNotifier>((ref) {
  return ref.watch(
      bitcoinAccountsByScopeProvider(ref.watch(sessionStorageScopeProvider))
          .notifier);
});

final bitcoinAccountReceiveRequestsProvider =
    FutureProvider.family<List<ReceivingRequestView>, String>(
        (ref, accountId) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <ReceivingRequestView>[];
  }

  final service = ref.watch(bitcoinAccountsServiceProvider);
  return service.listReceiveRequestsForAccount(accountId);
});

final bitcoinColdWalletUtxosProvider =
    FutureProvider.family<List<ColdWalletUtxoView>, String>(
        (ref, coldWalletId) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <ColdWalletUtxoView>[];
  }

  final service = ref.watch(bitcoinAccountsServiceProvider);
  return service.listColdWalletUtxos(coldWalletId);
});

final bitcoinColdWalletPsbtsProvider =
    FutureProvider.family<List<PsbtWorkflowView>, String>(
        (ref, coldWalletId) async {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <PsbtWorkflowView>[];
  }

  final service = ref.watch(bitcoinAccountsServiceProvider);
  return service.listColdWalletPsbt(coldWalletId);
});

final kfeTaxEventsProvider = FutureProvider<List<TaxEventView>>((ref) {
  final sessionScope = ref.watch(sessionStorageScopeProvider);
  if (sessionScope == null) {
    return const <TaxEventView>[];
  }

  final service = ref.watch(bitcoinAccountsServiceProvider);
  return service.listTaxEvents();
});
