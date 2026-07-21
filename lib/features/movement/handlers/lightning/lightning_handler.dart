import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';

class LightningMovementProvider implements MovementEntryProvider {
  const LightningMovementProvider();

  @override
  List<MovementEntry> entriesFor(
      BuildContext context, Wallet? wallet, MovementCapability caps) {
    if (wallet != null && (wallet.isColdWallet || wallet.isCustodialOnchain)) {
      return []; // Only internal wallet can do Lightning
    }

    return [
      MovementEntry(
        id: 'lightning',
        title: ReceiveMoneyCopy.lightningTitle(context),
        subtitle: ReceiveMoneyCopy.lightningSubtitle(context),
        icon: KeroseneIcons.bolt,
        routeName: 'receive_lightning',
        extraArgs: ReceiveAmountMethod.lightning,
      ),
    ];
  }
}
