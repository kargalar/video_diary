import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DailyRatingRepository {
  static const _key = 'daily_ratings'; // json map: { 'yyyy-MM-dd': int }

  Future<Map<String, int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final map = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    return map;
  }

  Future<void> save(Map<String, int> ratings) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(ratings);
    await prefs.setString(_key, raw);
  }
}
