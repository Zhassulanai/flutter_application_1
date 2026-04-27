import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String preview,
    required String chatId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Сообщения',
      channelDescription: 'Входящие сообщения FamilyChat',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      chatId.hashCode,
      senderName,
      preview,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
