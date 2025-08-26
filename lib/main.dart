import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure notifications/timezone are fully initialized before the app starts
  await NotificationService().init();
  // Lock the entire app to portrait by default; specific pages can override temporarily
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const VideoDiaryApp());
}
