import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/diary_view_model.dart';
import '../../../settings/view/settings_page.dart';
import '../../../settings/viewmodel/settings_view_model.dart';
import '../recording_page.dart';
import 'video_edit_bottom_sheet.dart';
import '../../../../services/video_review_service.dart';

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
            heroTag: 'streakInfoFab',
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
            heroTag: 'startRecordingFab',
            onPressed: () async {
              // Request permissions first
              final hasPermissions = await vm.requestAndCheckPermissions();
              if (!hasPermissions) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Camera and microphone permissions are required to record videos.', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings(), textColor: Colors.white),
                  ),
                );
                return;
              }

              // ignore: use_build_context_synchronously
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
                  isDismissible: true,

                  enableDrag: false,
                  builder: (context) => PopScope(
                    canPop: false,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: VideoEditBottomSheet(currentTitle: '', currentRating: null, currentMoods: const [], isNewVideo: true),
                    ),
                  ),
                );

                if (result != null) {
                  var entryPath = latestEntry.path;
                  // Check if user discarded the video
                  if (result['discard'] == true) {
                    await vm.deleteByPath(latestEntry.path);
                    return;
                  }

                  // Save the metadata
                  final title = result['title'] as String?;
                  final description = result['description'] as String?;
                  final rating = result['rating'] as int?;
                  final moods = result['moods'] as List<dynamic>?;

                  if (title != null && title.trim().isNotEmpty) {
                    final updatedPath = await vm.renameByPath(entryPath, title.trim());
                    if (updatedPath != null) {
                      entryPath = updatedPath;
                    }
                  }

                  if (description != null && description.trim().isNotEmpty) {
                    await vm.setDescriptionForEntry(entryPath, description.trim());
                  }

                  if (rating != null) {
                    await vm.setRatingForEntry(entryPath, rating.clamp(1, 5));
                  }

                  if (moods != null && moods.isNotEmpty) {
                    await vm.setMoodsForEntry(entryPath, moods.cast());
                  }

                  // Show notification prompt if this is the first video
                  if (context.mounted) {
                    final settingsVm = context.read<SettingsViewModel>();
                    if (!settingsVm.state.hasShownNotificationPrompt) {
                      // Mark prompt as shown
                      final newSettings = settingsVm.state.copyWith(hasShownNotificationPrompt: true);
                      await settingsVm.repo.save(newSettings);
                      settingsVm.loadSettings();

                      // Show dialog
                      // ignore: use_build_context_synchronously
                      if (context.mounted) {
                        final wantNotifications = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Daily Reminders'),
                            content: const Text('Would you like to receive daily reminders to record your video?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not Now')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                child: const Text('Enable'),
                              ),
                            ],
                          ),
                        );

                        if (wantNotifications == true && context.mounted) {
                          // Navigate to settings page
                          Navigator.of(context).pushNamed(SettingsPage.route);
                        }
                      }
                    }
                  }

                  // Video başarıyla kaydedildi, review servisi çağrılır
                  // ignore: use_build_context_synchronously
                  if (context.mounted) {
                    final reviewService = VideoReviewService();
                    final videoCount = await reviewService.getVideoCount();
                    final reviewCompleted = await reviewService.isReviewCompleted();
                    debugPrint('🎬 Review Service - Before increment: Count=$videoCount, Completed=$reviewCompleted');

                    await reviewService.incrementVideoCountAndRequestReview();

                    final newCount = await reviewService.getVideoCount();
                    debugPrint('🎬 Review Service - After increment: Count=$newCount');
                  }
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
            heroTag: 'settingsFab',
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
