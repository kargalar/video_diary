import 'package:camera/camera.dart';

enum RecordStatus { initial, initializing, ready, recording, paused, saving, error }

class RecordState {
  final RecordStatus status;
  final CameraLensDirection preferredLensDirection;
  final bool hasPermission;
  final int remainingSeconds;
  final String? videoPath;
  final String? errorMessage;

  const RecordState({this.status = RecordStatus.initial, this.preferredLensDirection = CameraLensDirection.front, this.hasPermission = true, this.remainingSeconds = 0, this.videoPath, this.errorMessage});

  bool get isRecording => status == RecordStatus.recording;
  bool get isPaused => status == RecordStatus.paused;
  bool get isReady => status == RecordStatus.ready;

  RecordState copyWith({RecordStatus? status, CameraLensDirection? preferredLensDirection, bool? hasPermission, int? remainingSeconds, String? videoPath, String? errorMessage}) {
    return RecordState(
      status: status ?? this.status,
      preferredLensDirection: preferredLensDirection ?? this.preferredLensDirection,
      hasPermission: hasPermission ?? this.hasPermission,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      videoPath: videoPath ?? this.videoPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
