import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().init();
  // Lock the entire app to portrait by default; specific pages can override temporarily
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const VideoDiaryApp());
}
