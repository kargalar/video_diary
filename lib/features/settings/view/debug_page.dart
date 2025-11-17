import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/settings_view_model.dart';

class DebugPage extends StatelessWidget {
  static const route = '/debug';
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Notification Testing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              vm.sendTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent')));
            },
            icon: const Icon(Icons.notifications),
            label: const Text('Send Test Notification'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              vm.scheduleTestNotificationIn5Seconds();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled notification for 5 seconds from now')));
            },
            icon: const Icon(Icons.schedule),
            label: const Text('Schedule Test (5 seconds)'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text('Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: vm.getDiagnostics(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final diagnostics = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildInfoTile('Initialized', '${diagnostics['initialized']}'), _buildInfoTile('Timezone', '${diagnostics['timezone']}'), _buildInfoTile('Notifications Enabled', '${diagnostics['androidNotificationsEnabled']}'), _buildInfoTile('Channel ID', '${diagnostics['channelId']}')],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
