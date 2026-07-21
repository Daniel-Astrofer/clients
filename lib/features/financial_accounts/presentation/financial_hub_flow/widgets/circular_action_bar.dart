import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'circular_action_button.dart';

/// Row of 4 circular action buttons replacing horizontal expansion tiles:
/// 1. Receber (Receive Address, QR, Rotation)
/// 2. Enviar (Send/Transfer Flow)
/// 3. Gerenciar (Rename, Status, Lock/Archive)
/// 4. Detalhes (Public Material, Fingerprint, Derivation, IDs)
class CircularActionBar extends StatelessWidget {
  final VoidCallback onReceiveTap;
  final VoidCallback onSendTap;
  final VoidCallback onManageTap;
  final VoidCallback onDetailsTap;

  const CircularActionBar({
    super.key,
    required this.onReceiveTap,
    required this.onSendTap,
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
            label: 'Receber',
            onTap: onReceiveTap,
          ),
          CircularActionButton(
            icon: KeroseneIcons.send,
            label: 'Enviar',
            onTap: onSendTap,
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
