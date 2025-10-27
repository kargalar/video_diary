import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/mood.dart';
import '../viewmodel/diary_view_model.dart';
import 'widgets/compact_calendar.dart';
import 'widgets/video_grid_item.dart';
import 'widgets/video_dialogs.dart';
import 'widgets/bottom_action_buttons.dart';

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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendar
              Padding(
                padding: const EdgeInsets.all(4),
                child: CompactCalendar(entries: vm.entries, currentStreak: vm.currentStreak, vm: vm),
              ),
              // Videos grid
              _DiaryGrid(entries: vm.entries),
            ],
          ),
        ),
      ),
      floatingActionButton: const BottomActionButtons(),
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
  final Set<String> _expandedDays = {};

  Map<String, List<dynamic>> _groupByDay(List<dynamic> entries) {
    final Map<String, List<dynamic>> grouped = {};
    for (var entry in entries) {
      final date = entry.date as DateTime;
      final key = '${date.year}-${date.month}-${date.day}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    // Sort entries within each day (newest first)
    for (var dayEntries in grouped.values) {
      dayEntries.sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 80),
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
    final groupedEntries = _groupByDay(widget.entries);
    final sortedDays = groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sortedDays.length,
      itemBuilder: (ctx, i) {
        final dayKey = sortedDays[i];
        final dayEntries = groupedEntries[dayKey]!;
        final isExpanded = _expandedDays.contains(dayKey);
        final isSingleVideo = dayEntries.length == 1;

        if (isSingleVideo) {
          // Show single video directly
          final e = dayEntries[0];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoGridItem(entry: e, onEdit: (updates) => _handleEdit(vm, e, updates), onDelete: () => _handleDelete(vm, e)),
            ),
          );
        }

        // Show folder for multiple videos
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildDayFolder(context, dayKey, dayEntries, isExpanded, vm));
      },
    );
  }

  Widget _buildDayFolder(BuildContext context, String dayKey, List<dynamic> entries, bool isExpanded, DiaryViewModel vm) {
    final theme = Theme.of(context);
    final firstEntry = entries[0];
    final date = firstEntry.date as DateTime;

    // Calculate aggregated data
    final allMoods = <Mood>{};
    int totalRating = 0;
    int ratingCount = 0;

    for (var entry in entries) {
      final moods = (entry.moods as List<Mood>?) ?? [];
      allMoods.addAll(moods);
      final rating = entry.rating as int?;
      if (rating != null) {
        totalRating += rating;
        ratingCount++;
      }
    }

    final avgRating = ratingCount > 0 ? (totalRating / ratingCount).round() : null;

    return Column(
      children: [
        // Folder header
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedDays.remove(dayKey);
              } else {
                _expandedDays.add(dayKey);
              }
            });
          },
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background - stacked thumbnails effect
                    Positioned.fill(child: _buildStackedThumbnails(entries)),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withAlpha(150)], stops: const [0.5, 1.0]),
                        ),
                      ),
                    ),
                    // Info overlay at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title with video count
                            Row(
                              children: [
                                const Icon(Icons.folder, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(date),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${entries.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Moods and Rating
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Moods
                                if (allMoods.isNotEmpty)
                                  Expanded(
                                    child: Wrap(spacing: 2, children: allMoods.take(5).map((mood) => Text(mood.emoji, style: const TextStyle(fontSize: 14))).toList()),
                                  ),
                                // Rating
                                if (avgRating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.amber.withAlpha(230), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, size: 12, color: Colors.white),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$avgRating',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expand indicator
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(8)),
                        child: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Expanded videos
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Column(
              children: entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoGridItem(entry: e, onEdit: (updates) => _handleEdit(vm, e, updates), onDelete: () => _handleDelete(vm, e)),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStackedThumbnails(List<dynamic> entries) {
    final thumbnails = entries.take(3).map((e) => e.thumbnailPath as String?).where((t) => t != null).toList();

    if (thumbnails.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.videocam_outlined, size: 48, color: Colors.grey[400]),
      );
    }

    return Stack(
      children: [
        // Main thumbnail (full)
        Positioned.fill(child: Image.file(File(thumbnails[0]!), fit: BoxFit.cover)),
        // Second thumbnail (if exists) - small overlay at bottom right
        if (thumbnails.length > 1)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(thumbnails[1]!), fit: BoxFit.cover),
              ),
            ),
          ),
        // Third thumbnail (if exists) - small overlay next to second
        if (thumbnails.length > 2)
          Positioned(
            bottom: 8,
            right: 76,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(thumbnails[2]!), fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleEdit(DiaryViewModel vm, dynamic e, Map<String, dynamic> updates) async {
    final path = e.path as String;
    final title = e.title as String?;
    final newTitle = updates['title'] as String;
    final newRating = updates['rating'] as int?;
    final newMoods = updates['moods'] as List<Mood>;
    final newDate = updates['date'] as DateTime?;

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

    if (newDate != null && newDate != (e.date as DateTime)) {
      await vm.setDateForEntry(path, newDate);
    }
  }

  Future<void> _handleDelete(DiaryViewModel vm, dynamic e) async {
    final ok = await VideoDialogs.showDeleteConfirmation(context);
    if (ok == true) {
      await vm.deleteByPath(e.path as String);
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(d.year, d.month, d.day);

    if (dateOnly == today) {
      return 'Today';
    }

    if (dateOnly == yesterday) {
      return 'Yesterday';
    }

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = monthNames[d.month - 1];

    if (d.year == now.year) {
      return '${d.day} $monthName';
    }

    return '${d.day} $monthName ${d.year}';
  }
}
