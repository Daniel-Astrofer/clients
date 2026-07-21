import 'package:flutter/widgets.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/capability/movement_capability.dart';

class MovementEntry {
  final String id;
  final String title;
  final String subtitle;
  final IconData? icon;
  final String routeName;
  final Object? extraArgs;
  final VoidCallback? onSelect;
  final bool isRecommended;
  final bool requiresWallet;

  const MovementEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    this.icon,
    this.routeName = '',
    this.extraArgs,
    this.onSelect,
    this.isRecommended = false,
    this.requiresWallet = true,
  });
}

abstract class MovementEntryProvider {
  List<MovementEntry> entriesFor(BuildContext context, Wallet? wallet, MovementCapability caps);
}
