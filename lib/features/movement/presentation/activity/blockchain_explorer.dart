import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:url_launcher/url_launcher.dart';

typedef BlockchainExplorerLauncher = Future<bool> Function(Uri uri);

final blockchainExplorerLauncherProvider = Provider<BlockchainExplorerLauncher>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Public explorer links require a known network; a txid does not encode it.
class BlockchainExplorer {
  const BlockchainExplorer._();

  static bool hasValidTxid(String? value) =>
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch((value ?? '').trim());

  static String? _path(String? networkHint) =>
      switch ((networkHint ?? '').trim().toLowerCase()) {
        'mainnet' || 'bitcoin' => '',
        'testnet' || 'testnet3' => '/testnet',
        'testnet4' => '/testnet4',
        'signet' => '/signet',
        _ => null,
      };

  /// Mainnet and regtest Bech32 prefixes are distinct. Test prefixes alone
  /// cannot distinguish testnet3, testnet4, signet and legacy regtest addresses.
  static String? networkFromAddresses(Iterable<String> addresses) {
    final networks = addresses
        .where(looksLikeBitcoinAddress)
        .map(inferBitcoinNetworkFromAddress)
        .toSet();
    if (networks.length != 1) return null;
    return switch (networks.single) {
      BitcoinNetworkKind.mainnet => 'mainnet',
      BitcoinNetworkKind.regtest => 'regtest',
      _ => null,
    };
  }

  static Uri? txUri(String? blockchainTxid, {String? networkHint}) {
    if (!hasValidTxid(blockchainTxid)) return null;
    final path = _path(networkHint);
    if (path == null) return null;
    return Uri.parse(
        'https://mempool.space$path/tx/${blockchainTxid!.trim().toLowerCase()}');
  }

  static Uri? addressUri(String? address, {String? networkHint}) {
    final addr = normalizeBitcoinAddressForDisplay(address ?? '');
    if (!looksLikeBitcoinAddress(addr)) return null;
    final hint = networkHint ?? networkFromAddresses([addr]);
    final path = _path(hint);
    if (path == null) return null;
    final detected = inferBitcoinNetworkFromAddress(addr);
    if (detected == BitcoinNetworkKind.regtest ||
        (detected == BitcoinNetworkKind.mainnet) != (path.isEmpty)) {
      return null;
    }
    return Uri.parse('https://mempool.space$path/address/$addr');
  }

  static Future<bool> openTx(String? blockchainTxid,
      {String? networkHint, BlockchainExplorerLauncher? launcher}) async {
    final uri = txUri(blockchainTxid, networkHint: networkHint);
    if (uri == null) return false;
    try {
      return await (launcher ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      return false;
    }
  }
}
