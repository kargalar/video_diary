import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/settings.dart';

class SettingsRepository {
  static const _key = 'settings';

  Future<SettingsModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return SettingsModel.def;
    return SettingsModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(SettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
