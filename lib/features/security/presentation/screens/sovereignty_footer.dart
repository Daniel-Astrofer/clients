import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

typedef SovereigntyFooterCopy = String Function(
    {required String pt, required String en, required String es});

Widget buildSovereigntyFooter({
  required BuildContext context,
  required SovereigntyFooterCopy copy,
}) {
  return Center(
    child: Text(
      copy(
        pt: 'Painel atualizado automaticamente. Puxe a tela para forçar uma nova leitura.',
        en: 'Panel refreshes automatically. Pull the screen to force a new readout.',
        es: 'El panel se actualiza automáticamente. Desliza para forzar una nueva lectura.',
      ),
      textAlign: TextAlign.center,
      style: AppTypography.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50),
        height: 1.5,
      ),
    ),
  );
}
