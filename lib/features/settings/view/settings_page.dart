import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/settings_view_model.dart';
import '../../diary/viewmodel/diary_view_model.dart';

class SettingsPage extends StatelessWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final diaryVm = context.watch<DiaryViewModel>();
    final state = vm.state;
    final timeOfDay = TimeOfDay(hour: state.reminderHour, minute: state.reminderMinute);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Storage Folder'),
            subtitle: Text(state.storageDirectory ?? 'Not selected'),
            trailing: ElevatedButton(onPressed: vm.pickDirectory, child: const Text('Select')),
          ),
          const SizedBox(height: 12),
          SwitchListTile(secondary: const Icon(Icons.screen_rotation), title: const Text('Landscape Recording'), value: state.landscape, onChanged: (v) => vm.setLandscape(v)),
          const Divider(height: 32),
          // Reminder Section
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Daily Reminder'),
            subtitle: state.reminderEnabled ? Text('Every day at ${timeOfDay.format(context)}') : const Text('Off'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.reminderEnabled) ...[
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                      if (picked != null) {
                        await vm.setReminder(picked.hour, picked.minute);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder time updated')));
                        }
                      }
                    },
                    child: Text(timeOfDay.format(context)),
                  ),
                  const SizedBox(width: 8),
                ],
                Switch(
                  value: state.reminderEnabled,
                  onChanged: (v) async {
                    final success = await vm.setReminderEnabled(v);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission required. Please grant permission in app settings.')));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('When reminders are enabled, the app will send a notification at the selected time to record your daily video.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          const Divider(height: 32),
          // Clear All Videos Section
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Videos', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Delete all videos and reset all data'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Videos'),
                    content: const Text('This will permanently delete all your videos, thumbnails, and reset all ratings and streaks. This action cannot be undone. Are you sure?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete All'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final success = await diaryVm.clearAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'All videos deleted successfully' : 'Failed to delete videos'), backgroundColor: success ? Colors.green : Colors.red));
                  }
                }
              },
              child: const Text('Clear All'),
            ),
          ),
        ],
      ),
    );
  }
}
