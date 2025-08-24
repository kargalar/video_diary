import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: iOS);
    await _plugin.initialize(initSettings);

    // timezone init
    try {
      tz.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _initialized = true;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    final details = NotificationDetails(
      android: const AndroidNotificationDetails('daily_video_diary', 'Daily Reminder', channelDescription: 'Daily reminder to record your video diary', importance: Importance.max, priority: Priority.high),
      iOS: const DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _ensureAndroidPermissions();
    try {
      await _plugin.cancel(1001);
      await _plugin.zonedSchedule(
        1001,
        'Video Günlüğü',
        'Günün videosunu çekmeyi unutma',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Fallback to inexact scheduling if exact alarm permission is restricted
      await _plugin.cancel(1001);
      await _plugin.zonedSchedule(
        1001,
        'Video Günlüğü',
        'Günün videosunu çekmeyi unutma',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> _ensureAndroidPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
    } catch (_) {}
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }
}
