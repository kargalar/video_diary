import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodel/diary_view_model.dart';
import '../../settings/viewmodel/settings_view_model.dart';

class RecordingPage extends StatefulWidget {
  static const route = '/record';
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  CameraController? _controller;
  bool? _currentLandscape;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Apply preferred device orientation according to settings
    final settings = context.read<SettingsViewModel>().state;
    _currentLandscape = settings.landscape;
    await _applyOrientation(settings.landscape);

    final vm = context.read<DiaryViewModel>();
    await vm.initCamera();
    if (!mounted) return;
    setState(() => _controller = vm.cameraController);
    // Ensure camera capture orientation matches
    await _lockCameraOrientation(settings.landscape);
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
    // Restore all orientations when leaving the page
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiaryViewModel>();
    // React to settings changes live
    final landscape = context.select<SettingsViewModel, bool>((s) => s.state.landscape);
    if (_currentLandscape != landscape) {
      _currentLandscape = landscape;
      // fire-and-forget updates
      _applyOrientation(landscape);
      _lockCameraOrientation(landscape);
    }

    return Scaffold(
      appBar: landscape ? null : AppBar(title: const Text('Kayıt')),
      backgroundColor: Colors.black,
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
                      // If portrait page, ensure width < height for proper contain fit
                      if (!landscape && previewW > previewH) {
                        final tmp = previewW;
                        previewW = previewH;
                        previewH = tmp;
                      }
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(width: previewW, height: previewH, child: CameraPreview(_controller!)),
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: ElevatedButton.icon(
                icon: Icon(vm.isRecording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(vm.isRecording ? 'Durdur' : 'Kaydı Başlat'),
                style: ElevatedButton.styleFrom(backgroundColor: vm.isRecording ? Colors.red : Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: const StadiumBorder()),
                onPressed: () async {
                  if (!vm.isRecording) {
                    await vm.startRecording();
                    if (!mounted) return;
                    setState(() {});
                  } else {
                    final filePath = await vm.stopRecording();
                    if (!mounted) return;
                    if (filePath != null) {
                      final title = await _askTitle(context);
                      if (title != null && title.trim().isNotEmpty) {
                        await vm.renameLastRecordingWithTitle(title.trim());
                      }
                    }
                    if (mounted) Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askTitle(BuildContext context) async {
    final titleController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başlık Gir'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Örn: Gün 1'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, titleController.text), child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
