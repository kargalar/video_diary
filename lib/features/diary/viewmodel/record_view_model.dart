import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../../services/storage_service.dart';
import '../../../services/video_service.dart';
import '../../settings/data/settings_repository.dart';
import '../model/diary_entry.dart';
import 'record_state.dart';

class RecordViewModel extends ChangeNotifier {
  final VideoService _videoService;
  final SettingsRepository _settingsRepo;
  final StorageService _storageService;

  RecordState _state = const RecordState();
  RecordState get state => _state;

  static const String _preferredCameraLensKey = 'preferred_camera_lens';
  bool _preferredLensLoaded = false;

  DateTime? _recordingStartedAt;
  DateTime? get recordingStartedAt => _recordingStartedAt;

  RecordViewModel(this._videoService, this._settingsRepo, this._storageService);

  void _updateState(RecordState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> ensurePreferredLensLoaded() async {
    if (_preferredLensLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_preferredCameraLensKey);
    final dir = (v == 'back') ? 'back' : 'front';
    _updateState(_state.copyWith(preferredLensDirection: dir));
    _preferredLensLoaded = true;
  }

  Future<void> savePreferredLens(String dir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredCameraLensKey, dir);
    _updateState(_state.copyWith(preferredLensDirection: dir));
  }

  Future<bool> requestAndCheckPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    return cameraStatus.isGranted && micStatus.isGranted;
  }

  /// Prepares the file path for recording and updates state to recording.
  Future<String?> prepareRecording({required Future<bool> Function() onRequireStorageLocation}) async {
    final hasPermissions = await requestAndCheckPermissions();
    if (!hasPermissions) {
      _updateState(_state.copyWith(hasPermission: false, errorMessage: 'Required permissions not granted.'));
      return null;
    }

    var settings = await _settingsRepo.load();
    String? base = settings.storageDirectory;

    if (base == null) {
      final proceed = await onRequireStorageLocation();
      if (!proceed) {
        _updateState(_state.copyWith(errorMessage: 'Storage location not selected.'));
        return null;
      }
      base = await _storageService.pickDirectory();
      if (base == null) {
        _updateState(_state.copyWith(errorMessage: 'Storage location not selected.'));
        return null;
      }
      settings = settings.copyWith(storageDirectory: base);
      await _settingsRepo.save(settings);
    }

    final dir = await _storageService.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}videos${Platform.pathSeparator}$filename';

    // Ensure directory exists
    await Directory('${dir.path}${Platform.pathSeparator}videos').create(recursive: true);

    _recordingStartedAt = DateTime.now();
    _updateState(_state.copyWith(status: RecordStatus.recording, videoPath: filePath));
    return filePath;
  }

  /// Called when CamerAwesome finishes recording and provides the saved file path.
  Future<DiaryEntry?> onVideoSaved(String savedFilePath) async {
    _updateState(_state.copyWith(status: RecordStatus.saving));
    try {
      var settings = await _settingsRepo.load();
      final base = settings.storageDirectory ?? (await _storageService.pickDirectory());

      if (base == null) {
        throw Exception('Storage location not selected.');
      }

      final dir = await _storageService.ensureDiaryFolder(base);
      final targetPath = _state.videoPath!;

      // Move file from CamerAwesome output to our target path
      if (savedFilePath != targetPath) {
        await _videoService.moveVideoFile(savedFilePath, targetPath);
      }

      final file = File(targetPath);
      final bytes = await file.length();

      final thumbDir = '${dir.path}${Platform.pathSeparator}thumbnails';
      final thumbPath = await vt.VideoThumbnail.thumbnailFile(video: targetPath, thumbnailPath: thumbDir, imageFormat: vt.ImageFormat.PNG, maxHeight: 200, quality: 70);

      final durMs = await _probeDurationMs(targetPath);
      final entry = DiaryEntry(path: targetPath, date: DateTime.now(), thumbnailPath: thumbPath, durationMs: durMs, fileBytes: bytes, lensDirection: _state.preferredLensDirection);

      _updateState(_state.copyWith(status: RecordStatus.ready, videoPath: null));
      _recordingStartedAt = null;
      return entry;
    } catch (e) {
      _updateState(_state.copyWith(status: RecordStatus.error, errorMessage: e.toString(), videoPath: null));
      _recordingStartedAt = null;
      return null;
    }
  }

  void setRecordingStarted() {
    _recordingStartedAt = DateTime.now();
    _updateState(_state.copyWith(status: RecordStatus.recording));
  }

  void setReady() {
    _recordingStartedAt = null;
    _updateState(_state.copyWith(status: RecordStatus.ready, videoPath: null));
  }

  String _fileNameFor(DateTime date) {
    final fmt = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return 'diary_${fmt.format(date)}.mp4';
  }

  Future<int?> _probeDurationMs(String path) async {
    try {
      final player = await _videoService.createPlayer(path);
      final ms = player.value.duration.inMilliseconds;
      await player.dispose();
      return ms;
    } catch (_) {
      return null;
    }
  }
}
