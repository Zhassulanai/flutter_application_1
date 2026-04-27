import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'familychat_service',
        channelName: 'FamilyChat сервис',
        channelDescription: 'Держит соединение активным',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: true,
      ),
    );
  }

  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'FamilyChat активен',
      notificationText: 'Получение сообщений...',
      callback: _serviceCallback,
    );
  }

  static Future<void> stop() => FlutterForegroundTask.stopService();
}

@pragma('vm:entry-point')
void _serviceCallback() {
  FlutterForegroundTask.setTaskHandler(_ServiceHandler());
}

class _ServiceHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
