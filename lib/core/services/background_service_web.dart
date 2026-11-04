import 'background_service_status.dart';
export 'background_service_status.dart';

Future<void> initializeBackgroundService() async {}

Future<void> startBackgroundService() async {}

Future<void> stopBackgroundService() async {}

Future<void> requestBackgroundNotificationPoll() async {}

Future<void> notifyBackgroundAppLifecycle({required bool foreground}) async {}

Future<void> markBackgroundNotificationsSeen(Iterable<String> ids) async {}

bool get backgroundServiceSupported => false;
Future<BackgroundServiceStatus> readBackgroundServiceStatus() async =>
    const BackgroundServiceStatus(running: false);
