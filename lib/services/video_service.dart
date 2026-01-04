import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraLensDirection _lensDirection = CameraLensDirection.front;

  CameraLensDirection get lensDirection => _lensDirection;

  Future<CameraController> initCamera({bool landscape = false, ResolutionPreset preset = ResolutionPreset.high, CameraLensDirection? lensDirection}) async {
    _cameras ??= await availableCameras();
    if (lensDirection != null) {
      _lensDirection = lensDirection;
    }

    final camera = _cameras!.firstWhere((c) => c.lensDirection == _lensDirection, orElse: () => _cameras!.first);

    await _controller?.dispose();
    _controller = CameraController(camera, preset, enableAudio: true, imageFormatGroup: ImageFormatGroup.nv21);
    await _controller!.initialize();
    if (landscape) {
      await _controller!.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    } else {
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
    return _controller!;
  }

  Future<CameraController> switchCamera({bool landscape = false, ResolutionPreset preset = ResolutionPreset.high}) async {
    _cameras ??= await availableCameras();
    final hasFront = _cameras!.any((c) => c.lensDirection == CameraLensDirection.front);
    final hasBack = _cameras!.any((c) => c.lensDirection == CameraLensDirection.back);

    if (_lensDirection == CameraLensDirection.front && hasBack) {
      _lensDirection = CameraLensDirection.back;
    } else if (_lensDirection == CameraLensDirection.back && hasFront) {
      _lensDirection = CameraLensDirection.front;
    }

    return initCamera(landscape: landscape, preset: preset, lensDirection: _lensDirection);
  }

  CameraController? get controller => _controller;

  Future<File> startRecording(String filePath) async {
    final c = _controller;
    if (c == null) {
      throw StateError('Camera not initialized');
    }
    if (c.value.isRecordingVideo) {
      throw StateError('Already recording');
    }
    await c.startVideoRecording();
    return File(filePath);
  }

  Future<void> stopRecordingTo(String filePath) async {
    final c = _controller;
    if (c == null) throw StateError('Camera not initialized');
    if (!c.value.isRecordingVideo) {
      // Video is not recording, nothing to stop
      return;
    }
    try {
      final file = await c.stopVideoRecording();
      final sourceFile = File(file.path);
      final targetFile = File(filePath);

      // Ensure target directory exists
      await targetFile.parent.create(recursive: true);

      // Try to rename (move) first - faster and more efficient
      // If rename fails (cross-device), fall back to copy + delete
      try {
        await sourceFile.rename(filePath);
      } catch (_) {
        await sourceFile.copy(filePath);
        await sourceFile.delete();
      }
    } catch (e) {
      // Ensure the original recording file is cleaned up if operation fails
      throw StateError('Failed to stop recording: $e');
    }
  }

  Future<VideoPlayerController> createPlayer(String filePath) async {
    final controller = VideoPlayerController.file(File(filePath));
    await controller.initialize();
    return controller;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
