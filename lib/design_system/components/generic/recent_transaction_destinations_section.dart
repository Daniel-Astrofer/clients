import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';

Color _recentDestinationPanelColor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;
Color _recentDestinationBorderColor(BuildContext context) =>
    Theme.of(context).dividerColor;
Color _recentDestinationTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;
Color _recentDestinationMutedTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;
Color _recentDestinationFaintTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

class RecentTransactionDestinationsSection extends StatelessWidget {
  final List<RecentTransactionDestination> destinations;
  final ValueChanged<RecentTransactionDestination> onSelect;
  final ValueChanged<RecentTransactionDestination>? onRemove;
  final VoidCallback? onClearAll;
  final String title;
  final int maxItems;
  final double radius;

  const RecentTransactionDestinationsSection({
    super.key,
    required this.destinations,
    required this.onSelect,
    this.onRemove,
    this.onClearAll,
    required this.title,
    this.maxItems = 4,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleDestinations =
        destinations.take(maxItems).toList(growable: false);
    final clearAllLabel = context.tr.recentDestinationClearAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _recentDestinationFaintTextColor(context),
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (onClearAll != null)
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(KeroseneIcons.trash, size: 14),
                label: Text(clearAllLabel),
                style: TextButton.styleFrom(
                  foregroundColor: _recentDestinationMutedTextColor(context),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: _recentDestinationPanelColor(context),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _recentDestinationBorderColor(context)),
          ),
          child: Column(
            children: [
              for (var index = 0;
                  index < visibleDestinations.length;
                  index++) ...[
                _RecentDestinationRow(
                  destination: visibleDestinations[index],
                  onTap: () => onSelect(visibleDestinations[index]),
                  onRemove: onRemove == null
                      ? null
                      : () => onRemove!(visibleDestinations[index]),
                  radius: radius,
                ),
                if (index != visibleDestinations.length - 1)
                  Divider(
                    height: 1,
                    color: _recentDestinationBorderColor(context),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentDestinationRow extends StatelessWidget {
  final RecentTransactionDestination destination;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final double radius;

  const _RecentDestinationRow({
    required this.destination,
    required this.onTap,
    this.onRemove,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final label = destination.label?.trim();
    final hasLabel = label != null && label.isNotEmpty;
    final title = hasLabel ? label : destination.address;
    final subtitle =
        hasLabel ? destination.address : _kindLabel(context, destination.kind);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(destination.kind),
                      size: 17,
                      color: _recentDestinationMutedTextColor(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _recentDestinationTextColor(context),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTypography.financialFontFamily,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      _recentDestinationMutedTextColor(context),
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (onRemove == null)
              Icon(
                KeroseneIcons.next,
                size: 16,
                color: _recentDestinationFaintTextColor(context),
              )
            else
              IconButton(
                onPressed: onRemove,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(KeroseneIcons.trash, size: 16),
                color: _recentDestinationFaintTextColor(context),
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RecentTransactionDestinationKind kind) {
    return switch (kind) {
      RecentTransactionDestinationKind.internal => KeroseneIcons.address,
      RecentTransactionDestinationKind.onChain => KeroseneIcons.onchain,
      RecentTransactionDestinationKind.lightning => KeroseneIcons.lightning,
    };
  }

  String _kindLabel(
    BuildContext context,
    RecentTransactionDestinationKind kind,
  ) {
    return switch (kind) {
      RecentTransactionDestinationKind.internal =>
        context.tr.recentDestinationInternal,
      RecentTransactionDestinationKind.onChain =>
        context.tr.recentDestinationOnChain,
      RecentTransactionDestinationKind.lightning =>
        context.tr.recentDestinationLightning,
    };
  }
}
