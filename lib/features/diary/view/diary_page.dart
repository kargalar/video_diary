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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
