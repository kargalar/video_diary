enum RecordStatus { initial, initializing, ready, recording, paused, saving, error }

class RecordState {
  final RecordStatus status;
  final String preferredLensDirection; // 'front' or 'back'
  final bool hasPermission;
  final int remainingSeconds;
  final String? videoPath;
  final String? errorMessage;

  const RecordState({this.status = RecordStatus.initial, this.preferredLensDirection = 'front', this.hasPermission = true, this.remainingSeconds = 0, this.videoPath, this.errorMessage});

  bool get isRecording => status == RecordStatus.recording;
  bool get isPaused => status == RecordStatus.paused;
  bool get isReady => status == RecordStatus.ready;
  bool get isFrontCamera => preferredLensDirection == 'front';

  RecordState copyWith({RecordStatus? status, String? preferredLensDirection, bool? hasPermission, int? remainingSeconds, String? videoPath, String? errorMessage}) {
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
