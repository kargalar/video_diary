import 'package:hive_flutter/hive_flutter.dart';

class DayData {
  final int? rating; // daily average rating 1..5
  final List<String> moods; // allow multiple moods per day
  final bool inStreak; // whether the day is part of current streak snapshot
  DayData({this.rating, List<String>? moods, required this.inStreak}) : moods = moods ?? const [];

  DayData copyWith({int? rating, List<String>? moods, bool? inStreak}) {
    return DayData(rating: rating ?? this.rating, moods: moods ?? this.moods, inStreak: inStreak ?? this.inStreak);
  }

  Map<String, dynamic> toJson() => {'rating': rating, 'moods': moods, 'inStreak': inStreak};

  static DayData fromJson(Map json) {
    // Backward-compat: legacy 'mood' string
    final legacyMood = json['mood'] as String?;
    final moods = (json['moods'] as List?)?.cast<String>() ?? (legacyMood != null ? [legacyMood] : <String>[]);
    return DayData(rating: (json['rating'] as int?), moods: moods, inStreak: (json['inStreak'] as bool?) ?? false);
  }
}

class DayDataRepository {
  static const _boxName = 'day_data';
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    _inited = true;
  }

  String keyFor(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DayData?> getDay(DateTime day) async {
    final box = Hive.box(_boxName);
    final k = keyFor(day);
    final raw = box.get(k);
    if (raw is Map) return DayData.fromJson(raw);
    return null;
  }

  Future<void> putDay(DateTime day, DayData data) async {
    final box = Hive.box(_boxName);
    await box.put(keyFor(day), data.toJson());
  }

  Future<void> clearRating(DateTime day) async {
    final existing = await getDay(day);
    final data = (existing ?? DayData(inStreak: false)).copyWith(rating: null);
    await putDay(day, data);
  }

  Future<void> setRating(DateTime day, int rating) async {
    final existing = await getDay(day);
    final data = (existing ?? DayData(inStreak: false)).copyWith(rating: rating);
    await putDay(day, data);
  }

  Future<void> addMoods(DateTime day, List<String> moods) async {
    final existing = await getDay(day);
    final current = existing ?? DayData(inStreak: false);
    final set = {...current.moods, ...moods};
    final data = current.copyWith(moods: set.toList());
    await putDay(day, data);
  }

  Future<void> setMoods(DateTime day, List<String> moods) async {
    final existing = await getDay(day);
    final data = (existing ?? DayData(inStreak: false)).copyWith(moods: List<String>.from(moods));
    await putDay(day, data);
  }

  Future<void> clearMoods(DateTime day) async {
    final existing = await getDay(day);
    final data = (existing ?? DayData(inStreak: false)).copyWith(moods: <String>[]);
    await putDay(day, data);
  }

  Future<Map<String, DayData>> getAll() async {
    final box = Hive.box(_boxName);
    final map = <String, DayData>{};
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map) map[k.toString()] = DayData.fromJson(v);
    }
    return map;
  }

  Future<void> clearAll() async {
    final box = Hive.box(_boxName);
    await box.clear();
  }
}
