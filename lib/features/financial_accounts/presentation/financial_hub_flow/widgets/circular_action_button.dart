import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/design_system/components/buttons/bouncing_button.dart';
import '../theme/financial_hub_tokens.dart';

/// Circular action button widget following the design system.
/// Features a circular icon container with tap animation and label below.
class CircularActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const CircularActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 58.0,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? FinancialHubTokens.circularButtonBg;
    final fgColor = iconColor ?? FinancialHubTokens.circularButtonIcon;

    return BouncingButton(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: fgColor,
              size: size * 0.42,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FinancialHubTokens.buttonLabel(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }
}
