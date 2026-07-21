import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';

class NfcMovementProvider implements MovementEntryProvider {
  const NfcMovementProvider();

  @override
  List<MovementEntry> entriesFor(
      BuildContext context, Wallet? wallet, MovementCapability caps) {
    final isInternal =
        wallet == null || (!wallet.isColdWallet && !wallet.isCustodialOnchain);
    if (!isInternal || !caps.nfcAvailable) {
      return [];
    }

    return [
      MovementEntry(
        id: 'nfc',
        title: context.tr.receiveMethodNfcTitle,
        subtitle: context.tr.receiveMethodNfcSubtitle,
        icon: KeroseneIcons.nfc,
        routeName: 'receive_nfc',
        extraArgs: ReceiveAmountMethod.nfc,
      ),
    ];
  }
}
