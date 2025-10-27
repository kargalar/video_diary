import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/mood.dart';
import '../../settings/view/settings_page.dart';
import '../viewmodel/diary_view_model.dart';
import 'recording_page.dart';
import 'widgets/compact_calendar.dart';
import 'widgets/video_grid_item.dart';
import 'widgets/video_item.dart';
import 'widgets/streak_banner.dart';
import 'widgets/video_dialogs.dart';
import 'widgets/video_edit_bottom_sheet.dart';

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
      body: Column(
        children: [
          // Streak banner with settings button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: StreakBanner(current: vm.currentStreak, max: vm.maxStreak),
                ),
                const SizedBox(width: 12),
                IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined, size: 24), onPressed: () => Navigator.of(context).pushNamed(SettingsPage.route)),
              ],
            ),
          ),
          // Compact calendar
          CompactCalendar(entries: vm.entries, currentStreak: vm.currentStreak, vm: vm),
          // Videos grid
          Expanded(child: _DiaryGrid(entries: vm.entries)),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: () async {
            final filePath = await Navigator.of(context).pushNamed(RecordingPage.route);
            if (!mounted) return;

            // If a video was recorded, show the edit bottom sheet
            if (filePath != null && filePath is String) {
              // Get the latest entry
              final latestEntry = vm.entries.isNotEmpty ? vm.entries.first : null;
              if (latestEntry == null) return;

              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                isDismissible: false,
                enableDrag: false,
                builder: (context) => PopScope(
                  canPop: false,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.85,
                    child: VideoEditBottomSheet(currentTitle: '', currentRating: null, currentMoods: const [], showCloseButton: false),
                  ),
                ),
              );

              if (result != null) {
                // Save the metadata
                final title = result['title'] as String;
                final rating = result['rating'] as int?;
                final moods = result['moods'] as List<dynamic>;

                if (title.trim().isNotEmpty) {
                  await vm.renameByPath(latestEntry.path, title.trim());
                }

                if (rating != null && rating > 0) {
                  await vm.setRatingForEntry(latestEntry.path, rating.clamp(1, 5));
                }

                if (moods.isNotEmpty) {
                  await vm.setMoodsForEntry(latestEntry.path, moods.cast());
                }
              } else {
                // User cancelled - delete the video
                await vm.deleteByPath(latestEntry.path);
              }
            }
          },
          icon: const Icon(Icons.fiber_manual_record, size: 16),
          label: const Text('Start Recording', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Grid view for videos
class _DiaryGrid extends StatefulWidget {
  final List<dynamic> entries;
  const _DiaryGrid({required this.entries});

  @override
  State<_DiaryGrid> createState() => _DiaryGridState();
}

class _DiaryGridState extends State<_DiaryGrid> {
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
              'No recordings yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w300, letterSpacing: 0.5),
            ),
          ],
        ),
      );
    }

    final vm = context.read<DiaryViewModel>();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
      itemCount: widget.entries.length,
      itemBuilder: (ctx, i) {
        final e = widget.entries[i];
        return VideoGridItem(
          entry: e,
          onEdit: (updates) async {
            final path = e.path as String;
            final title = e.title as String?;
            final newTitle = updates['title'] as String;
            final newRating = updates['rating'] as int?;
            final newMoods = updates['moods'] as List<Mood>;

            if (newTitle != title) {
              await vm.renameByPath(path, newTitle);
            }

            if (newRating != (e.rating as int?)) {
              if (newRating != null) {
                await vm.setRatingForEntry(path, newRating);
              }
            }

            final currentMoods = (e.moods as List<Mood>?) ?? [];
            if (newMoods.toSet().difference(currentMoods.toSet()).isNotEmpty || currentMoods.toSet().difference(newMoods.toSet()).isNotEmpty) {
              await vm.setMoodsForEntry(path, newMoods);
            }
          },
          onDelete: () async {
            final ok = await VideoDialogs.showDeleteConfirmation(context);
            if (ok == true) {
              await vm.deleteByPath(e.path as String);
            }
          },
        );
      },
    );
  }
}

// Legacy list view - kept for reference, not used
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
              'No recordings yet',
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
          onEdit: (updates) async {
            final newTitle = updates['title'] as String;
            final newRating = updates['rating'] as int?;
            final newMoods = updates['moods'] as List<Mood>;

            // Update title if changed
            if (newTitle != title) {
              await vm.renameByPath(path, newTitle);
            }

            // Update rating if changed
            if (newRating != (e.rating as int?)) {
              if (newRating != null) {
                await vm.setRatingForEntry(path, newRating);
              }
            }

            // Update moods if changed
            final currentMoods = (e.moods as List<Mood>?) ?? [];
            if (newMoods.toSet().difference(currentMoods.toSet()).isNotEmpty || currentMoods.toSet().difference(newMoods.toSet()).isNotEmpty) {
              await vm.setMoodsForEntry(path, newMoods);
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
