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
  static const String _channelId = 'daily_video_diary_v2';
  static const String _channelName = 'Daily Reminder';

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const windows = WindowsInitializationSettings(appName: 'Video Diary', appUserModelId: 'com.kargalar.video_diary', guid: 'e0e87d60-3b0f-4ff2-8d85-0a9c8ebdb5a9');
    const initSettings = InitializationSettings(android: android, iOS: iOS, windows: windows);
    await _plugin.initialize(initSettings);

    // Ensure Android channel exists (some OEMs/Release builds can be picky)
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(_channelId, _channelName, description: 'Daily reminder to record your video diary', importance: Importance.max));

    // timezone init
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Fallback
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _initialized = true;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(_channelId, _channelName, channelDescription: 'Daily reminder to record your video diary', importance: Importance.max, priority: Priority.high),
      iOS: const DarwinNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _ensureAndroidPermissions();
    // Prefer inexact scheduling to avoid exact alarm restrictions; still repeats daily at selected time
    await _plugin.cancel(1001);
    await _plugin.zonedSchedule(1001, 'Video Diary', 'Don\'t forget to record today\'s video', scheduled, details, androidScheduleMode: AndroidScheduleMode.inexact, matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<Map<String, dynamic>> diagnostics() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    bool? notifEnabled;
    try {
      notifEnabled = await android?.areNotificationsEnabled();
    } catch (_) {}
    return {'initialized': _initialized, 'timezone': tz.local.name, 'androidNotificationsEnabled': notifEnabled, 'channelId': _channelId};
  }

  Future<void> _ensureAndroidPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
    } catch (_) {}
    // Do not prompt for exact alarm; we schedule in inexact mode by default
  }
}
