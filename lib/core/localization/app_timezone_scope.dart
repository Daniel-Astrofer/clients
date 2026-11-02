import 'package:flutter/widgets.dart';

import 'app_timezone.dart';

/// Reactive presentation timezone, separate from API/domain timestamps.
/// A null ID follows the current device clock, including OS offset changes.
class AppTimezoneScope extends InheritedWidget {
  final String? timeZoneId;
  final bool followDevice;

  const AppTimezoneScope({
    super.key,
    required this.timeZoneId,
    this.followDevice = false,
    required super.child,
  });

  static String? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppTimezoneScope>();
    return scope?.followDevice == true ? null : scope?.timeZoneId;
  }

  static DateTime convert(BuildContext context, DateTime instant) =>
      AppTimezone.convert(instant, timeZoneId: of(context));

  @override
  bool updateShouldNotify(AppTimezoneScope oldWidget) =>
      oldWidget.timeZoneId != timeZoneId ||
      oldWidget.followDevice != followDevice;
}
