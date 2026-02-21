import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/forced_landscape.dart';
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
  CameraController? _controller;
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final vm = context.read<RecordViewModel>();
    await vm.initCamera();
    if (!mounted) return;
    setState(() => _controller = vm.cameraController);
    // Lock capture to portrait so the recorded video is upright
    await _lockCapturePortrait();
  }

  Future<void> _stopRecordingAndExit({required RecordViewModel vm, required bool returnFilePath}) async {
    if (_isStopping) return;
    setState(() => _isStopping = true);
    try {
      final entry = await vm.stopRecording();
      if (entry != null) {
        if (mounted) {
          context.read<DiaryViewModel>().addEntry(entry);
        }
      }
      await vm.disposeCamera();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final nav = Navigator.of(context);
      if (returnFilePath) {
        nav.pop(entry?.path);
      } else {
        nav.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStopping = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
    }
  }

  Future<void> _lockCapturePortrait() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    // Lock capture to landscape so the recorded video is horizontal
    await _controller!.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
  }

  Future<void> _handleSwipeBack() async {
    if (_isStopping) return;
    final vm = context.read<RecordViewModel>();
    if (vm.state.isRecording) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => RotatedBox(
          quarterTurns: 1,
          child: AlertDialog(
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
        ),
      );
      if (shouldDelete == true && mounted) {
        await vm.discardRecording();
        if (!mounted) return;
        await vm.disposeCamera();
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }
    } else {
      await vm.disposeCamera();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    context.read<RecordViewModel>().disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordViewModel>();
    // Always use landscape mode - no dynamic switching

    return ForcedLandscape(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isStopping) return;
          if (vm.state.isRecording) {
            // If recording, show confirmation dialog
            final shouldDelete = await showDialog<bool>(
              context: context,
              builder: (context) => RotatedBox(
                quarterTurns: 1,
                child: AlertDialog(
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
              ),
            );

            if (shouldDelete == true && mounted) {
              await vm.discardRecording();
              if (!mounted) return;
              await vm.disposeCamera();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop(result);
            }
          } else {
            await vm.disposeCamera();
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop(result);
          }
        },
        child: SwipeToPop(
          direction: SwipeDirection.leftToRight,
          onSwipe: _handleSwipeBack,
          child: Stack(
            children: [
              Scaffold(
                // Prevent keyboard from pushing the whole UI up; let it overlay instead
                resizeToAvoidBottomInset: false,
                appBar: null,
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 20,
                      bottom: 20,
                      right: 100,
                      child: _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // Non-distorted preview using previewSize + FittedBox
                                final size = _controller!.value.previewSize;
                                if (size == null) {
                                  return Center(
                                    child: AspectRatio(
                                      aspectRatio: _controller!.value.aspectRatio,
                                      child: ClipRRect(borderRadius: BorderRadius.circular(20.0), child: CameraPreview(_controller!)),
                                    ),
                                  );
                                }
                                double previewW = size.width;
                                double previewH = size.height;
                                // Always landscape mode, no rotation needed
                                return Center(
                                  child: AspectRatio(
                                    aspectRatio: previewW / previewH,
                                    child: ClipRRect(borderRadius: BorderRadius.circular(20.0), child: CameraPreview(_controller!)),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Record button panel on the right side.
                    // Column: timer (recording) or switch camera (idle) above FAB.
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top slot: timer when recording, switch camera when idle
                            if (vm.state.isRecording)
                              RecordingTimer(startedAt: vm.recordingStartedAt)
                            else
                              Material(
                                color: Colors.black45,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Switch camera',
                                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                                  onPressed: _isStopping
                                      ? null
                                      : () async {
                                          final messenger = ScaffoldMessenger.of(context);
                                          try {
                                            await vm.toggleCamera();
                                            if (!mounted) return;
                                            setState(() => _controller = vm.cameraController);
                                            await _lockCapturePortrait();
                                          } catch (e) {
                                            if (!mounted) return;
                                            messenger.showSnackBar(SnackBar(content: Text('Failed to switch camera: $e')));
                                          }
                                        },
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Record FAB
                            Builder(
                              builder: (context) {
                                final isRec = vm.state.isRecording;
                                return FloatingActionButton(
                                  backgroundColor: isRec ? Colors.red : const Color.fromARGB(255, 39, 39, 39),
                                  tooltip: isRec ? 'Stop' : 'Start Recording',
                                  onPressed: _isStopping
                                      ? null
                                      : () async {
                                          if (!vm.state.isRecording) {
                                            try {
                                              await vm.startRecording();
                                              if (!mounted) return;
                                              setState(() {});
                                            } catch (e) {
                                              if (!mounted) return;
                                              // ignore: use_build_context_synchronously
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: Colors.white)),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(seconds: 4),
                                                ),
                                              );
                                            }
                                          } else {
                                            await _stopRecordingAndExit(vm: vm, returnFilePath: true);
                                          }
                                        },
                                  child: Icon(isRec ? Icons.stop : Icons.fiber_manual_record, size: 28),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isStopping)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: Container(
                      color: Colors.black54,
                      // Block all input and show progress while the recording stops.
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
