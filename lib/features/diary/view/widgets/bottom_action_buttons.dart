import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/diary_view_model.dart';
import '../../../settings/view/settings_page.dart';
import '../recording_page.dart';
import 'video_edit_bottom_sheet.dart';

class BottomActionButtons extends StatelessWidget {
  const BottomActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiaryViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Streak indicator
          FloatingActionButton.extended(
            onPressed: null, // Non-interactive
            backgroundColor: Colors.white,
            icon: const Icon(Icons.local_fire_department, color: Colors.orange),
            label: Text(
              '${vm.currentStreak} day${vm.currentStreak != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          // Start Recording button
          FloatingActionButton.extended(
            onPressed: () async {
              final filePath = await Navigator.of(context).pushNamed(RecordingPage.route);
              if (!context.mounted) return;

              // If a video was recorded, show the edit bottom sheet
              if (filePath != null && filePath is String) {
                // Get the latest entry
                final latestEntry = vm.entries.isNotEmpty ? vm.entries.first : null;
                if (latestEntry == null) return;

                final result = await showModalBottomSheet<Map<String, dynamic>>(
                  // ignore: use_build_context_synchronously
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (context) => PopScope(
                    canPop: false,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: VideoEditBottomSheet(currentTitle: '', currentRating: null, currentMoods: const []),
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
            icon: const Icon(Icons.fiber_manual_record, size: 16, color: Colors.black87),
            backgroundColor: Colors.white,
            label: const Text(
              'Start Recording',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          // Settings button
          FloatingActionButton(
            onPressed: () => Navigator.of(context).pushNamed(SettingsPage.route),
            backgroundColor: Colors.white,
            tooltip: 'Settings',
            child: const Icon(Icons.settings, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
