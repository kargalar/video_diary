import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/widgets/swipe_to_pop.dart';
import '../viewmodel/diary_view_model.dart';
import '../viewmodel/record_view_model.dart';
import 'recording_timer.dart';

class RecordingPage extends StatefulWidget {
  static const route = '/record';
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  bool _isStopping = false;
  CameraState? _cameraState;
  BuildContext? _landscapeDialogContext;
  StreamSubscription? _accelSubscription;
  bool _isLandscapeDetected = false;

  @override
  void initState() {
    super.initState();
    _initPreferences();
    
    _accelSubscription = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      
      // If phone is mostly upright
      if (event.y.abs() > 6.0) {
        if (_isLandscapeDetected || _landscapeDialogContext == null) {
          _isLandscapeDetected = false;
          _showLandscapeWarningIfNeeded();
        }
      } 
      // If phone is mostly horizontal
      else if (event.x.abs() > 6.0) {
        if (!_isLandscapeDetected) {
          _isLandscapeDetected = true;
          if (_landscapeDialogContext != null) {
            Navigator.of(_landscapeDialogContext!).pop();
            _landscapeDialogContext = null;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  void _showLandscapeWarningIfNeeded() {
    if (_landscapeDialogContext != null) return; // dialog already showing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _landscapeDialogContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.elasticOut,
                  builder: (_, value, child) => Transform.rotate(
                    angle: (1.0 - value) * (3.14159 / 2),
                    child: child,
                  ),
                  child: const Icon(
                    Icons.stay_primary_landscape_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rotate Your Phone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'For best results, hold your phone horizontally (landscape mode) while recording.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(178),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _landscapeDialogContext = null;
    });
  }

  Future<void> _initPreferences() async {
    final vm = context.read<RecordViewModel>();
    await vm.ensurePreferredLensLoaded();
  }

  Future<void> _handleSwipeBack() async {
    if (_isStopping) return;
    final vm = context.read<RecordViewModel>();
    if (vm.state.isRecording && _cameraState != null) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete video?'),
          content: const Text('The recorded video will be deleted.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (shouldDelete == true && mounted) {
        _cameraState!.when(
          onVideoRecordingMode: (recordingState) async {
            await recordingState.stopRecording();
            vm.setReady();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        );
      }
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordViewModel>();

    return SafeArea(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isStopping) return;
          _handleSwipeBack();
        },
        child: SwipeToPop(
          direction: SwipeDirection.leftToRight,
          onSwipe: _handleSwipeBack,
          child: Scaffold(
            appBar: null,
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                // Camera preview
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 35),
                      child: ClipRRect(borderRadius: BorderRadius.circular(20.0), child: _buildCameraPreview(vm)),
                    ),
                  ),
                ),

                // Controls at the bottom
                _buildControls(vm),

                SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview(RecordViewModel vm) {
    return CameraAwesomeBuilder.custom(
      previewFit: CameraPreviewFit.cover,
      saveConfig: SaveConfig.video(mirrorFrontCamera: true, videoOptions: VideoOptions(enableAudio: true, quality: VideoRecordingQuality.fhd)),
      sensorConfig: SensorConfig.single(sensor: vm.state.isFrontCamera ? Sensor.position(SensorPosition.front) : Sensor.position(SensorPosition.back), aspectRatio: CameraAspectRatios.ratio_16_9),
      onMediaCaptureEvent: (event) {
        if (event.status == MediaCaptureStatus.success && event.isVideo) {
          event.captureRequest.when(
            single: (single) async {
              final savedPath = single.file?.path;
              if (savedPath != null && mounted) {
                final entry = await vm.onVideoSaved(savedPath);
                if (entry != null && mounted) {
                  // ignore: use_build_context_synchronously
                  context.read<DiaryViewModel>().addEntry(entry);
                }
                setState(() => _isStopping = false);
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop(entry?.path);
                }
              }
            },
          );
        }
      },
      builder: (cameraState, preview) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _cameraState != cameraState) {
            setState(() {
              _cameraState = cameraState;
            });
          }
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildControls(RecordViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Left spacer (balances the right side)
          const Expanded(child: SizedBox()),

          // Record button — always centered
          _buildRecordButton(vm),

          // Right side: switch camera or timer
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 50),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: !vm.state.isRecording
                      ? Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Switch camera',
                            icon: const Icon(Icons.cameraswitch, color: Colors.white),
                            iconSize: 28,
                            onPressed: _isStopping || _cameraState == null
                                ? null
                                : () async {
                                    final newDir = vm.state.isFrontCamera ? 'back' : 'front';
                                    await vm.savePreferredLens(newDir);
                                    if (!mounted || _cameraState == null) return;
                                    _cameraState!.switchCameraSensor();
                                  },
                          ),
                        )
                      : RecordingTimer(startedAt: vm.recordingStartedAt),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton(RecordViewModel vm) {
    final isRec = vm.state.isRecording;
    return GestureDetector(
      onTap: _isStopping || _cameraState == null
          ? null
          : () async {
              if (!isRec) {
                _cameraState!.when(
                  onVideoMode: (videoState) async {
                    try {
                      final path = await vm.prepareRecording(
                        onRequireStorageLocation: () async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Recording Location'),
                              content: const Text('Before you continue, you need to select a folder where your videos will be safely stored.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Select Folder'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                      );
                      if (path == null) return;
                      await videoState.startRecording();
                      if (mounted) setState(() {});
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                );
              } else {
                setState(() => _isStopping = true);
                _cameraState!.when(
                  onVideoRecordingMode: (recordingState) async {
                    await recordingState.stopRecording();
                  },
                );
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 4),
          borderRadius: BorderRadius.circular(isRec ? 16 : 36),
        ),
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(isRec ? 8 : 30)),
        ),
      ),
    );
  }
}
