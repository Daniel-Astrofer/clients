import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/features/home/scene/renderer/home_scene_host.dart';

/// Region A — home communication theater.
///
/// Thin shell: all rendering is Scene-Driven via [HomeSceneHost].
/// Screens never parse JSON; only the scene repository / mapper do.
class HomeCommunicationStage extends ConsumerWidget {
  final String userName;
  final GlobalKey? notificationButtonKey;

  const HomeCommunicationStage({
    super.key,
    required this.userName,
    this.notificationButtonKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSceneHost(
      userName: userName,
      notificationButtonKey: notificationButtonKey,
    );
  }
}
