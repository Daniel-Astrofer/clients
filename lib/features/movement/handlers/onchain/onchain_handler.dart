import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';

class OnchainMovementProvider implements MovementEntryProvider {
  const OnchainMovementProvider();

  @override
  List<MovementEntry> entriesFor(BuildContext context, Wallet? wallet, MovementCapability caps) {
    return [
      MovementEntry(
        id: 'qrcode',
        title: context.tr.receiveMethodQrTitle,
        subtitle: context.tr.receiveMethodQrSubtitle,
        icon: KeroseneIcons.qr,
        routeName: 'receive_qrcode',
        extraArgs: ReceiveAmountMethod.qrCode,
      ),
    ];
  }
}
