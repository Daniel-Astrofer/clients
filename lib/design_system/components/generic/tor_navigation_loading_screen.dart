import 'package:flutter/material.dart';
import 'package:kerosene/features/presentation/widgets/tor_loading_dots.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Full-screen Tor dots loader with a **fixed** visual center.
///
/// Used for the single post-PIN bootstrap surface (and the PIN verify handoff).
/// [TorLoadingDotsKeys.primary] keeps the animation continuous when the parent
/// swaps from the PIN gate to [HomeLoadingScreen].
class TorNavigationLoadingScreen extends StatelessWidget {
  /// When true (default), reuses the primary dots key for PIN→home continuity.
  final bool usePrimaryKey;

  const TorNavigationLoadingScreen({
    super.key,
    this.usePrimaryKey = true,
  });

  @override
  Widget build(BuildContext context) {
    // Strip bottom viewInsets (keyboard) so Center stays geometrically stable.
    final media = MediaQuery.of(context);
    final stableMedia =
        media.removeViewInsets(removeBottom: true).removeViewPadding(
              removeBottom: true,
            );

    return MediaQuery(
      data: stableMedia,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: SizedBox.expand(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: TorLoadingDots(
                key: usePrimaryKey ? TorLoadingDotsKeys.primary : null,
                // Small travel + scale/alpha pulse (see TorLoadingDots).
                travel: 5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
