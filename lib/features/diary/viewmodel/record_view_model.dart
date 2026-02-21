import 'dart:io';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  CameraController? get cameraController => _videoService.controller;

  void _updateState(RecordState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _ensurePreferredLensLoaded() async {
    if (_preferredLensLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_preferredCameraLensKey);
    CameraLensDirection dir = CameraLensDirection.front;
    if (v == 'back') {
      dir = CameraLensDirection.back;
    }
    _updateState(_state.copyWith(preferredLensDirection: dir));
    _preferredLensLoaded = true;
  }

  Future<void> _savePreferredLens(CameraLensDirection dir) async {
    final prefs = await SharedPreferences.getInstance();
    final v = dir == CameraLensDirection.back ? 'back' : 'front';
    await prefs.setString(_preferredCameraLensKey, v);
  }

  Future<void> initCamera() async {
    if (_videoService.controller != null && _videoService.controller!.value.isInitialized) return;

    Future.microtask(() => _updateState(_state.copyWith(status: RecordStatus.initializing)));
    try {
      await _ensurePreferredLensLoaded();
      final settings = await _settingsRepo.load();
      await _videoService.initCamera(landscape: settings.landscape, lensDirection: _state.preferredLensDirection);
      _updateState(_state.copyWith(status: RecordStatus.ready));
    } catch (e) {
      _updateState(_state.copyWith(status: RecordStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> toggleCamera() async {
    if (_state.isRecording) return;
    try {
      await _ensurePreferredLensLoaded();
      final settings = await _settingsRepo.load();
      await _videoService.switchCamera(landscape: settings.landscape);
      final newDirection = _videoService.lensDirection;
      await _savePreferredLens(newDirection);
      _updateState(_state.copyWith(preferredLensDirection: newDirection));
    } catch (e) {
      _updateState(_state.copyWith(status: RecordStatus.error, errorMessage: e.toString()));
    }
  }

  Future<bool> requestAndCheckPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final videoStatus = await Permission.videos.request();
        return cameraStatus.isGranted && micStatus.isGranted && videoStatus.isGranted;
      }
    }

    return cameraStatus.isGranted && micStatus.isGranted;
  }

  Future<void> startRecording() async {
    final hasPermissions = await requestAndCheckPermissions();
    if (!hasPermissions) {
      _updateState(_state.copyWith(hasPermission: false, errorMessage: 'Required permissions not granted.'));
      return;
    }

    var settings = await _settingsRepo.load();
    final base = settings.storageDirectory ?? (await _storageService.pickDirectory());

    if (base == null) {
      _updateState(_state.copyWith(errorMessage: 'Storage location not selected.'));
      return;
    }

    if (settings.storageDirectory == null) {
      settings = settings.copyWith(storageDirectory: base);
      await _settingsRepo.save(settings);
    }

    final dir = await _storageService.ensureDiaryFolder(base);
    final filename = _fileNameFor(DateTime.now());
    final filePath = '${dir.path}${Platform.pathSeparator}videos${Platform.pathSeparator}$filename';

    if (_videoService.controller == null || !_videoService.controller!.value.isInitialized) {
      await _ensurePreferredLensLoaded();
      await _videoService.initCamera(landscape: settings.landscape, lensDirection: _state.preferredLensDirection);
    }

    try {
      await _videoService.startRecording(filePath);
      _recordingStartedAt = DateTime.now();
      _updateState(_state.copyWith(status: RecordStatus.recording, videoPath: filePath));
    } catch (e) {
      _recordingStartedAt = null;
      _updateState(_state.copyWith(status: RecordStatus.error, errorMessage: e.toString()));
    }
  }

  Future<DiaryEntry?> stopRecording() async {
    if (!_state.isRecording) return null;

    _updateState(_state.copyWith(status: RecordStatus.saving));
    try {
      var settings = await _settingsRepo.load();
      final base = settings.storageDirectory ?? (await _storageService.pickDirectory());

      if (base == null) {
        throw Exception('Storage location not selected.');
      }

      final dir = await _storageService.ensureDiaryFolder(base);
      final filePath = _state.videoPath!;

      await _videoService.stopRecordingTo(filePath);
      final file = File(filePath);
      final bytes = await file.length();

      final thumbDir = '${dir.path}${Platform.pathSeparator}thumbnails';
      final thumbPath = await vt.VideoThumbnail.thumbnailFile(video: filePath, thumbnailPath: thumbDir, imageFormat: vt.ImageFormat.PNG, maxHeight: 200, quality: 70);

      final durMs = await _probeDurationMs(filePath);
      final entry = DiaryEntry(path: filePath, date: DateTime.now(), thumbnailPath: thumbPath, durationMs: durMs, fileBytes: bytes);

      _updateState(_state.copyWith(status: RecordStatus.ready, videoPath: null));
      _recordingStartedAt = null;
      return entry;
    } catch (e) {
      _updateState(_state.copyWith(status: RecordStatus.error, errorMessage: e.toString(), videoPath: null));
      _recordingStartedAt = null;
      return null;
    }
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

  /// Stops the active recording, deletes the temp file, and clears recording state.
  Future<void> discardRecording() async {
    if (!_state.isRecording) return;
    await _videoService.discardRecording();
    _recordingStartedAt = null;
    _updateState(_state.copyWith(status: RecordStatus.ready, videoPath: null));
  }

  Future<void> disposeCamera() async {
    // Stop any active recording before disposing so the temp file is cleaned up
    // and the state is cleared before the camera controller is released.
    if (_state.isRecording) {
      await _videoService.discardRecording();
      _recordingStartedAt = null;
      _updateState(_state.copyWith(status: RecordStatus.ready, videoPath: null));
    }
    await _videoService.dispose();
    _updateState(const RecordState());
  }

  @override
  void dispose() {
    _videoService.dispose();
    super.dispose();
  }
}
