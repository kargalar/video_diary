import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../viewmodel/settings_view_model.dart';
import '../../diary/viewmodel/diary_view_model.dart';
import 'privacy_policy_webview_page.dart';
import 'debug_page.dart';
import 'widgets/export_import_dialog.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: const Icon(Icons.folder, size: 20),
            title: const Text('Storage Folder', style: TextStyle(fontSize: 14)),
            subtitle: Text(state.storageDirectory ?? 'Not selected', style: const TextStyle(fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: vm.pickDirectory,
              child: const Text('Select', style: TextStyle(fontSize: 12)),
            ),
          ),
          const Divider(height: 16, indent: 0, endIndent: 0),
          // Reminder Section
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: const Icon(Icons.notifications_active, size: 20),
            title: const Text('Daily Reminder', style: TextStyle(fontSize: 14)),
            subtitle: state.reminderEnabled ? Text('Every day at ${timeOfDay.format(context)}', style: const TextStyle(fontSize: 12)) : const Text('Off', style: TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.reminderEnabled) ...[
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                        if (picked != null) {
                          await vm.setReminder(picked.hour, picked.minute);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder time updated')));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                      child: Text(timeOfDay.format(context), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: state.reminderEnabled,
                    onChanged: (v) async {
                      final success = await vm.setReminderEnabled(v);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission required. Please grant permission in app settings.')));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 12, top: 4, bottom: 4),
            child: Text('Daily notifications to record your video.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          const Divider(height: 16, indent: 0, endIndent: 0),
          // Debug Section
          if (kDebugMode)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: const Icon(Icons.bug_report, size: 20),
              title: const Text('Debug', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Test notifications and diagnostics', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).pushNamed(DebugPage.route);
              },
            ),
          if (kDebugMode) const Divider(height: 16, indent: 0, endIndent: 0),
          // Privacy Policy Section
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: const Icon(Icons.privacy_tip, size: 20),
            title: const Text('Privacy Policy', style: TextStyle(fontSize: 14)),
            subtitle: const Text('View our privacy policy', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PrivacyPolicyWebViewPage()));
            },
          ),
          const Divider(height: 16, indent: 0, endIndent: 0),
          // GitHub Section
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: const Icon(Icons.code, size: 20),
            title: const Text('GitHub', style: TextStyle(fontSize: 14)),
            subtitle: const Text('View source code on GitHub', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () async {
              final uri = Uri.parse('https://github.com/kargalar/video_diary');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const Divider(height: 16, indent: 0, endIndent: 0),
          // Export & Import Section
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: const Icon(Icons.cloud_download, size: 20),
            title: const Text('Export & Import Data', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Backup your data or restore from another device', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => ExportImportDialog(
                  onDataImported: () {
                    diaryVm.load();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
