import 'dart:async';
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
    final settingsVm = context.read<SettingsViewModel>();
    final vm = context.read<DiaryViewModel>();
    final landscape = settingsVm.state.landscape;
    _currentLandscape = landscape;
    await _applyOrientation(landscape);
    await vm.initCamera();
    if (!mounted) return;
    setState(() => _controller = vm.cameraController);
    // Ensure camera capture orientation matches
    await _lockCameraOrientation(landscape);
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
    // React to settings changes live
    final landscape = context.select<SettingsViewModel, bool>((s) => s.state.landscape);
    if (_currentLandscape != landscape) {
      _currentLandscape = landscape;
      // fire-and-forget updates
      _applyOrientation(landscape);
      _lockCameraOrientation(landscape);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) return;
        final vm = context.read<DiaryViewModel>();
        // Always restore app orientation to portrait when leaving this page
        SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        await vm.disposeCamera();
      },
      child: Scaffold(
        // Prevent keyboard from pushing the whole UI up; let it overlay instead
        resizeToAvoidBottomInset: false,
        appBar: null,
        backgroundColor: Colors.black,
        floatingActionButton: Builder(
          builder: (context) {
            final isRec = vm.isRecording;
            return FloatingActionButton.small(
              backgroundColor: isRec ? Colors.red : Colors.green,
              tooltip: isRec ? 'Durdur' : 'Kaydı Başlat',
              child: Icon(isRec ? Icons.stop : Icons.fiber_manual_record),
              onPressed: () async {
                final nav = Navigator.of(context);
                if (!vm.isRecording) {
                  await vm.startRecording();
                  if (!mounted) return;
                  setState(() {});
                } else {
                  final filePath = await vm.stopRecording();
                  if (!context.mounted) return;
                  if (filePath != null) {
                    // Force portrait immediately after recording ends
                    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                    if (!context.mounted) return;
                    final res = await _askTitleAndRating(context);
                    if (res != null) {
                      final t = res.title.trim();
                      if (t.isNotEmpty) {
                        await vm.renameLastRecordingWithTitle(t);
                      }
                      if (res.rating != null && res.rating! > 0) {
                        // Set rating on the latest entry (just saved)
                        final latestPath = vm.entries.isNotEmpty ? vm.entries.first.path : null;
                        if (latestPath != null) {
                          await vm.setRatingForEntry(latestPath, res.rating!.clamp(1, 5));
                        }
                      }
                      if (res.moods.isNotEmpty) {
                        await vm.addMoodsForDay(DateTime.now(), res.moods);
                      }
                    }
                  }
                  await vm.disposeCamera();
                  nav.pop();
                }
              },
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
                        // If portrait page, ensure width < height for proper contain fit
                        if (!landscape && previewW > previewH) {
                          final tmp = previewW;
                          previewW = previewH;
                          previewH = tmp;
                        }
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
                          final nav = Navigator.of(context);
                          await vm.disposeCamera();
                          if (!mounted) return;
                          // Restore portrait before navigating back
                          await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                          nav.pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kayıt',
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
    );
  }

  Future<_TitleRating?> _askTitleAndRating(BuildContext context) async {
    final titleController = TextEditingController();
    int rating = 0;
    final Set<String> moods = <String>{};
    return showModalBottomSheet<_TitleRating>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets; // respects keyboard height
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Başlık ve Puan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: 'Örn: Gün 1', border: OutlineInputBorder()),
                    onSubmitted: (_) => Navigator.pop(ctx, _TitleRating(titleController.text, rating == 0 ? null : rating, moods.toList())),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Video Puanı:'),
                      const SizedBox(width: 8),
                      StatefulBuilder(
                        builder: (context, setStateSb) {
                          Widget star(int v) => IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 24,
                            onPressed: () => setStateSb(() => rating = v),
                            icon: Icon(v <= rating ? Icons.star : Icons.star_border, color: Colors.amber),
                          );
                          return Row(children: [for (int i = 1; i <= 5; i++) star(i)]);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: Text('Nasıl hissediyorsun? (Birden fazla seçebilirsin)')),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setStateSb) {
                      Widget chip(String id, String label, String emoji) => Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: FilterChip(
                          label: Text('$emoji $label'),
                          selected: moods.contains(id),
                          onSelected: (sel) => setStateSb(() {
                            if (sel) {
                              moods.add(id);
                            } else {
                              moods.remove(id);
                            }
                          }),
                        ),
                      );
                      return Wrap(spacing: 0, runSpacing: 0, children: [chip('mutlu', 'Mutlu', '😊'), chip('uzgun', 'Üzgün', '😢'), chip('kizgin', 'Kızgın', '😠'), chip('yorgun', 'Yorgun', '😴'), chip('hasta', 'Hasta', '🤒'), chip('heyecanli', 'Heyecanlı', '🤩'), chip('stresli', 'Stresli', '😬')]);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, _TitleRating(titleController.text, rating == 0 ? null : rating, moods.toList())), child: const Text('Kaydet')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleRating {
  final String title;
  final int? rating; // 1..5
  final List<String> moods; // multi-select
  _TitleRating(this.title, this.rating, [List<String>? moods]) : moods = moods ?? const [];
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
