import 'package:flutter/widgets.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';
import 'package:kerosene/features/movement/kernel/presentation/movement_entry.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';

class PaymentLinkMovementProvider implements MovementEntryProvider {
  const PaymentLinkMovementProvider();

  @override
  List<MovementEntry> entriesFor(BuildContext context, Wallet? wallet, MovementCapability caps) {
    return [
      MovementEntry(
        id: 'payment_link',
        title: context.tr.receiveMethodPaymentLinkTitle,
        subtitle: context.tr.receiveMethodPaymentLinkSubtitle,
        icon: KeroseneIcons.onchain,
        routeName: 'receive_payment_link',
        extraArgs: ReceiveAmountMethod.paymentLink,
      ),
    ];
  }
}
