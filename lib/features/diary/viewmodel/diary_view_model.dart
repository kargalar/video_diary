import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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
    await _video.initCamera();
    notifyListeners();
  }

  Future<void> startRecording() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    final settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());
    final dir = await _storage.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}$filename';

    if (_video.controller == null || !_video.controller!.value.isInitialized) {
      await _video.initCamera();
    }
    await _video.startRecording(filePath);
    _isRecording = true;
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storage.pickDirectory());
    final dir = await _storage.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}$filename';

    await _video.stopRecordingTo(filePath);
    _isRecording = false;
    final entry = DiaryEntry(path: filePath, date: DateTime.now());
    _entries = [entry, ..._entries];
    await _repo.save(_entries);
    notifyListeners();
    return filePath;
  }

  String _fileNameFor(DateTime date) {
    final fmt = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'diary_${fmt.format(date)}.mp4';
  }
}
