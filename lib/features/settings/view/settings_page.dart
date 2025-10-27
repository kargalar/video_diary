import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
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
          SwitchListTile(secondary: const Icon(Icons.dark_mode), title: const Text('Dark Theme'), value: state.darkMode, onChanged: (v) => vm.setDarkMode(v)),
          SwitchListTile(secondary: const Icon(Icons.screen_rotation), title: const Text('Landscape Recording'), value: state.landscape, onChanged: (v) => vm.setLandscape(v)),
          const Divider(height: 32),
          // Reminder Section
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: const Text('Daily Reminder'),
            subtitle: Text(state.reminderEnabled ? 'Every day at ${timeOfDay.format(context)}' : 'Off'),
            value: state.reminderEnabled,
            onChanged: (v) async {
              final success = await vm.setReminderEnabled(v);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission required. Please grant permission in app settings.')));
              }
            },
          ),
          if (state.reminderEnabled) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const SizedBox(width: 40), // Alignment with switch
              title: const Text('Reminder Time'),
              subtitle: Text(timeOfDay.format(context)),
              trailing: ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                  if (picked != null) {
                    await vm.setReminder(picked.hour, picked.minute);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder time updated')));
                    }
                  }
                },
                child: const Text('Change'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('When reminders are enabled, the app will send a notification at the selected time to record your daily video.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}
