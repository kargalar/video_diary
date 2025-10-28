import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<CameraController> initCamera({
    bool landscape = false,
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    _cameras ??= await availableCameras();
    final camera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );
    _controller = CameraController(
      camera,
      preset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    if (landscape) {
      await _controller!.lockCaptureOrientation(
        DeviceOrientation.landscapeLeft,
      );
    } else {
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
    return _controller!;
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
    if (!c.value.isRecordingVideo) return;
    final file = await c.stopVideoRecording();
    await File(file.path).copy(filePath);
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
