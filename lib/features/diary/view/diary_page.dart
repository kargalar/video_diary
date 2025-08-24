import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/view/settings_page.dart';
import '../viewmodel/diary_view_model.dart';
import 'recording_page.dart';
import 'player_page.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  @override
  void initState() {
    super.initState();
    final vm = context.read<DiaryViewModel>();
    vm.load();
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Kayda Başla'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => Navigator.of(context).pushNamed(RecordingPage.route),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(flex: 3, child: _DiaryList(entries: vm.entries)),
        ],
      ),
    );
  }
}

// removed inline record bar; recording happens on RecordingPage

class _DiaryList extends StatefulWidget {
  final List<dynamic> entries; // DiaryEntry list but keep loose to avoid import
  const _DiaryList({required this.entries});

  @override
  State<_DiaryList> createState() => _DiaryListState();
}

class _DiaryListState extends State<_DiaryList> {
  void _openPlayer({required String path, String? title}) {
    Navigator.of(context).pushNamed(
      PlayerPage.route,
      arguments: PlayerPageArgs(path: path, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const Center(child: Text('Henüz kayıt yok.'));
    }
    return ListView.separated(
      itemCount: widget.entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final e = widget.entries[i];
        final path = e.path as String;
        final date = e.date as DateTime;
        final thumb = e.thumbnailPath as String?;
        final durMs = e.durationMs as int?;
        final bytes = e.fileBytes as int?;
        final title = e.title as String?;
        final durationText = durMs != null ? _formatDuration(Duration(milliseconds: durMs)) : '';
        final sizeText = bytes != null ? _formatSize(bytes) : '';
        return ListTile(
          leading: thumb != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image(image: FileImage(File(thumb)), width: 56, height: 56, fit: BoxFit.cover),
                )
              : const Icon(Icons.videocam),
          title: Text(title?.isNotEmpty == true ? title! : _formatDate(date)),
          subtitle: Text('$durationText  •  $sizeText', maxLines: 1),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _openPlayer(path: path, title: title ?? _formatDate(date)),
          ),
          onTap: () => _openPlayer(path: path, title: title ?? _formatDate(date)),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }

  String _formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }
}
