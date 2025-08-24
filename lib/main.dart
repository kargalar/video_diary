import 'package:flutter/material.dart';

import 'core/app.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().init();
  runApp(const VideoDiaryApp());
}
