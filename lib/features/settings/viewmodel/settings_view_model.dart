import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/notification_service.dart';
import '../../../services/storage_service.dart';
import '../data/settings_repository.dart';
import '../model/settings.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repo = SettingsRepository();
  final StorageService _storage = StorageService();
  final NotificationService _notifier = NotificationService();

  SettingsModel _state = SettingsModel.def;
  SettingsModel get state => _state;

  Future<void> load() async {
    _state = await _repo.load();
    notifyListeners();
  }

  Future<void> pickDirectory() async {
    final selected = await _storage.pickDirectory(initialDirectory: state.storageDirectory);
    _state = _state.copyWith(storageDirectory: selected);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<void> setReminder(int hour, int minute) async {
    _state = _state.copyWith(reminderHour: hour, reminderMinute: minute);
    await _repo.save(_state);

    // Only schedule if enabled
    if (_state.reminderEnabled) {
      await _requestNotificationPermission();
      await _notifier.init();
      await _notifier.scheduleDaily(hour, minute);
    }
    notifyListeners();
  }

  Future<bool> setReminderEnabled(bool enabled) async {
    // Check permission when enabling
    if (enabled) {
      final hasPermission = await _requestNotificationPermission();
      if (!hasPermission) {
        // Permission denied, open settings
        await openAppSettings();
        return false;
      }

      // Schedule notification
      await _notifier.init();
      await _notifier.scheduleDaily(_state.reminderHour, _state.reminderMinute);
    } else {
      // Disable notifications
      await _notifier.cancelAll();
    }

    _state = _state.copyWith(reminderEnabled: enabled);
    await _repo.save(_state);
    notifyListeners();
    return true;
  }

  Future<bool> _requestNotificationPermission() async {
    final p = await Permission.notification.request();
    return p.isGranted || p.isLimited;
  }

  Future<void> setLandscape(bool value) async {
    _state = _state.copyWith(landscape: value);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<bool> clearAllVideos(Future<bool> Function() clearAllCallback) async {
    return await clearAllCallback();
  }
}
