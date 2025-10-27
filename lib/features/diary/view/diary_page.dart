import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/view/settings_page.dart';
import '../viewmodel/diary_view_model.dart';
import 'recording_page.dart';
import 'widgets/video_item.dart';
import 'widgets/streak_banner.dart';
import 'widgets/video_dialogs.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük', style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1.2)),
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Takvim', icon: const Icon(Icons.calendar_today_outlined, size: 20), onPressed: () => Navigator.of(context).pushNamed('/calendar')),
          IconButton(tooltip: 'Ayarlar', icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () => Navigator.of(context).pushNamed(SettingsPage.route)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Streak banner - minimalist version
          StreakBanner(current: vm.currentStreak, max: vm.maxStreak),
          Expanded(child: _DiaryList(entries: vm.entries)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(16)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pushNamed(RecordingPage.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 16, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Kayıt Başlat',
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Henüz kayıt yok',
              style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w300, letterSpacing: 0.5),
            ),
          ],
        ),
      );
    }
    final vm = context.read<DiaryViewModel>();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.entries.length,
      itemBuilder: (ctx, i) {
        final e = widget.entries[i];
        final path = e.path as String;
        final title = e.title as String?;

        return VideoItem(
          entry: e,
          onRename: () async {
            final newTitle = await VideoDialogs.showRenameDialog(context, current: title ?? '');
            if (newTitle != null && newTitle.trim().isNotEmpty) {
              await vm.renameByPath(path, newTitle.trim());
            }
          },
          onDelete: () async {
            final ok = await VideoDialogs.showDeleteConfirmation(context);
            if (ok == true) {
              await vm.deleteByPath(path);
            }
          },
        );
      },
    );
  }
}
