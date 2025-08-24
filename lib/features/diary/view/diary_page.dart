import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../settings/view/settings_page.dart';
import '../viewmodel/diary_view_model.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    final vm = context.read<DiaryViewModel>();
    vm.load();
    _initCamera(vm);
  }

  Future<void> _initCamera(DiaryViewModel vm) async {
    try {
      await vm.initCamera();
      final c = vm.cameraController;
      if (!mounted) return;
      setState(() => _cameraController = c);
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiaryViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Günlüğü'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.of(context).pushNamed(SettingsPage.route))],
      ),
      body: Column(
        children: [
          Expanded(flex: 2, child: _cameraController == null ? const Center(child: CircularProgressIndicator()) : CameraPreview(_cameraController!)),
          _RecordBar(isRecording: vm.isRecording, onStart: vm.startRecording, onStop: vm.stopRecording),
          const Divider(height: 1),
          Expanded(flex: 3, child: _DiaryList(paths: vm.entries.map((e) => e.path).toList())),
        ],
      ),
    );
  }
}

class _RecordBar extends StatelessWidget {
  final bool isRecording;
  final Future<void> Function() onStart;
  final Future<String?> Function() onStop;
  const _RecordBar({required this.isRecording, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white),
              label: Text(isRecording ? 'Durdur' : 'Kayda Başla'),
              style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : Colors.green),
              onPressed: isRecording ? () => onStop() : () => onStart(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryList extends StatefulWidget {
  final List<String> paths;
  const _DiaryList({required this.paths});

  @override
  State<_DiaryList> createState() => _DiaryListState();
}

class _DiaryListState extends State<_DiaryList> {
  VideoPlayerController? _player;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _play(String path) async {
    final p = VideoPlayerController.file(File(path));
    await p.initialize();
    await _player?.dispose();
    setState(() => _player = p);
    await p.play();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) {
      return const Center(child: Text('Henüz kayıt yok.'));
    }
    return ListView.separated(
      itemCount: widget.paths.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final path = widget.paths[i];
        final name = path.split(Platform.pathSeparator).last;
        final playing = _player != null && _player!.value.isInitialized && _player!.dataSource == path;
        return ListTile(
          leading: const Icon(Icons.videocam),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: Icon(playing && _player!.value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () async {
              if (playing) {
                if (_player!.value.isPlaying) {
                  await _player!.pause();
                } else {
                  await _player!.play();
                }
                setState(() {});
              } else {
                await _play(path);
              }
            },
          ),
        );
      },
    );
  }
}
