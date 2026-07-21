import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/data/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';

/// Stable capability snapshot for hub + send routing.
///
/// Intentionally product-agnostic: no foreshadowed feature flags. Send adds
/// receiver rails / eligible source wallets from the backend capabilities API.
class MovementCapability {
  final Wallet? wallet;
  final bool nfcAvailable;

  /// Source custody of [wallet] when known (send flow).
  final SourceCustody? sourceCustody;

  /// Live receiving capabilities of the destination (username resolve).
  final KfeReceivingCapabilities? receiverCapabilities;

  /// Eligible sender wallet ids from the backend (authoritative filter).
  final Set<String> eligibleSourceWalletIds;

  /// Platform expected on-chain network (mainnet / testnet).
  final BitcoinNetworkKind expectedNetwork;

  /// Optional user-selected rail when destination offers more than one.
  final PaymentRail? userSelectedRail;

  const MovementCapability({
    this.wallet,
    this.nfcAvailable = false,
    this.sourceCustody,
    this.receiverCapabilities,
    this.eligibleSourceWalletIds = const {},
    this.expectedNetwork = BitcoinNetworkKind.unknown,
    this.userSelectedRail,
  });

  MovementCapability copyWith({
    Wallet? wallet,
    bool? nfcAvailable,
    SourceCustody? sourceCustody,
    KfeReceivingCapabilities? receiverCapabilities,
    Set<String>? eligibleSourceWalletIds,
    BitcoinNetworkKind? expectedNetwork,
    PaymentRail? userSelectedRail,
  }) {
    return MovementCapability(
      wallet: wallet ?? this.wallet,
      nfcAvailable: nfcAvailable ?? this.nfcAvailable,
      sourceCustody: sourceCustody ?? this.sourceCustody,
      receiverCapabilities: receiverCapabilities ?? this.receiverCapabilities,
      eligibleSourceWalletIds:
          eligibleSourceWalletIds ?? this.eligibleSourceWalletIds,
      expectedNetwork: expectedNetwork ?? this.expectedNetwork,
      userSelectedRail: userSelectedRail ?? this.userSelectedRail,
    );
  }
}
