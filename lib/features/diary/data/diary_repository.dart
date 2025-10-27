import 'package:hive_flutter/hive_flutter.dart';

import '../model/diary_entry.dart';

class DiaryRepository {
  static const _boxName = 'diary_entries';
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    _inited = true;
  }

  Future<List<DiaryEntry>> load() async {
    await init();
    final box = Hive.box(_boxName);
    final raw = box.get('entries');
    if (raw == null) return [];
    final list = (raw as List).cast<Map<dynamic, dynamic>>().map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> save(List<DiaryEntry> entries) async {
    await init();
    final box = Hive.box(_boxName);
    final data = entries.map((e) => e.toJson()).toList();
    await box.put('entries', data);
  }
}
