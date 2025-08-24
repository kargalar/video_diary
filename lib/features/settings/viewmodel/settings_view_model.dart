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
    await _requestNotificationPermission();
    await _notifier.init();
    await _notifier.scheduleDaily(hour, minute);
    notifyListeners();
  }

  Future<void> _requestNotificationPermission() async {
    final p = await Permission.notification.request();
    if (!p.isGranted && !p.isLimited) {
      // No-op; user can enable later
    }
  }

  Future<void> setDarkMode(bool value) async {
    _state = _state.copyWith(darkMode: value);
    await _repo.save(_state);
    notifyListeners();
  }

  Future<void> setLandscape(bool value) async {
    _state = _state.copyWith(landscape: value);
    await _repo.save(_state);
    notifyListeners();
  }
}
