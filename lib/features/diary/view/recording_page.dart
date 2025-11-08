import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodel/diary_view_model.dart';

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
    // Always use landscape orientation for recording
    final vm = context.read<DiaryViewModel>();
    const landscape = true;
    await _applyOrientation(landscape);
    await vm.initCamera();
    if (!mounted) return;
    setState(() => _controller = vm.cameraController);
    // Ensure camera capture orientation matches
    await _lockCameraOrientation(landscape);
  }

  Future<void> _stopRecordingAndExit({required DiaryViewModel vm, required bool returnFilePath}) async {
    if (_isStopping) return;
    setState(() => _isStopping = true);
    try {
      final filePath = await vm.stopRecording();
      if (!mounted) return;
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      await vm.disposeCamera();
      // ignore: use_build_context_synchronously
      final nav = Navigator.of(context);
      if (returnFilePath) {
        nav.pop(filePath);
      } else {
        nav.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStopping = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to stop recording.')));
    }
  }

  Future<void> _applyOrientation(bool landscape) async {
    if (landscape) {
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
  }

  Future<void> _lockCameraOrientation(bool landscape) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (landscape) {
      await _controller!.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    } else {
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
  }

  @override
  void dispose() {
    // Release camera and restore all orientations when leaving the page
    context.read<DiaryViewModel>().disposeCamera();
    // Return app to portrait when leaving recording
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiaryViewModel>();
    // Always use landscape mode - no dynamic switching

    return PopScope(
      canPop: !vm.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isStopping) return;
        if (didPop) {
          // If already popped (not recording), clean up
          final vm = context.read<DiaryViewModel>();
          await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
          await vm.disposeCamera();
        } else if (vm.isRecording) {
          // If recording, show confirmation dialog
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
            // Discard the recording without saving
            await vm.disposeCamera();
            await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            // Prevent keyboard from pushing the whole UI up; let it overlay instead
            resizeToAvoidBottomInset: false,
            appBar: null,
            backgroundColor: Colors.black,
            floatingActionButton: Builder(
              builder: (context) {
                final isRec = vm.isRecording;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    backgroundColor: isRec ? Colors.red : Colors.black87,
                    tooltip: isRec ? 'Stop' : 'Start Recording',
                    onPressed: _isStopping
                        ? null
                        : () async {
                            if (!vm.isRecording) {
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
                  ),
                );
              },
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _controller == null
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // Non-distorted preview using previewSize + FittedBox
                            final size = _controller!.value.previewSize;
                            if (size == null) {
                              return Center(
                                child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: CameraPreview(_controller!)),
                              );
                            }
                            double previewW = size.width;
                            double previewH = size.height;
                            // Always landscape mode, no rotation needed
                            return FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(width: previewW, height: previewH, child: CameraPreview(_controller!)),
                            );
                          },
                        ),
                ),
                // Top overlay: back button (now above preview)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () async {
                              final vm = context.read<DiaryViewModel>();
                              if (vm.isRecording) {
                                // If recording, show confirmation dialog
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
                                  // Discard the recording without saving
                                  await vm.disposeCamera();
                                  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                                  if (!mounted) return;
                                  // ignore: use_build_context_synchronously
                                  Navigator.of(context).pop();
                                }
                              } else {
                                // Not recording, just go back
                                await vm.disposeCamera();
                                await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Recording',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Elapsed timer overlay when recording
                if (vm.isRecording)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(bottom: false, child: _RecordingTimer(startedAt: vm.recordingStartedAt)),
                  ),
                // Removed the large centered start/stop button; using small FAB at bottom-right instead
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
    );
  }
}

class _RecordingTimer extends StatefulWidget {
  final DateTime? startedAt;
  const _RecordingTimer({required this.startedAt});

  @override
  State<_RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<_RecordingTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = widget.startedAt;
      if (!mounted || start == null) return;
      setState(() => _elapsed = DateTime.now().difference(start));
    });
  }

  @override
  void didUpdateWidget(covariant _RecordingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _fmt(_elapsed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
