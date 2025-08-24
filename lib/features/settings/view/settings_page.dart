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
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Kayıt Klasörü'),
            subtitle: Text(state.storageDirectory ?? 'Seçilmedi'),
            trailing: ElevatedButton(onPressed: vm.pickDirectory, child: const Text('Seç')),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Günlük Hatırlatma Saati'),
            subtitle: Text(timeOfDay.format(context)),
            trailing: ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                if (picked != null) {
                  await vm.setReminder(picked.hour, picked.minute);
                }
              },
              child: const Text('Ayarla'),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Uygulama, seçtiğiniz saatlerde günlük video kaydı için bildirim gönderir.'),
        ],
      ),
    );
  }
}
