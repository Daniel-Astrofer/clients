import 'package:equatable/equatable.dart';

/// Describes an address issued for an on-chain deposit and its transfer state.
///
/// The value combines wallet/provider routing metadata with confirmation data
/// so receive flows can display progress without owning deposit lifecycle rules.
class OnchainAddressAllocation extends Equatable {
  /// Display name of the wallet that owns the allocated address.
  final String walletName;

  /// Bitcoin address presented to the payer.
  final String onchainAddress;

  /// Expected deposit amount in BTC; zero means no amount was specified.
  final double expectedAmountBtc;

  /// Network identifier used to interpret the address and transaction.
  final String network;

  /// External provider that issued or monitors the address.
  final String provider;

  /// Provider-side wallet reference, when this wallet is externally managed.
  final String externalWalletReference;

  /// Custody mode label used to distinguish self-custody from hosted wallets.
  final String walletMode;

  /// Identifier of the associated transfer, if the service has created one.
  final String transferId;

  /// Current service transfer status, such as `PENDING`.
  final String transferStatus;

  /// Confirmations observed for the associated blockchain transaction.
  final int confirmations;

  /// Confirmation threshold required before the deposit is treated as final.
  final int requiredConfirmations;

  /// Transaction identifier observed on the blockchain, if available.
  final String blockchainTxid;

  /// Creates an immutable address allocation from normalized service values.
  const OnchainAddressAllocation({
    required this.walletName,
    required this.onchainAddress,
    required this.expectedAmountBtc,
    required this.network,
    required this.provider,
    required this.externalWalletReference,
    required this.walletMode,
    required this.transferId,
    required this.transferStatus,
    required this.confirmations,
    required this.requiredConfirmations,
    required this.blockchainTxid,
  });

  /// Whether a nonblank service transfer identifier is available.
  bool get hasTransferId => transferId.trim().isNotEmpty;

  /// Whether the wallet mode is explicitly marked as self-custodial.
  bool get isSelfCustody => walletMode.trim().toUpperCase() == 'SELF_CUSTODY';

  /// Builds an allocation from the API shape, applying display-safe defaults.
  ///
  /// Missing text fields become empty strings, numeric fields become zero,
  /// wallet mode defaults to Kerosene custody, and the confirmation threshold
  /// defaults to three. This factory does not validate the address or network.
  factory OnchainAddressAllocation.fromJson(Map<String, dynamic> json) {
    return OnchainAddressAllocation(
      walletName: json['walletName']?.toString() ?? '',
      onchainAddress: json['onchainAddress']?.toString() ?? '',
      expectedAmountBtc: (json['expectedAmountBtc'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      externalWalletReference:
          json['externalWalletReference']?.toString() ?? '',
      walletMode: json['walletMode']?.toString() ?? 'KEROSENE',
      transferId: json['transferId']?.toString() ?? '',
      transferStatus: json['transferStatus']?.toString() ?? 'PENDING',
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      requiredConfirmations:
          (json['requiredConfirmations'] as num?)?.toInt() ?? 3,
      blockchainTxid: json['blockchainTxid']?.toString() ?? '',
    );
  }

  @override

  /// Fields that define equality for an address allocation.
  List<Object?> get props => [
        walletName,
        onchainAddress,
        expectedAmountBtc,
        network,
        provider,
        externalWalletReference,
        walletMode,
        transferId,
        transferStatus,
        confirmations,
        requiredConfirmations,
        blockchainTxid,
      ];
}
