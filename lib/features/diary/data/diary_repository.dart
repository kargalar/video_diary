import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/diary_entry.dart';

class DiaryRepository {
  static const _key = 'diary_entries';

  Future<List<DiaryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(DiaryEntry.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> save(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
