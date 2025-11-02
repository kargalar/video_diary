import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../../services/storage_service.dart';
import '../../../services/video_service.dart';
import '../../settings/data/settings_repository.dart';
import '../data/diary_repository.dart';
import '../data/day_data_repository.dart';
import '../model/diary_entry.dart';
import '../model/mood.dart';

class DiaryViewModel extends ChangeNotifier {
  final DiaryRepository _repo = DiaryRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final StorageService _storage = StorageService();
  final VideoService _video = VideoService();
  final DayDataRepository _dayRepo = DayDataRepository();

  List<DiaryEntry> _entries = [];
  List<DiaryEntry> get entries => _entries;

  // Daily average rating 1..5
  Map<String, int> _dailyRatings = {};
  Map<String, int> get dailyRatings => _dailyRatings;
  // Multiple moods per day
  Map<String, List<String>> _dailyMoods = {}; // key: yyyy-MM-dd -> list of moods
  Map<String, List<String>> get dailyMoods => _dailyMoods;

  // Streak state
  int _currentStreak = 0;
  int _maxStreak = 0;
  DateTime? _lastRecordedDay; // date-only
  int get currentStreak => _currentStreak;
  int get maxStreak => _maxStreak;
  DateTime? get lastRecordedDay => _lastRecordedDay;

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  DateTime? _recordingStartedAt;
  DateTime? get recordingStartedAt => _recordingStartedAt;

  Future<void> load() async {
    _entries = await _repo.load();
    await _dayRepo.init();
    // Load existing hive day data
    final all = await _dayRepo.getAll();
    _dailyRatings = {
      for (final e in all.entries)
        if (e.value.rating != null) e.key: e.value.rating!,
    };
    _dailyMoods = {for (final e in all.entries) e.key: e.value.moods};
    _recomputeStreak();
    notifyListeners();
  }

  CameraController? get cameraController => _video.controller;

  Future<void> initCamera() async {
    if (_video.controller != null && _video.controller!.value.isInitialized) return;
    final settings = await _settingsRepo.load();
    await _video.initCamera(landscape: settings.landscape);
    notifyListeners();
  }

  // Request camera and microphone permissions and return true if both are granted
  Future<bool> requestAndCheckPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    return cameraStatus.isGranted && micStatus.isGranted;
  }

  Future<void> startRecording() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    var settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());

    // If user cancelled location selection or it returned null, throw error
    if (base == null) {
      throw Exception('Storage location not selected. Location selection is required to record videos.');
    }

    if (settings.storageDirectory == null) {
      // persist chosen dir so it appears immediately in settings
      settings = settings.copyWith(storageDirectory: base);
      await _settingsRepo.save(settings);
    }
    final dir = await _storage.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}$filename';

    if (_video.controller == null || !_video.controller!.value.isInitialized) {
      await _video.initCamera(landscape: settings.landscape);
    }
    await _video.startRecording(filePath);
    _isRecording = true;
    _recordingStartedAt = DateTime.now();
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    var settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());

    // If user cancelled location selection or it returned null, throw error
    if (base == null) {
      throw Exception('Storage location not selected. Location selection is required to save videos.');
    }

    if (settings.storageDirectory == null) {
      settings = settings.copyWith(storageDirectory: base);
      await _settingsRepo.save(settings);
    }
    final dir = await _storage.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}$filename';

    await _video.stopRecordingTo(filePath);
    _isRecording = false;
    _recordingStartedAt = null;
    final file = File(filePath);
    final bytes = await file.length();
    final thumbPath = await vt.VideoThumbnail.thumbnailFile(video: filePath, imageFormat: vt.ImageFormat.PNG, maxHeight: 200, quality: 70);
    // duration is not trivial to fetch without ffprobe; use video_player quick init
    final durMs = await _probeDurationMs(filePath);
    final entry = DiaryEntry(path: filePath, date: DateTime.now(), thumbnailPath: thumbPath, durationMs: durMs, fileBytes: bytes);
    _entries = [entry, ..._entries];
    await _repo.save(_entries);
    _recomputeStreak();
    notifyListeners();
    return filePath;
  }

  // Per-entry rating and daily average helpers
  Future<void> setRatingForEntry(String path, int rating) async {
    final idx = _entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _entries[idx];
    _entries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, rating: rating.clamp(1, 5), moods: old.moods);
    await _repo.save(_entries);
    await _recomputeDailyAverageForDay(old.date);
    notifyListeners();
  }

  Future<void> setMoodsForEntry(String path, List<Mood> moods) async {
    final idx = _entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _entries[idx];
    _entries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, rating: old.rating, moods: moods);
    await _repo.save(_entries);
    await _recomputeDailyMoodsForDay(old.date);
    notifyListeners();
  }

  Future<void> setDateForEntry(String path, DateTime newDate) async {
    final idx = _entries.indexWhere((e) => e.path == path);
    if (idx == -1) return;
    final old = _entries[idx];
    _entries[idx] = DiaryEntry(path: old.path, date: newDate, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: old.title, rating: old.rating, moods: old.moods);
    await _repo.save(_entries);
    notifyListeners();
  }

  int? getDailyAverageRating(DateTime day) => _dailyRatings[_keyFor(day)];

  Future<void> clearRatingsForDay(DateTime day) async {
    // Clear average and also remove per-entry ratings for that day
    final key = _keyFor(day);
    await _dayRepo.clearRating(day);
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (_keyFor(e.date) == key && e.rating != null) {
        _entries[i] = DiaryEntry(path: e.path, date: e.date, thumbnailPath: e.thumbnailPath, durationMs: e.durationMs, fileBytes: e.fileBytes, title: e.title, rating: null);
      }
    }
    await _repo.save(_entries);
    _dailyRatings.remove(key);
    notifyListeners();
  }

  Future<void> setMoodsForDay(DateTime day, List<String> moods) async {
    await _dayRepo.setMoods(day, moods);
    _dailyMoods = {..._dailyMoods, _keyFor(day): List<String>.from(moods)};
    notifyListeners();
  }

  List<String> getMoodsForDay(DateTime day) => _dailyMoods[_keyFor(day)] ?? const [];

  Future<void> addMoodsForDay(DateTime day, List<String> moods) async {
    if (moods.isEmpty) return;
    await _dayRepo.addMoods(day, moods);
    final key = _keyFor(day);
    final merged = {...(_dailyMoods[key] ?? const <String>[]), ...moods}.toList();
    _dailyMoods = {..._dailyMoods, key: merged};
    notifyListeners();
  }

  String _fileNameFor(DateTime date) {
    final fmt = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'diary_${fmt.format(date)}.mp4';
  }

  Future<int?> _probeDurationMs(String path) async {
    try {
      final player = await _video.createPlayer(path);
      final ms = player.value.duration.inMilliseconds;
      await player.dispose();
      return ms;
    } catch (_) {
      return null;
    }
  }

  Future<void> renameLastRecordingWithTitle(String title) async {
    if (_entries.isEmpty) return;
    final latest = _entries.first;
    final oldFile = File(latest.path);
    if (!await oldFile.exists()) return;
    final dir = oldFile.parent.path;
    final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(latest.date);
    final safeTitle = title.replaceAll(RegExp(r'[^\w\- ]+'), '').replaceAll(' ', '_');
    final newName = 'diary_${stamp}_$safeTitle.mp4';
    final newPath = '$dir${Platform.pathSeparator}$newName';
    try {
      await oldFile.rename(newPath);
      final updated = DiaryEntry(path: newPath, date: latest.date, thumbnailPath: latest.thumbnailPath, durationMs: latest.durationMs, fileBytes: latest.fileBytes, title: title, rating: latest.rating);
      _entries[0] = updated;
      await _repo.save(_entries);
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> disposeCamera() async {
    await _video.dispose();
  }

  Future<String?> renameByPath(String path, String newTitle) async {
    try {
      final idx = _entries.indexWhere((e) => e.path == path);
      if (idx == -1) return null;
      final old = _entries[idx];
      final oldFile = File(old.path);
      if (!await oldFile.exists()) {
        // File missing; update title only
        _entries[idx] = DiaryEntry(path: old.path, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: newTitle, rating: old.rating, moods: old.moods);
        await _repo.save(_entries);
        notifyListeners();
        return old.path;
      }
      final dir = oldFile.parent.path;
      final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(old.date);
      final safeTitle = newTitle.replaceAll(RegExp(r'[^\w\- ]+'), '').replaceAll(' ', '_');
      final newName = 'diary_${stamp}_$safeTitle.mp4';
      final newPath = '$dir${Platform.pathSeparator}$newName';
      await oldFile.rename(newPath);
      _entries[idx] = DiaryEntry(path: newPath, date: old.date, thumbnailPath: old.thumbnailPath, durationMs: old.durationMs, fileBytes: old.fileBytes, title: newTitle, rating: old.rating, moods: old.moods);
      await _repo.save(_entries);
      notifyListeners();
      return newPath;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteByPath(String path) async {
    try {
      final idx = _entries.indexWhere((e) => e.path == path);
      if (idx == -1) return false;
      final e = _entries[idx];
      // Attempt to delete files
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
      _entries.removeAt(idx);
      await _repo.save(_entries);
      await _recomputeDailyAverageForDay(e.date);
      _recomputeStreak();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      // Delete all video and thumbnail files
      for (final e in _entries) {
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
      // Clear all data
      _entries = [];
      _dailyRatings = {};
      _dailyMoods = {};
      _currentStreak = 0;
      _maxStreak = 0;
      _lastRecordedDay = null;
      await _repo.save(_entries);
      await _dayRepo.clearAll();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _recomputeStreak() {
    if (_entries.isEmpty) {
      _currentStreak = 0;
      _maxStreak = 0;
      _lastRecordedDay = null;
      return;
    }
    // Build unique day set from entries
    final uniqueDays = <DateTime>{};
    for (final e in _entries) {
      uniqueDays.add(_dateOnly(e.date));
    }
    final days = uniqueDays.toList()..sort((a, b) => b.compareTo(a)); // desc
    _lastRecordedDay = days.first;

    // Current streak: count consecutive days starting from today or yesterday
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
    _currentStreak = cur;

    // Max streak across all days
    int best = 0;
    int run = 0;
    DateTime? prev;
    for (final d in days.reversed) {
      // ascending
      if (prev == null) {
        run = 1;
      } else if (d.difference(prev).inDays == 1) {
        run += 1;
      } else if (d == prev) {
        // same day won't happen due to uniqueness, but keep for safety
      } else {
        if (run > best) best = run;
        run = 1;
      }
      prev = d;
    }
    if (run > best) best = run;
    _maxStreak = best;
  }

  Future<void> _recomputeDailyAverageForDay(DateTime day) async {
    final key = _keyFor(day);
    final sameDay = _entries.where((e) => _keyFor(e.date) == key && (e.rating ?? 0) > 0).toList();
    if (sameDay.isEmpty) {
      _dailyRatings.remove(key);
      await _dayRepo.clearRating(day);
      return;
    }
    final avg = (sameDay.map((e) => e.rating!).reduce((a, b) => a + b) / sameDay.length).round();
    _dailyRatings[key] = avg;
    await _dayRepo.setRating(day, avg);
  }

  Future<void> _recomputeDailyMoodsForDay(DateTime day) async {
    final key = _keyFor(day);
    final sameDay = _entries.where((e) => _keyFor(e.date) == key).toList();

    // Collect all moods for this day
    final allMoods = <String>{};
    for (final entry in sameDay) {
      if (entry.moods != null && entry.moods!.isNotEmpty) {
        allMoods.addAll(entry.moods!.map((m) => m.name));
      }
    }

    if (allMoods.isEmpty) {
      _dailyMoods.remove(key);
      await _dayRepo.setMoods(day, []);
    } else {
      final moodList = allMoods.toList();
      _dailyMoods[key] = moodList;
      await _dayRepo.setMoods(day, moodList);
    }
  }

  Future<void> setDailyAverageRating(DateTime day, int rating) async {
    final key = _keyFor(day);
    _dailyRatings[key] = rating.clamp(1, 5);
    await _dayRepo.setRating(day, rating.clamp(1, 5));
    notifyListeners();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _keyFor(DateTime d) {
    final dd = _dateOnly(d);
    return '${dd.year}-${dd.month.toString().padLeft(2, '0')}-${dd.day.toString().padLeft(2, '0')}';
  }
}
