import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Streak banner
            _StreakBanner(current: vm.currentStreak, max: vm.maxStreak),
            Expanded(child: _DiaryList(entries: vm.entries)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                    const SizedBox(width: 12),
                    IconButton(tooltip: 'Takvim', icon: const Icon(Icons.calendar_month), onPressed: () => Navigator.of(context).pushNamed('/calendar')),
                    const SizedBox(width: 8),
                    IconButton(tooltip: 'Ayarlar', icon: const Icon(Icons.settings), onPressed: () => Navigator.of(context).pushNamed(SettingsPage.route)),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final vm = context.read<DiaryViewModel>();
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
        return Slidable(
          key: ValueKey(path),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.5,
            children: [
              SlidableAction(
                onPressed: (_) async {
                  final newTitle = await _promptRename(context, current: title ?? '');
                  if (newTitle != null && newTitle.trim().isNotEmpty) {
                    await vm.renameByPath(path, newTitle.trim());
                  }
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Yeniden Adlandır',
              ),
              SlidableAction(
                onPressed: (_) async {
                  final ok = await _confirmDelete(context);
                  if (ok == true) {
                    await vm.deleteByPath(path);
                  }
                },
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Sil',
              ),
            ],
          ),
          child: ListTile(
            leading: thumb != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image(image: FileImage(File(thumb)), width: 56, height: 56, fit: BoxFit.cover),
                  )
                : const Icon(Icons.videocam),
            title: Row(
              children: [
                Expanded(child: Text(title?.isNotEmpty == true ? '${title!} — ${_formatDate(date)}' : _formatDate(date))),
                if ((e.rating ?? 0) > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text('${e.rating}', style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Text('$durationText  •  $sizeText', maxLines: 1),
            onTap: () => _openPlayer(path: path, title: title ?? _formatDate(date)),
          ),
        );
      },
    );
  }

  Future<String?> _promptRename(BuildContext context, {String current = ''}) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Yeni başlık'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Kaydet')),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu videoyu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
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

class _StreakBanner extends StatelessWidget {
  final int current;
  final int max;
  const _StreakBanner({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStreak = current > 0 || max > 0;
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: hasStreak ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Streak: $current gün', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(max > 0 ? 'En iyi seri: $max' : 'Her gün kısa bir video kaydet! 🎯', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
