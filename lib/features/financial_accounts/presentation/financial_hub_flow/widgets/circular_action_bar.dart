import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'circular_action_button.dart';

/// Row of circular action buttons for the financial accounts hub:
/// 1. Adicionar carteira (creation flow)
/// 2. Gerenciar
/// 3. Detalhes
class CircularActionBar extends StatelessWidget {
  final VoidCallback onAddWalletTap;
  final VoidCallback onManageTap;
  final VoidCallback onDetailsTap;

  const CircularActionBar({
    super.key,
    required this.onAddWalletTap,
    required this.onManageTap,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CircularActionButton(
            icon: KeroseneIcons.plus,
            label: 'Adicionar\ncarteira',
            onTap: onAddWalletTap,
          ),
          CircularActionButton(
            icon: KeroseneIcons.settings,
            label: 'Gerenciar',
            onTap: onManageTap,
          ),
          CircularActionButton(
            icon: KeroseneIcons.creditCard,
            label: 'Detalhes',
            onTap: onDetailsTap,
          ),
        ],
      ),
    );
  }
}
