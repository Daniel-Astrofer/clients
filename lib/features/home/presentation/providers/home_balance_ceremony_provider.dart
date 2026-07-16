import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped: one short balance spin ceremony per app session on home.
///
/// Not persisted — survives only while the provider container lives.
class HomeBalanceCeremonyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns true only the first time this is claimed in the session.
  bool claim() {
    if (state) return false;
    state = true;
    return true;
  }

  bool get alreadyPlayed => state;
}

final homeBalanceCeremonyPlayedProvider =
    NotifierProvider<HomeBalanceCeremonyNotifier, bool>(
  HomeBalanceCeremonyNotifier.new,
);

/// Absolute BTC delta required before digit-roll odometer runs on updates.
const double kHomeBalanceLargeDeltaBtc = 0.000001; // 100 sats
