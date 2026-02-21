import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../services/notification_service.dart';
import '../../settings/data/settings_repository.dart';
import '../data/diary_repository.dart';
import '../data/day_data_repository.dart';
import '../model/diary_entry.dart';
import '../model/mood.dart';
import 'diary_state.dart';

class DiaryViewModel extends ChangeNotifier {
  final DiaryRepository _repo;
  final SettingsRepository _settingsRepo;
  final DayDataRepository _dayRepo;
  final NotificationService _notificationService;

  DiaryState _state = const DiaryState();
  DiaryState get state => _state;

  // For backward compatibility during refactoring
  List<DiaryEntry> get entries => _state.entries;
  Map<String, int> get dailyRatings => _state.dailyRatings;
  Map<String, List<String>> get dailyMoods => _state.dailyMoods;
  int get currentStreak => _state.currentStreak;
  int get maxStreak => _state.maxStreak;
  DateTime? get lastRecordedDay => _state.lastRecordedDay;

  DiaryViewModel(this._repo, this._settingsRepo, this._dayRepo, this._notificationService);

  void _updateState(DiaryState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> load() async {
    Future.microtask(() => _updateState(_state.copyWith(status: DiaryStatus.loading)));
    try {
      final entries = await _repo.load();
      final all = await _dayRepo.getAll();

      final dailyRatings = {
        for (final e in all.entries)
          if (e.value.rating != null) e.key: e.value.rating!,
      };
      final dailyMoods = {for (final e in all.entries) e.key: e.value.moods};

      _updateState(_state.copyWith(status: DiaryStatus.success, entries: entries, dailyRatings: dailyRatings, dailyMoods: dailyMoods));

      _recomputeStreak();

      // Reschedule notifications on every app launch
      final settings = await _settingsRepo.load();
      await _notificationService.rescheduleIfNeeded(settings.reminderEnabled, settings.reminderHour, settings.reminderMinute);
    } catch (e) {
      _updateState(_state.copyWith(status: DiaryStatus.error, errorMessage: e.toString()));
    }
  }

  void addEntry(DiaryEntry entry) {
    final newEntries = [entry, ..._state.entries];
    _updateState(_state.copyWith(entries: newEntries));
    _repo.save(newEntries);
    _recomputeStreak();
  }

  // Per-entry rating and daily average helpers
  Future<void> setRatingForEntry(String path, int rating) async {
    final idx = _state.entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _state.entries[idx];
    final newEntries = List<DiaryEntry>.from(_state.entries);
    newEntries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, description: old.description, rating: rating.clamp(1, 5), moods: old.moods);

    _updateState(_state.copyWith(entries: newEntries));
    await _repo.save(newEntries);
    await _recomputeDailyAverageForDay(old.date);
  }

  Future<void> setDescriptionForEntry(String path, String description) async {
    final idx = _state.entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _state.entries[idx];
    final newEntries = List<DiaryEntry>.from(_state.entries);
    newEntries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, description: description.isEmpty ? null : description, rating: old.rating, moods: old.moods);

    _updateState(_state.copyWith(entries: newEntries));
    await _repo.save(newEntries);
  }

  Future<void> setMoodsForEntry(String path, List<Mood> moods) async {
    final idx = _state.entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _state.entries[idx];
    final newEntries = List<DiaryEntry>.from(_state.entries);
    newEntries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, description: old.description, rating: old.rating, moods: moods);

    _updateState(_state.copyWith(entries: newEntries));
    await _repo.save(newEntries);
    await _recomputeDailyMoodsForDay(old.date);
  }

  Future<void> setDateForEntry(String path, DateTime newDate) async {
    final idx = _state.entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _state.entries[idx];
    final newEntries = List<DiaryEntry>.from(_state.entries);
    newEntries[idx] = DiaryEntry(path: old.path, date: newDate, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, description: old.description, rating: old.rating, moods: old.moods);

    _updateState(_state.copyWith(entries: newEntries));
    await _repo.save(newEntries);
  }

  int? getDailyAverageRating(DateTime day) => _state.dailyRatings[_keyFor(day)];

  Future<void> clearRatingsForDay(DateTime day) async {
    final key = _keyFor(day);
    await _dayRepo.clearRating(day);

    final newEntries = List<DiaryEntry>.from(_state.entries);
    for (var i = 0; i < newEntries.length; i++) {
      final e = newEntries[i];
      if (_keyFor(e.date) == key && e.rating != null) {
        newEntries[i] = DiaryEntry(path: e.path, date: e.date, thumbnailPath: e.thumbnailPath, durationMs: e.durationMs, fileBytes: e.fileBytes, title: e.title, description: e.description, rating: null);
      }
    }

    final newRatings = Map<String, int>.from(_state.dailyRatings)..remove(key);

    _updateState(_state.copyWith(entries: newEntries, dailyRatings: newRatings));
    await _repo.save(newEntries);
  }

  Future<void> setMoodsForDay(DateTime day, List<String> moods) async {
    await _dayRepo.setMoods(day, moods);
    final newMoods = Map<String, List<String>>.from(_state.dailyMoods)..[_keyFor(day)] = List<String>.from(moods);
    _updateState(_state.copyWith(dailyMoods: newMoods));
  }

  List<String> getMoodsForDay(DateTime day) => _state.dailyMoods[_keyFor(day)] ?? const [];

  Future<void> addMoodsForDay(DateTime day, List<String> moods) async {
    if (moods.isEmpty) return;
    await _dayRepo.addMoods(day, moods);
    final key = _keyFor(day);
    final merged = {...(_state.dailyMoods[key] ?? const <String>[]), ...moods}.toList();
    final newMoods = Map<String, List<String>>.from(_state.dailyMoods)..[key] = merged;
    _updateState(_state.copyWith(dailyMoods: newMoods));
  }

  Future<void> renameLastRecordingWithTitle(String title) async {
    if (_state.entries.isEmpty) return;
    final latest = _state.entries.first;
    final oldFile = File(latest.path);
    if (!await oldFile.exists()) return;
    final dir = oldFile.parent.path;
    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(latest.date);
    final safeTitle = title.replaceAll(RegExp(r'[^\w\- ]+'), '').replaceAll(' ', '_');
    final newName = 'diary_${stamp}_$safeTitle.mp4';
    final newPath = '$dir${Platform.pathSeparator}$newName';
    try {
      await oldFile.rename(newPath);
      final updated = DiaryEntry(path: newPath, date: latest.date, thumbnailPath: latest.thumbnailPath, durationMs: latest.durationMs, fileBytes: latest.fileBytes, title: title, description: latest.description, rating: latest.rating);

      final newEntries = List<DiaryEntry>.from(_state.entries);
      newEntries[0] = updated;
      _updateState(_state.copyWith(entries: newEntries));
      await _repo.save(newEntries);
    } catch (_) {
      // ignore
    }
  }

  Future<String?> renameByPath(String path, String newTitle) async {
    try {
      final idx = _state.entries.indexWhere((e) => e.path == path);
      if (idx == -1) return null;
      final old = _state.entries[idx];
      final oldFile = File(old.path);

      final newEntries = List<DiaryEntry>.from(_state.entries);

      if (!await oldFile.exists()) {
        newEntries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: newTitle, description: old.description, rating: old.rating, moods: old.moods);
        _updateState(_state.copyWith(entries: newEntries));
        await _repo.save(newEntries);
        return old.path;
      }

      final dir = oldFile.parent.path;
      final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(old.date);
      final safeTitle = newTitle.replaceAll(RegExp(r'[^\w\- ]+'), '').replaceAll(' ', '_');
      final newName = 'diary_${stamp}_$safeTitle.mp4';
      final newPath = '$dir${Platform.pathSeparator}$newName';
      await oldFile.rename(newPath);

      newEntries[idx] = DiaryEntry(path: newPath, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: newTitle, description: old.description, rating: old.rating, moods: old.moods);
      _updateState(_state.copyWith(entries: newEntries));
      await _repo.save(newEntries);
      return newPath;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteByPath(String path) async {
    try {
      final idx = _state.entries.indexWhere((e) => e.path == path);
      if (idx == -1) return false;
      final e = _state.entries[idx];

      try {
        final f = File(e.path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      try {
        final t = e.thumbnailPath;
        if (t != null) {
          final tf = File(t);
          if (await tf.exists()) {
            await tf.delete();
          }
        }
      } catch (_) {}

      final newEntries = List<DiaryEntry>.from(_state.entries)..removeAt(idx);
      _updateState(_state.copyWith(entries: newEntries));

      await _repo.save(newEntries);
      await _recomputeDailyAverageForDay(e.date);
      _recomputeStreak();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      for (final e in _state.entries) {
        try {
          final f = File(e.path);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
        try {
          final t = e.thumbnailPath;
          if (t != null) {
            final tf = File(t);
            if (await tf.exists()) {
              await tf.delete();
            }
          }
        } catch (_) {}
      }

      _updateState(const DiaryState(status: DiaryStatus.success));
      await _repo.save([]);
      await _dayRepo.clearAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _recomputeStreak() {
    if (_state.entries.isEmpty) {
      _updateState(_state.copyWith(currentStreak: 0, maxStreak: 0, lastRecordedDay: null));
      return;
    }

    final uniqueDays = <DateTime>{};
    for (final e in _state.entries) {
      uniqueDays.add(_dateOnly(e.date));
    }
    final days = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
    final lastRecordedDay = days.first;

    final today = _dateOnly(DateTime.now());
    int cur = 0;
    DateTime? anchor;
    if (days.contains(today)) {
      anchor = today;
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (days.contains(yesterday)) {
        anchor = yesterday;
      }
    }
    if (anchor != null) {
      cur = 1;
      var next = anchor.subtract(const Duration(days: 1));
      while (days.contains(next)) {
        cur += 1;
        next = next.subtract(const Duration(days: 1));
      }
    } else {
      cur = 0;
    }

    int best = 0;
    int run = 0;
    DateTime? prev;
    for (final d in days.reversed) {
      if (prev == null) {
        run = 1;
      } else if (d.difference(prev).inDays == 1) {
        run += 1;
      } else if (d == prev) {
      } else {
        if (run > best) best = run;
        run = 1;
      }
      prev = d;
    }
    if (run > best) best = run;

    _updateState(_state.copyWith(currentStreak: cur, maxStreak: best, lastRecordedDay: lastRecordedDay));
  }

  Future<void> _recomputeDailyAverageForDay(DateTime day) async {
    final key = _keyFor(day);
    final sameDay = _state.entries.where((e) => _keyFor(e.date) == key && (e.rating ?? 0) > 0).toList();

    final newRatings = Map<String, int>.from(_state.dailyRatings);

    if (sameDay.isEmpty) {
      newRatings.remove(key);
      await _dayRepo.clearRating(day);
    } else {
      final avg = (sameDay.map((e) => e.rating!).reduce((a, b) => a + b) / sameDay.length).round();
      newRatings[key] = avg;
      await _dayRepo.setRating(day, avg);
    }

    _updateState(_state.copyWith(dailyRatings: newRatings));
  }

  Future<void> _recomputeDailyMoodsForDay(DateTime day) async {
    final key = _keyFor(day);
    final sameDay = _state.entries.where((e) => _keyFor(e.date) == key).toList();

    final allMoods = <String>{};
    for (final entry in sameDay) {
      if (entry.moods != null && entry.moods!.isNotEmpty) {
        allMoods.addAll(entry.moods!.map((m) => m.name));
      }
    }

    final newMoods = Map<String, List<String>>.from(_state.dailyMoods);

    if (allMoods.isEmpty) {
      newMoods.remove(key);
      await _dayRepo.setMoods(day, []);
    } else {
      final moodList = allMoods.toList();
      newMoods[key] = moodList;
      await _dayRepo.setMoods(day, moodList);
    }

    _updateState(_state.copyWith(dailyMoods: newMoods));
  }

  Future<void> setDailyAverageRating(DateTime day, int rating) async {
    final key = _keyFor(day);
    final newRatings = Map<String, int>.from(_state.dailyRatings)..[key] = rating.clamp(1, 5);
    _updateState(_state.copyWith(dailyRatings: newRatings));
    await _dayRepo.setRating(day, rating.clamp(1, 5));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _keyFor(DateTime d) {
    final dd = _dateOnly(d);
    return '${dd.year}-${dd.month.toString().padLeft(2, '0')}-${dd.day.toString().padLeft(2, '0')}';
  }
}
