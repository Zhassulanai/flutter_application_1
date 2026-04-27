import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';
import 'services/identity_service.dart';
import 'data/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.open();
  await IdentityService.instance.isOnboarded();
  await NotificationService.instance.init();
  await ForegroundService.init();
  runApp(const App());
}
