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
import '../model/diary_entry.dart';

class DiaryViewModel extends ChangeNotifier {
  final DiaryRepository _repo = DiaryRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final StorageService _storage = StorageService();
  final VideoService _video = VideoService();

  List<DiaryEntry> _entries = [];
  List<DiaryEntry> get entries => _entries;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<void> load() async {
    _entries = await _repo.load();
    notifyListeners();
  }

  CameraController? get cameraController => _video.controller;

  Future<void> initCamera() async {
    if (_video.controller != null && _video.controller!.value.isInitialized) return;
    final settings = await _settingsRepo.load();
    await _video.initCamera(landscape: settings.landscape);
    notifyListeners();
  }

  Future<void> startRecording() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    var settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());
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
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    var settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());
    if (settings.storageDirectory == null) {
      settings = settings.copyWith(storageDirectory: base);
      await _settingsRepo.save(settings);
    }
    final dir = await _storage.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}$filename';

    await _video.stopRecordingTo(filePath);
    _isRecording = false;
    final file = File(filePath);
    final bytes = await file.length();
    final thumbPath = await vt.VideoThumbnail.thumbnailFile(video: filePath, imageFormat: vt.ImageFormat.PNG, maxHeight: 200, quality: 70);
    // duration is not trivial to fetch without ffprobe; use video_player quick init
    final durMs = await _probeDurationMs(filePath);
    final entry = DiaryEntry(path: filePath, date: DateTime.now(), thumbnailPath: thumbPath, durationMs: durMs, fileBytes: bytes);
    _entries = [entry, ..._entries];
    await _repo.save(_entries);
    notifyListeners();
    return filePath;
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
      final updated = DiaryEntry(path: newPath, date: latest.date, thumbnailPath: latest.thumbnailPath, durationMs: latest.durationMs, fileBytes: latest.fileBytes, title: title);
      _entries[0] = updated;
      await _repo.save(_entries);
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }
}
