import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a public explorer for a Bitcoin txid / address when possible.
///
/// Network is inferred from address/txid context; defaults to testnet-friendly
/// mempool.space paths used by local/regtest-adjacent builds.
class BlockchainExplorer {
  const BlockchainExplorer._();

  static Uri? txUri(String? blockchainTxid, {String? networkHint}) {
    final txid = (blockchainTxid ?? '').trim().toLowerCase();
    if (txid.isEmpty || txid.length < 16) return null;
    final net = (networkHint ?? '').toLowerCase();
    if (net.contains('main')) {
      return Uri.parse('https://mempool.space/tx/$txid');
    }
    if (net.contains('signet')) {
      return Uri.parse('https://mempool.space/signet/tx/$txid');
    }
    // Default: testnet (local/dev often uses testnet-style explorers).
    return Uri.parse('https://mempool.space/testnet/tx/$txid');
  }

  static Uri? addressUri(String? address, {String? networkHint}) {
    final addr = (address ?? '').trim();
    if (addr.isEmpty || addr.length < 14) return null;
    final lower = addr.toLowerCase();
    // regtest has no public explorer.
    if (lower.startsWith('bcrt1')) return null;
    final net = (networkHint ?? '').toLowerCase();
    if (net.contains('main') || lower.startsWith('bc1')) {
      return Uri.parse('https://mempool.space/address/$addr');
    }
    if (net.contains('signet')) {
      return Uri.parse('https://mempool.space/signet/address/$addr');
    }
    // tb1… and most non-mainnet → testnet explorer.
    return Uri.parse('https://mempool.space/testnet/address/$addr');
  }

  static Future<bool> openTx(String? blockchainTxid, {String? networkHint}) async {
    final uri = txUri(blockchainTxid, networkHint: networkHint);
    if (uri == null) return false;
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BlockchainExplorer.openTx failed: $e');
      }
      return false;
    }
  }
}
